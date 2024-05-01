require 'gem_config'
require 'logger'

module Sdk4me
  include GemConfig::Base

  with_configuration do
    has :logger, default: ::Logger.new($stdout)

    has :host, classes: String, default: 'https://api.4me.com'
    has :api_version, values: ['v1'], default: 'v1'
    has :access_token, classes: String
    has :api_token, classes: String

    has :account, classes: String
    has :source, classes: String

    has :max_retry_time, classes: Integer, default: 300
    has :read_timeout, classes: Integer, default: 25
    has :block_at_rate_limit, classes: [TrueClass, FalseClass], default: true
    has :max_throttle_time, classes: Integer, default: 3660
    has :proxy_host, classes: String
    has :proxy_port, classes: Integer, default: 8080
    has :proxy_user, classes: String
    has :proxy_password, classes: String

    has :ca_file, classes: String, default: '../ca-bundle.crt'
  end

  def self.logger
    configuration.logger
  end

  class Exception < ::Exception
  end

  class UploadFailed < Exception
  end
end
