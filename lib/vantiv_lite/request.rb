# frozen-string-literal: true

require 'securerandom'
require 'vantiv_lite/response'
require 'vantiv_lite/xml'

module VantivLite
  TRANSACTIONS = {
    auth_reversal: :auth_reversal,
    authorization: :authorization,
    capture: :capture,
    credit: :credit,
    register_token: :register_token_request,
    sale: :sale,
    void: :void
  }.freeze

  class Request
    InvalidConfig = Class.new(StandardError)
    ResponseError = Class.new(StandardError)

    attr_reader :config, :http, :serializer

    def initialize(config = VantivLite.default_config, http: nil, serializer: nil)
      raise InvalidConfig, 'invalid or missing config' unless config.is_a?(Config)
      @config = config
      @http = http || _http
      @parser = XML.parser_with(config.xml_lib)
      @serializer = serializer || XML.serializer_with(config.xml_lib)
    end

    def call(request_hash, *dig_keys)
      Response.new(post(serializer.(format_request(request_hash))), *dig_keys, parser: @parser)
    end

    def post(xml)
      http.start { |h| h.request(post_request(xml)) }
    end

    TRANSACTIONS.each do |name, request_name|
      define_method(name) { |hash| call({ request_name => hash }, :"#{name}_response") }
    end

    private

    def _http
      Net::HTTP.new(config.uri.host, config.uri.port, *config.proxy_args).tap do |h|
        h.use_ssl = true if config.uri.scheme == 'https'
      end
    end

    def default_attributes_with(hash)
      hash['id'] ||= SecureRandom.hex(12)
      hash['reportGroup'] ||= config.report_group
      hash
    end

    def format_request(request_hash)
      {
        'litleOnlineRequest' => {
          'xmlns' => 'http://www.litle.com/schema',
          'version' => config.version,
          'merchantId' => config.merchant_id,
          'authentication' => { 'user' => config.username, 'password' => config.password }
        }.merge(insert_default_attributes(lower_camelize_keys(request_hash)))
      }
    end

    def insert_default_attributes(request_hash)
      request_hash.each_with_object({}) do |(k, obj), h|
        h[k] = XML.hash_or_array(obj) { |o| default_attributes_with(o) }
      end
    end

    def lower_camelize_keys(hash)
      XML.transform_keys(hash) do |k|
        if k.is_a?(String)
          k
        else
          k.to_s.gsub(/_[a-z]/i) { |m| m[1].upcase }.tap { |s| s[0] = s[0].downcase }
        end
      end
    end

    def post_request(xml)
      Net::HTTP::Post.new(config.uri.path).tap do |r|
        r['Content-Type'] ||= 'text/xml; charset=UTF-8'
        r.body = xml
      end
    end
  end
end
