module Sdk4me
  class Attachments

    AWS_PROVIDER = 'aws'
    FILENAME_TEMPLATE = '${filename}'

    def initialize(client)
      @client = client
    end

    # upload the attachments and return the data with the uploaded attachment info
    # Two flavours available
    #  * data[:attachments]
    #  * data[:note] containing text with '[attachment:/tmp/images/green_fuzz.jpg]'
    def upload_attachments!(path, data)
      upload_options = {
        raise_exceptions: !!data.delete(:attachments_exception),
        attachments_field: attachments_field(path),
      }
      uploaded_attachments = upload_normal_attachments!(path, data, upload_options)
      uploaded_attachments += upload_inline_attachments!(path, data, upload_options)
      # jsonify the attachments, if any were uploaded
      data[upload_options[:attachments_field]] = uploaded_attachments.compact.to_json if uploaded_attachments.compact.any?
    end

    private

    # upload the attachments in :attachments to 4me and return the data with the uploaded attachment info
    def upload_normal_attachments!(path, data, upload_options)
      attachments = [data.delete(:attachments)].flatten.compact
      return [] if attachments.empty?

      upload_options[:storage] ||= storage(path, upload_options[:raise_exceptions])
      return [] unless upload_options[:storage]

      attachments.map do |attachment|
        upload_attachment(upload_options[:storage], attachment, upload_options[:raise_exceptions])
      end
    end

    INLINE_ATTACHMENT_REGEXP = /\[attachment:([^\]]+)\]/.freeze
    # upload any '[attachment:/tmp/images/green_fuzz.jpg]' in :note text field to 4me as inline attachment and add the s3 key to the text
    def upload_inline_attachments!(path, data, upload_options)
      text_field = upload_options[:attachments_field].to_s.gsub('_attachments', '').to_sym
      return [] unless (data[text_field] || '') =~ INLINE_ATTACHMENT_REGEXP

      upload_options[:storage] ||= storage(path, upload_options[:raise_exceptions])
      return [] unless upload_options[:storage]

      attachments = []
      data[text_field] = data[text_field].gsub(INLINE_ATTACHMENT_REGEXP) do |full_match|
        attachment_details = upload_attachment(upload_options[:storage], $~[1], upload_options[:raise_exceptions])
        if attachment_details
          attachments << attachment_details.merge(inline: true)
          "![](#{attachment_details[:key]})" # magic markdown for inline attachments
        else
          full_match
        end
      end
      attachments
    end

    def storage(path, raise_exceptions)
      # retrieve the upload configuration for this record from 4me
      storage = @client.get(path =~ /\d+$/ ? path : "#{path}/new", {attachment_upload_token: true}, @client.send(:expand_header))[:storage_upload]
      report_error("Attachments not allowed for #{path}", raise_exceptions) unless storage
      storage
    end

    def attachments_field(path)
      case path
      when /cis/, /contracts/, /flsas/, /service_instances/, /slas/
        :remarks_attachments
      when /service_offerings/
        :summary_attachments
      else
        :note_attachments
      end
    end

    def report_error(message, raise_exceptions)
      if raise_exceptions
        raise Sdk4me::UploadFailed.new(message)
      else
        @client.logger.error{ message }
      end
    end

    # upload a single attachment and return the data for the note_attachments
    # returns nil and provides an error in case the attachment upload failed
    def upload_attachment(storage, attachment, raise_exceptions)
      begin
        # attachment is already a file or we need to open the file from disk
        unless attachment.respond_to?(:path) && attachment.respond_to?(:read)
          raise "file does not exist: #{attachment}" unless File.exists?(attachment)
          attachment = File.open(attachment, 'rb')
        end

        # there are two different upload methods: AWS S3 and 4me local storage
        key_template = "#{storage[:upload_path]}#{FILENAME_TEMPLATE}"
        key = key_template.gsub(FILENAME_TEMPLATE, File.basename(attachment.path))
        upload_method = storage[:provider] == AWS_PROVIDER ? :aws_upload : :upload_to_4me
        send(upload_method, storage, key_template, key, attachment)

        # return the values for the note_attachments param
        {key: key, filesize: File.size(attachment.path)}
      rescue ::Exception => e
        report_error("Attachment upload failed: #{e.message}", raise_exceptions)
        nil
      end
    end

    def aws_upload(aws, key_template, key, attachment)
      # upload the file to AWS
      response = send_file(aws[:upload_uri], {
        :'x-amz-server-side-encryption' => 'AES256',
        key: key_template,
        AWSAccessKeyId: aws[:access_key],
        acl: 'private',
        signature: aws[:signature],
        success_action_status: 201,
        policy: aws[:policy],
        file: attachment # file must be last
      })
      # this is a bit of a hack, but Amazon S3 returns only XML :(
      xml = response.raw.body || ''
      error = xml[/<Error>.*<Message>(.*)<\/Message>.*<\/Error>/, 1]
      raise "AWS upload to #{aws[:upload_uri]} for #{key} failed: #{error}" if error

      # inform 4me of the successful upload
      response = @client.get(aws[:success_url].split('/').last, {key: key}, @client.send(:expand_header))
      raise "4me confirmation #{aws[:success_url].split('/').last} for #{key} failed: #{response.message}" unless response.valid?
    end

    # upload the file directly to 4me
    def upload_to_4me(storage, key_template, key, attachment)
      uri = storage[:upload_uri] =~ /\/v1/ ? storage[:upload_uri] : storage[:upload_uri].gsub('/attachments', '/v1/attachments')
      response = send_file(uri, {file: attachment, key: key_template}, @client.send(:expand_header))
      raise "4me upload to #{storage[:upload_uri]} for #{key} failed: #{response.message}" unless response.valid?
    end

    def send_file(uri, params, basic_auth_header = {})
      params = {:'Content-Type' => MIME::Types.type_for(params[:key])[0] || MIME::Types["application/octet-stream"][0]}.merge(params)
      data, header = Sdk4me::Multipart::Post.prepare_query(params)
      ssl, domain, port, path = @client.send(:ssl_domain_port_path, uri)
      request = Net::HTTP::Post.new(path, basic_auth_header.merge(header))
      request.body = data
      @client.send(:_send, request, domain, port, ssl)
    end

  end
end
