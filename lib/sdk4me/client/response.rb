module Sdk4me
  class Response
    def initialize(request, response)
      @request = request
      @response = response
    end

    def request
      @request
    end

    def response
      @response
    end
    alias_method :raw, :response

    def body
      @response.body
    end

    # The JSON value, if single resource is queried this is a Hash, if multiple resources where queried it is an Array
    # If the response is not +valid?+ it is a Hash with 'message' and optionally 'errors'
    def json
      return @json if defined?(@json)
      # no content, no JSON
      if @response.code.to_s == '204'
        data = {}
      elsif @response.body.blank?
        # no body, no json
        data = {message: @response.message.blank? ? 'empty body' : @response.message.strip}
      end
      begin
        data ||= JSON.parse(@response.body)
      rescue ::Exception => e
        data = { message: "Invalid JSON - #{e.message} for:\n#{@response.body}" }
      end
      # indifferent access to hashes
      data = data.is_a?(Array) ? data.map(&:with_indifferent_access) : data.with_indifferent_access
      # empty OK response is not seen as an error
      data = {} if data.is_a?(Hash) && data.size == 1 && data[:message] == 'OK'
      # prepend HTTP response code to message
      data[:message] = "#{response.code}: #{data[:message]}" unless @response.is_a?(Net::HTTPSuccess)
      @json = data
    end

    # the error message in case the response is not +valid?+
    def message
      @message ||= json.is_a?(Hash) ? json[:message] : nil
    end

    # +true+ if the server did not respond at all
    def empty?
      @response.body.blank?
    end

    # +true+ if no 'message' is given (and the JSON could be parsed)
    def valid?
      message.nil?
    end
    alias_method :success?, :valid?

    # +true+ in case of a HTTP 5xx error
    def failure?
      !success? && (@response.code.to_s.blank? || @response.code.to_s =~ /5\d\d/)
    end

    # retrieve a value from the resource
    # if the JSON value is an Array a array with the value for each resource will be given
    # @param keys: a single key or a key-path separated by comma
    def[](*keys)
      values = json.is_a?(Array) ? json : [json]
      keys.each { |key| values = values.map{ |value| value.is_a?(Hash) ? value[key] : nil} }
      json.is_a?(Array) ? values : values.first
    end

    # The nr of resources found
    def size
      @size ||= message ? 0 : json.is_a?(Array) ? json.size : 1
    end
    alias :count :size

    # pagination - per page
    def per_page
      @per_page ||= @response.header['X-Pagination-Per-Page'].to_i
    end

    # pagination - current page
    def current_page
      @current_page ||= @response.header['X-Pagination-Current-Page'].to_i
    end

    # pagination - total pages
    def total_pages
      @total_pages ||= @response.header['X-Pagination-Total-Pages'].to_i
    end

    # pagination - total entries
    def total_entries
      @total_entries ||= @response.header['X-Pagination-Total-Entries'].to_i
    end

    # pagination urls (full paths with server) - relations :first, :prev, :next, :last
    # Link: <https://api.4me.com/v1/requests?page=1&per_page=25>; rel="first", <https://api.4me.com/v1/requests?page=2&per_page=25>; rel="prev", etc.
    def pagination_link(relation)
      # split on ',' select the [url] in '<[url]>; rel="[relation]"', compact to all url's found (at most one) and take the first
      (@pagination_links ||= {})[relation] ||= @response.header['Link'] && @response.header['Link'].split(/,\s*<?/).map{ |link| link[/^\s*<?(.*?)>?;\s*rel="#{relation.to_s}"\s*$/, 1] }.compact.first
    end

    # pagination urls (relative paths without server) - relations :first, :prev, :next, :last
    def pagination_relative_link(relation)
      (@pagination_relative_links ||= {})[relation] ||= pagination_link(relation) && pagination_link(relation)[/^https?:\/\/[^\/]*(.*)/, 1]
    end

    # +true+ if the response is invalid because of throttling
    def throttled?
      !!(@response.code.to_s == '429' || (message && message =~ /Too Many Requests/))
    end

    def retry_after
      @current_page ||= @response.header['Retry-After'].to_i
    end

    def to_s
      valid? ? json.to_s : message
    end

  end
end
