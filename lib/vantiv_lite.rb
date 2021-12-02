# frozen-string-literal: true

require 'vantiv_lite/config'
require 'vantiv_lite/request'

module VantivLite
  TRANSACTIONS = {
    auth_reversal: 'authReversal',
    authorization: 'authorization',
    capture: 'capture',
    credit: 'credit',
    register_token: 'registerTokenRequest',
    sale: 'sale',
    void: 'void'
  }.freeze

  class << self
    attr_reader :default_config, :default_request

    def configure(config = env_config, &blk)
      @default_config = block_given? ? Config.build(&blk) : Config.with_obj(config)
      @default_request = Request.new(@default_config)
    end

    def env_config
      opts = Config::OPTS.each_with_object({}) do |k, h|
        env_key = "vantiv_#{k}"
        h[k] = ENV[env_key] if ENV.key?(env_key)
      end
      Config.new(opts)
    end

    def request(request_hash)
      default_request.(request_hash)
    end
    alias call request

    TRANSACTIONS.keys.each { |t| define_method(t) { |hash| default_request.public_send(t, hash) } }
  end
  configure
end
