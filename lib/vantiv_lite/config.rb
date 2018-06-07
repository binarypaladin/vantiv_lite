# frozen-string-literal: true

require 'net/http'
require 'uri'

module VantivLite
  class Config
    InvalidEnvironment = Class.new(StandardError)

    ENVS = {
      'sandbox' => URI('https://www.testvantivcnp.com/sandbox/communicator/online'),
      'prelive' => URI('https://payments.vantivprelive.com/vap/communicator/online'),
      'postlive' => URI('https://payments.vantivcnp.com/vap/communicator/online')
    }.freeze

    OPTS = %i[env merchant_id password proxy_url report_group username version xml_lib].freeze

    class Builder
      def self.call(&blk)
        new.(&blk)
      end

      def initialize
        @opts = {}
      end

      OPTS.each { |o| define_method(o) { |val| @opts[o] = val.to_s } }

      def call(&blk)
        instance_eval(&blk) if block_given?
        Config.new(@opts)
      end
    end

    class << self
      def build(&blk)
        Config::Builder.(&blk)
      end

      def with_obj(config)
        config.is_a?(self) ? config : new(config)
      end
    end

    attr_reader :proxy_uri, :sandbox, :uri
    alias sandbox? sandbox

    def initialize(**opts)
      @opts = opts.each_with_object({}) { |(k, v), h| OPTS.include?(k = k.to_sym) && h[k] = v.to_s }
      defaults!
      load_xml_lib
      env_valid?
      proxy_uri!
      @uri = ENVS[@opts[:env]]
    end

    def opts
      @opts.dup
    end

    def proxy_args
      @proxy_uri ? [@proxy_uri.host, @proxy_uri.port, @proxy_uri.user, @proxy_uri.password] : []
    end

    def with(**opts)
      self.class.new(@opts.merge(opts))
    end

    OPTS.each { |o| define_method(o) { @opts[o] } }

    private

    def default_xml_lib
      return 'Ox' if defined?(::Ox)
      return 'Nokogiri' if defined?(::Nokogiri)
      'REXML'
    end

    def defaults!
      @opts[:env] ||= 'sandbox'
      @opts[:report_group] ||= 'Default Report Group'
      @opts[:version] ||= '8.22'
      @opts[:xml_lib] ||= default_xml_lib
      return unless (@sandbox = (opts[:env] == 'sandbox'))
      @opts[:merchant_id] ||= 'default'
      @opts[:password] ||= 'sandbox'
      @opts[:username] ||= 'sandbox'
    end

    def env_valid?
      raise InvalidEnvironment, %(:env must be set to one of: "#{ENVS.keys.join('", "')}") unless
        ENVS.key?(@opts[:env])
    end

    def load_xml_lib
      require "vantiv_lite/xml/#{@opts[:xml_lib].downcase}"
    end

    def proxy_uri!
      return unless (url = @opts[:proxy_url] || ENV['HTTP_PROXY'] || ENV['http_proxy'])
      @proxy_uri = URI(url)
    end
  end
end
