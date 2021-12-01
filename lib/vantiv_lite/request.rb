# frozen-string-literal: true

require 'securerandom'
require 'vantiv_lite/response'
require 'vantiv_lite/xml'

module VantivLite
  TRANSACTIONS = {
    capture: 'capture',
    credit: 'credit',
    sale: 'sale',
    void: 'void'
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
      http.dup.start { |h| h.request(post_request(xml)) }
    end

    TRANSACTIONS.each do |name, request_key|
      define_method(name) do |hash|
        call({ request_key => hash }, "#{request_key.sub(/Request$/, '')}Response")
      end
    end

    def register_token(request_hash)
      hash = request_hash(:register_token_request, request_hash)
      Response.new(post(serializer.(hash)), 'registerTokenResponse', parser: @parser)
    end

    def auth_reversal(request_hash)
      hash = request_hash(:auth_reversal_request, request_hash)
      Response.new(post(serializer.(hash)), 'authReversalResponse', parser: @parser)
    end

    def authorization(request_hash)
      hash = request_hash(:authorization_request, request_hash)
      Response.new(post(serializer.(hash)), 'authorizationResponse', parser: @parser)
    end

    private

    def authorization_request(hash) # rubocop:disable Metrics/MethodLength
      {
        authorizationRequest: {
          id: SecureRandom.uuid,
          reportGroup: config.report_group,
          {
            orderId: hash['orderId'],
            amount: hash['amount'],
            orderSource: hash['orderSource'],
            billToAddress: bill_to_address(hash['billToAddress']),
            card: card(hash['card'])
          }
        }
      }
    end

    def auth_reversal_request(hash)
      {
        authReversalRequest: {
          id: SecureRandom.uuid,
          reportGroup: config.report_group,
          {
            cnpTxnId: hash['txn_id'],
            amount: hash['amount']
          }
        }.compact
      }
    end

    def bill_to_address(address)
      return nil if address == nil

      {
        name: address['name'],
        addressLine1: address['addressLine1'],
        city: address['city'],
        state: address['state'],
        zip: address['zip'],
        country: address['country']
      }
    end

    def card(card_info)
      {
        type: card_info['type'],
        number: card_info['number'],
        expDate: card_info['expDate'],
        cardValidationNum: card_info['cardValidationNum']
      }
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

    def request_hash(method_name, request_hash)
      {
        'cnpOnlineRequest' => {
          'xmlns' => 'http://www.vantivcnp.com/schema',
          'version' => config.version,
          'merchantId' => config.merchant_id,
          'authentication' => { 'user' => config.username, 'password' => config.password }
        }.merge(self.send(method_name, request_hash))
      }
    end

    def register_token_request(request_hash)
      {
        registerTokenRequest: {
          id: SecureRandom.uuid,
          reportGroup: config.report_group,
          {
            accountNumber: request_hash['accountNumber'],
            cardValidationNum: request_hash['cardValidationNum']
          }
        }
      }
    end

    def format_request(request_hash)
      request_hash(:insert_default_attributes, request_hash)
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
