# frozen-string-literal: true

require 'securerandom'
require 'vantiv_lite/response'
require 'vantiv_lite/xml'
require 'nokogiri'

module VantivLite
  class Request # rubocop:disable Metrics/ClassLength
    TRANSACTIONS = {
      credit: 'credit',
      sale: 'sale',
      void: 'void'
    }.freeze

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
      http.dup.start { |h| h.request(post_request(xml)) }
    end

    TRANSACTIONS.each do |name, request_key|
      define_method(name) do |hash|
        call({ request_key => hash }, "#{request_key.sub(/Request$/, '')}Response")
      end
    end

    def register_token(request_hash)
      xml = format_xml(:register_token_request, request_hash)
      Response.new(post(xml), 'registerTokenResponse', parser: @parser)
    end

    def auth_reversal(request_hash)
      xml = format_xml(:auth_reversal_request, request_hash)
      Response.new(post(xml), 'authReversalResponse', parser: @parser)
    end

    def authorization(request_hash)
      xml = format_xml(:authorization_request, request_hash)
      Response.new(post(xml), 'authorizationResponse', parser: @parser)
    end

    def capture(request_hash)
      xml = format_xml(:capture_request, request_hash)
      Response.new(post(xml), 'captureResponse', parser: @parser)
    end

    def format_xml(method_name, request_hash)    # rubocop:disable Metrics/MethodLength
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.cnpOnlineRequest(
          'xmlns' => 'http://www.vantivcnp.com/schema',
          'version' => config.version,
          'merchantId' => config.merchant_id
        ) do
          xml.authentication do
            xml.user config.username
            xml.password config.password
          end
          send(method_name, request_hash, xml)
        end
      end

      builder.to_xml
    end

    private

    def authorization_request(hash, xml)
      xml.authorization('id' => id(hash), 'reportGroup' => config.report_group) do
        xml.orderId hash['orderId']
        xml.amount hash['amount']
        xml.orderSource hash['orderSource']
        bill_to_address(hash['billToAddress'], xml)
        card(hash['card'], xml)
      end
    end

    def auth_reversal_request(hash, xml)
      xml.authReversal('id' => id(hash), 'reportGroup' => config.report_group) do
        xml.cnpTxnId hash['authorizationRequestId']
        xml.amount hash['amount']
      end
    end

    def bill_to_address(address, xml)
      return nil if address.nil?

      xml.billToAddress do
        xml.name address['name']
        xml.addressLine1 address['addressLine1']
        xml.city address['city']
        xml.state address['state']
        xml.zip address['zip']
        xml.country address['country']
      end
    end

    def capture_request(request_hash, xml)
      xml.capture(
        'id' => request_hash['fundsTransferId'] || SecureRandom.uuid,
        'reportGroup' => config.report_group
      ) do
        xml.cnpTxnId request_hash['authorizationRequestId']
        xml.orderId request_hash['orderId']
      end
    end

    def card(card_info, xml)
      return nil if card_info.nil?

      xml.card do
        xml.type card_info['type']
        xml.number card_info['number']
        xml.expDate card_info['expDate']
        xml.cardValidationNum card_info['cardValidationNum']
      end
    end

    def _http
      Net::HTTP.new(config.uri.host, config.uri.port, *config.proxy_args).tap do |h|
        h.use_ssl = true if config.uri.scheme == 'https'
      end
    end

    def default_attributes_with(hash)
      hash['id'] ||= '0'
      hash['reportGroup'] ||= config.report_group
      hash
    end

    def format_request(request_hash)
      {
        'cnpOnlineRequest' => {
          'xmlns' => 'http://www.vantivcnp.com/schema',
          'version' => config.version,
          'merchantId' => config.merchant_id,
          'authentication' => { 'user' => config.username, 'password' => config.password }
        }.merge(insert_default_attributes(request_hash))
      }
    end

    def register_token_request(request_hash, xml)
      xml.registerTokenRequest('id' => id(request_hash), 'reportGroup' => config.report_group) do
        xml.accountNumber request_hash['accountNumber']
        xml.cardValidationNum request_hash['cardValidationNum']
      end
    end

    def id(hash)
      hash['id'] || hash['authorizationRequestId'] || SecureRandom.uuid
    end

    def insert_default_attributes(request_hash)
      request_hash.each_with_object({}) do |(k, obj), h|
        h[k] = XML.hash_or_array(obj) { |o| default_attributes_with(o) }
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
