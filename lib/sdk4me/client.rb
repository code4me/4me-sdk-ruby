require 'net/http'
require 'json'
require 'uri'
require 'date'
require 'time'
require 'net/https'
require 'open-uri'
require 'sdk4me'

require 'sdk4me/client/version'
require 'sdk4me/client/response'
require 'sdk4me/client/multipart'
require 'sdk4me/client/attachments'

# cherry-pick some core extensions from active support
require 'active_support/core_ext/module/aliasing.rb'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try.rb'
require 'active_support/core_ext/hash/indifferent_access'

module Sdk4me
  class Client
    MAX_PAGE_SIZE = 100
    DEFAULT_HEADER = {'Content-Type' => 'application/json'}

    # Create a new 4me SDK Client
    #
    # Shared configuration for all 4me SDK Clients:
    #   Sdk4me.configure do |config|
    #     config.api_token = 'd41f5868feb65fc87fa2311a473a8766ea38bc40'
    #     config.account = 'my-sandbox'
    #     ...
    #   end
    #
    # Override configuration per 4me SDK Client:
    # sdk4me = Sdk4me::Client.new(account: 'trusted-sandbox')
    #
    # All options available:
    #  - logger:      The Ruby Logger instance, default: Logger.new(STDOUT)
    #  - host:        The 4me API host, default: 'https://api.4me.com'
    #  - api_version: The 4me API version, default: 'v1'
    #  - api_token:   *required* The 4me API token
    #  - account:     Specify a different (trusted) account to work with
    #                 @see http://developer.4me.com/v1/#multiple-accounts
    #  - source:      The Source used when creating new records
    #                 @see http://developer.4me.com/v1/general/source/
    #
    #  - max_retry_time: maximum nr of seconds to wait for server to respond (default = 5400 = 1.5 hours)
    #                    the sleep time between retries starts at 2 seconds and doubles after each retry
    #                    retry times: 2, 6, 18, 54, 162, 486, 1458, 4374, 13122, ... seconds
    #                    one retry will always be performed unless you set the value to -1
    #  - read_timeout:   HTTP GET read timeout in seconds (default = 25)
    #  - block_at_rate_limit: Set to +true+ to block the request until the rate limit is lifted, default: +false+
    #                         @see http://developer.4me.com/v1/#rate-limiting
    #
    #  - proxy_host:     Define in case HTTP traffic needs to go through a proxy
    #  - proxy_port:     Port of the proxy, defaults to 8080
    #  - proxy_user:     Proxy user
    #  - proxy_password: Proxy password
    def initialize(options = {})
      @options = Sdk4me.configuration.current.merge(options)
      [:host, :api_version, :api_token].each do |required_option|
        raise ::Sdk4me::Exception.new("Missing required configuration option #{required_option}") if option(required_option).blank?
      end
      @ssl, @domain, @port = ssl_domain_port_path(option(:host))
      @ssl_verify_none = options[:ssl_verify_none]
      @logger = @options[:logger]
    end

    # Retrieve an option
    def option(key)
      @options[key]
    end

    # Yield all retrieved resources one-by-one for the given (paged) API query.
    # Raises an ::Sdk4me::Exception with the response retrieved from 4me is invalid
    # Returns total nr of resources yielded (for logging)
    def each(path, params = {}, header = {}, &block)
      # retrieve the resources using the max page size (least nr of API calls)
      next_path = expand_path(path, {per_page: MAX_PAGE_SIZE, page: 1}.merge(params))
      size = 0
      while next_path
        # retrieve the records (with retry and optionally wait for rate-limit)
        response = get(next_path, {}, header)
        # raise exception in case the response is invalid
        raise ::Sdk4me::Exception.new(response.message) unless response.valid?
        # yield the resources
        response.json.each{ |resource| yield resource }
        size += response.json.size
        # go to the next page
        next_path = response.pagination_relative_link(:next)
      end
      size
    end

    # send HTTPS GET request and return instance of Sdk4me::Response
    def get(path, params = {}, header = {})
      _send(Net::HTTP::Get.new(expand_path(path, params), expand_header(header)))
    end

    # send HTTPS DELETE request and return instance of Sdk4me::Response
    def delete(path, params = {}, header = {})
      _send(Net::HTTP::Delete.new(expand_path(path, params), expand_header(header)))
    end

    # send HTTPS PATCH request and return instance of Sdk4me::Response
    def put(path, data = {}, header = {})
      _send(json_request(Net::HTTP::Patch, path, data, header))
    end
    alias_method :patch, :put

    # send HTTPS POST request and return instance of Sdk4me::Response
    def post(path, data = {}, header = {})
      _send(json_request(Net::HTTP::Post, path, data, header))
    end

    # upload a CSV file to import
    # @param csv: The CSV File or the location of the CSV file
    # @param type: The type, e.g. person, organization, people_contact_details
    # @raise Sdk4me::UploadFailed in case the file could was not accepted by SDK4ME and +block_until_completed+ is +true+
    # @raise Sdk4me::Exception in case the import progress could not be monitored
    def import(csv, type, block_until_completed = false)
      csv = File.open(csv, 'rb') unless csv.respond_to?(:path) && csv.respond_to?(:read)
      data, headers = Sdk4me::Multipart::Post.prepare_query(type: type, file: csv)
      request = Net::HTTP::Post.new(expand_path('/import'), expand_header(headers))
      request.body = data
      response = _send(request)
      @logger.info { "Import file '#{csv.path}' successfully uploaded with token '#{response[:token]}'." } if response.valid?

      if block_until_completed
        raise ::Sdk4me::UploadFailed.new("Failed to queue #{type} import. #{response.message}") unless response.valid?
        token = response[:token]
        while true
          response = get("/import/#{token}")
          unless response.valid?
            sleep(5)
            response = get("/import/#{token}") # single retry to recover from a network error
            raise ::Sdk4me::Exception.new("Unable to monitor progress for #{type} import. #{response.message}") unless response.valid?
          end
          # wait 30 seconds while the response is OK and import is still busy
          break unless ['queued', 'processing'].include?(response[:state])
          @logger.debug { "Import of '#{csv.path}' is #{response[:state]}. Checking again in 30 seconds." }
          sleep(30)
        end
      end

      response
    end

    # Export CSV files
    # @param types: The types to export, e.g. person, organization, people_contact_details
    # @param from: Retrieve all files since a given data and time
    # @param block_until_completed: Set to true to monitor the export progress
    # @param locale: Required for translations export
    # @raise Sdk4me::Exception in case the export progress could not be monitored
    def export(types, from = nil, block_until_completed = false, locale = nil)
      data = {type: [types].flatten.join(',')}
      data[:from] = from unless from.blank?
      data[:locale] = locale unless locale.blank?
      response = post('/export', data)
      if response.valid?
        if response.raw.code.to_s == '204'
          @logger.info { "No changed records for '#{data[:type]}' since #{data[:from]}." }
          return response
        end
        @logger.info { "Export for '#{data[:type]}' successfully queued with token '#{response[:token]}'." }
      end

      if block_until_completed
        raise ::Sdk4me::UploadFailed.new("Failed to queue '#{data[:type]}' export. #{response.message}") unless response.valid?
        token = response[:token]
        while true
          response = get("/export/#{token}")
          unless response.valid?
            sleep(5)
            response = get("/export/#{token}") # single retry to recover from a network error
            raise ::Sdk4me::Exception.new("Unable to monitor progress for '#{data[:type]}' export. #{response.message}") unless response.valid?
          end
          # wait 30 seconds while the response is OK and export is still busy
          break unless ['queued', 'processing'].include?(response[:state])
          @logger.debug { "Export of '#{data[:type]}' is #{response[:state]}. Checking again in 30 seconds." }
          sleep(30)
        end
      end

      response
    end

    def logger
      @logger
    end

    private

    # create a request (place data in body if the request becomes too large)
    def json_request(request_class, path, data = {}, header = {})
      Sdk4me::Attachments.new(self).upload_attachments!(path, data)
      request = request_class.new(expand_path(path), expand_header(header))
      body = {}
      data.each{ |k,v| body[k.to_s] = typecast(v, false) }
      request.body = body.to_json
      request
    end

    URI_ESCAPE_PATTERN = Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")
    def uri_escape(value)
      URI.escape(value, URI_ESCAPE_PATTERN).gsub('.', '%2E')
    end

    # Expand the given header with the default header
    def expand_header(header = {})
      header = DEFAULT_HEADER.merge(header)
      header['X-4me-Account'] = option(:account) if option(:account)
      header['AUTHORIZATION'] = 'Basic ' + ["#{option(:api_token)}:x"].pack('m*').gsub(/\s/, '')
      if option(:source)
        header['X-4me-Source'] = option(:source)
        header['HTTP_USER_AGENT'] = option(:source)
      end
      header
    end

    # Expand the given path with the parameters
    # Examples:
    #   person_id: 5
    #   :"updated_at=>" => yesterday
    #   fields: ['id', 'created_at', 'sourceID']
    def expand_path(path, params = {})
      path = path.dup
      path = "/#{path}" unless path =~ /^\// # make sure path starts with /
      path = "/#{option(:api_version)}#{path}" unless path =~ /^\/v[\d.]+\// # preprend api version
      params.each do |key, value|
        path << (path['?'] ? '&' : '?')
        path << expand_param(key, value)
      end
      path
    end

    # Expand one parameter, e.g. (:"created_at=>", DateTime.now) to "created_at=%3E22011-12-16T12:24:41%2B01:00"
    def expand_param(key, value)
      param = uri_escape(key.to_s).gsub('%3D', '=') # handle :"updated_at=>" or :"person_id!=" parameters
      param << '=' unless key['=']
      param << typecast(value)
      param
    end

    # Parameter value typecasting
    def typecast(value, escape = true)
      case value.class.name.to_sym
        when :NilClass    then ''
        when :String      then escape ? uri_escape(value) : value
        when :TrueClass   then 'true'
        when :FalseClass  then 'false'
        when :DateTime    then datetime = value.new_offset(0).iso8601; escape ? uri_escape(datetime) : datetime
        when :Date        then value.strftime("%Y-%m-%d")
        when :Time        then value.strftime("%H:%M")
        # do not convert arrays in put/post requests as squashing arrays is only used in filtering
        when :Array       then escape ? value.map{ |v| typecast(v, escape) }.join(',') : value
        # TODO: temporary for special constructions to update contact details, see Request #1444166
        when :Hash        then escape ? value.to_s : value
        else escape ? value.to_json : value.to_s
      end
    end

    # Send a request to 4me and wrap the HTTP Response in an Sdk4me::Response
    # Guaranteed to return a Response, thought it may be +empty?+
    def _send(request, domain = @domain, port = @port, ssl = @ssl)
      @logger.debug { "Sending #{request.method} request to #{domain}:#{port}#{request.path}" }
      _response = begin
        http_with_proxy = option(:proxy_host).blank? ? Net::HTTP : Net::HTTP::Proxy(option(:proxy_host), option(:proxy_port), option(:proxy_user), option(:proxy_password))
        http = http_with_proxy.new(domain, port)
        http.read_timeout = option(:read_timeout)
        http.use_ssl = ssl
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @ssl_verify_none
        http.start{ |_http| _http.request(request) }
      rescue ::Exception => e
        Struct.new(:body, :message, :code, :header).new(nil, "No Response from Server - #{e.message} for '#{domain}:#{port}#{request.path}'", 500, {})
      end
      response = Sdk4me::Response.new(request, _response)
      if response.valid?
        @logger.debug { "Response:\n#{JSON.pretty_generate(response.json)}" }
      elsif response.raw.body =~ /^\s*<\?xml/i
        @logger.debug { "XML response:\n#{response.raw.body}" }
      elsif '303' == response.raw.code.to_s
        @logger.debug { "Redirect: #{response.raw.header['Location']}" }
      else
        @logger.error { "Request failed: #{response.message}" }
      end
      response
    end

    # parse the given URI to [domain, port, ssl, path]
    def ssl_domain_port_path(uri)
      uri = URI.parse(uri)
      ssl = uri.scheme == 'https'
      [ssl, uri.host, uri.port, uri.path]
    end

  end

  module SendWithRateLimitBlock
    # Wraps the _send method with retries when the server does not respond, see +initialize+ option +:rate_limit_block+
    def _send(request, domain = @domain, port = @port, ssl = @ssl)
      return super(request, domain, port, ssl) unless option(:block_at_rate_limit) && option(:max_throttle_time) > 0
      now = nil
      timed_out = false
      begin
        _response = super(request, domain, port, ssl)
        now ||= Time.now
        if _response.throttled?
          # if no Retry-After is not provided, the 4me server is very busy, wait 5 minutes
          retry_after = _response.retry_after == 0 ? 300 : [_response.retry_after, 2].max
          if (Time.now - now + retry_after) < option(:max_throttle_time)
            @logger.warn { "Request throttled, trying again in #{retry_after} seconds: #{_response.message}" }
            sleep(retry_after)
          else
            timed_out = true
          end
        end
      end while _response.throttled? && !timed_out
      _response
    end
  end
  Client.send(:prepend, SendWithRateLimitBlock)

  module SendWithRetries
    # Wraps the _send method with retries when the server does not respond, see +initialize+ option +:retries+
    def _send(request, domain = @domain, port = @port, ssl = @ssl)
      return super(request, domain, port, ssl) unless option(:max_retry_time) > 0
      retries = 0
      sleep_time = 1
      now = nil
      timed_out = false
      begin
        _response = super(request, domain, port, ssl)
        now ||= Time.now
        if _response.failure?
          sleep_time *= 2
          if (Time.now - now + sleep_time) < option(:max_retry_time)
            @logger.warn { "Request failed, retry ##{retries += 1} in #{sleep_time} seconds: #{_response.message}" }
            sleep(sleep_time)
          else
            timed_out = true
          end
        end
      end while _response.failure? && !timed_out
      _response
    end
  end
  Client.send(:prepend, SendWithRetries)
end

# HTTPS with certificate bundle
module Net
  class HTTP
    alias_method :original_use_ssl=, :use_ssl=

    def use_ssl=(flag)
      self.ca_file = File.expand_path(Sdk4me.configuration.current[:ca_file], __FILE__) if flag
      self.verify_mode = OpenSSL::SSL::VERIFY_PEER
      self.original_use_ssl = flag
    end
  end
end

