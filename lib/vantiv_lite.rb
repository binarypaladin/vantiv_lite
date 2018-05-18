# frozen-string-literal: true

require 'vantiv_lite/config'
require 'vantiv_lite/request'

module VantivLite
  class << self
    attr_reader :default_config, :default_request

    def configure(config = env_config, &blk)
      @default_config = block_given? ? Config.build(&blk) : Config.new(config)
      @default_request = Request.new(@default_config)
    end

    def env_config
      Config::OPTS.each_with_object({}) do |k, h|
        env_key = "vantiv_#{k}"
        h[k] = ENV[env_key] if ENV.key?(env_key)
      end
    end

    def request(request_hash)
      default_request.(request_hash)
    end
    alias call request

    TRANSACTIONS.keys.each { |t| define_method(t) { |hash| default_request.public_send(t, hash) } }
  end
  configure
end
