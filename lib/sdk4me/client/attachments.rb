module Sdk4me
  class Attachments
    S3_PROVIDER = 's3'.freeze
    FILENAME_TEMPLATE = '${filename}'.freeze

    def initialize(client, path)
      @client = client
      @path = path
    end

    # Upload attachments and replace the data inline with the uploaded
    # attachments info.
    #
    # To upload field attachments:
    #  * data[:note_attachments] = ['/tmp/test.doc', '/tmp/test.log']
    #
    # To upload inline images:
    #  * data[:note] containing text referring to inline images in
    #    data[:note_attachments] by their array index, with the index being
    #    zero-based. Text can only refer to inline images in its own
    #    attachments collection. For example:
    #
    #      data = {
    #        note: "Hello [note_attachments: 0] and [note_attachments: 1]",
    #        note_attachments: ['/tmp/jip.png', '/tmp/janneke.png'],
    #        ...
    #      }
    #
    # After calling this method the data, that will be posted to update the
    # 4me record, would look similar to:
    #
    #      data = {
    #        note: "Hello ![](storage/abc/adjhajdhjaadf.png) and ![](storage/abc/fskdhakjfkjdssdf.png])",
    #        note_attachments: ['storage/abc/fskdhakjfkjdssdf.png', 'storage/abc/fskdhakjfkjdssdf.png'],
    #        ...
    #      }
    def upload_attachments!(data)
      # Field attachments
      field_attachments = []
      data.each do |field, value|
        next unless field.to_s.end_with?('_attachments')
        next unless value.is_a?(Enumerable) && value.any?

        value.map! { |attachment| upload_attachment(attachment) }.compact!
        field_attachments << field if value.any?
      end

      # Rich text inline attachments
      field_attachments.each do |field_attachment|
        field = field_attachment.to_s.sub(/_attachments$/, '')
        value = data[field.to_sym] || data[field]
        next unless value.is_a?(String)

        value.gsub!(/\[#{field_attachment}:\s?(\d+)\]/) do |match|
          idx = Regexp.last_match(1).to_i
          attachment = data[field_attachment][idx]
          if attachment
            attachment[:inline] = true
            "![](#{attachment[:key]})" # magic markdown for inline attachments
          else
            match
          end
        end
      end
    end

    private

    def raise_error(message)
      @client.logger.error { message }
      raise Sdk4me::UploadFailed, message
    end

    def storage
      @storage ||= @client.get("#{@path}/attachment_upload")
                          .json
                          .with_indifferent_access
                          .tap do |storage|
                            storage[:provider] ||
                              raise_error("Attachments not supported for #{@path}")
                          end
    end

    # Upload a single attachment and return the data that should be submitted
    # back to 4me. Returns nil and provides an error in case the attachment
    # upload failed.
    def upload_attachment(attachment)
      return nil unless attachment

      provider = storage[:provider]

      # attachment is already a file or we need to open the file from disk
      unless attachment.respond_to?(:path) && attachment.respond_to?(:read)
        raise "file does not exist: #{attachment}" unless File.exist?(attachment)

        attachment = File.open(attachment, 'rb')
      end

      key_template = storage[provider][:key]
      key = key_template.sub(FILENAME_TEMPLATE, File.basename(attachment.path))

      if provider == S3_PROVIDER
        upload_to_s3(key, attachment)
      else
        upload_to_4me_local(key, attachment)
      end

      # return the values for the attachments param
      { key: key, filesize: File.size(attachment.path) }
    rescue StandardError => e
      raise_error("Attachment upload failed: #{e.message}")
    end

    # Upload the file to AWS S3 storage
    def upload_to_s3(key, attachment)
      uri = storage[:upload_uri]
      response = send_file(uri, storage[:s3].merge({ file: attachment }))

      # this is a bit of a hack, but Amazon S3 returns only XML :(
      xml = response.body || ''
      error = xml[%r{<Error>.*<Message>(.*)</Message>.*</Error>}, 1]
      raise "AWS S3 upload to #{uri} for #{key} failed: #{error}" if error
    end

    # Upload the file directly to 4me local storage
    def upload_to_4me_local(key, attachment)
      uri = storage[:upload_uri]
      response = send_file(uri, storage[:local].merge({ file: attachment }), @client.send(:expand_header))
      raise "4me upload to #{uri} for #{key} failed: #{response.message}" unless response.valid?
    end

    def send_file(uri, params, basic_auth_header = {})
      params = { 'Content-Type': MIME::Types.type_for(params[:key])[0] || MIME::Types['application/octet-stream'][0] }.merge(params)
      data, header = Sdk4me::Multipart::Post.prepare_query(params)
      ssl, domain, port, path = @client.send(:ssl_domain_port_path, uri)
      request = Net::HTTP::Post.new(path, basic_auth_header.merge(header))
      request.body = data
      @client.send(:_send, request, domain, port, ssl)
    end
  end
end
