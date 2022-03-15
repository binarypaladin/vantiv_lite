# frozen-string-literal: true

require 'securerandom'
require 'vantiv_lite/response'
require 'vantiv_lite/xml'
require 'nokogiri'
require 'active_support'

module VantivLite
  module V12
    class Request # rubocop:disable Metrics/ClassLength
      V12_TRANSACTIONS = {
        credit: 'credit',
        void: 'void'
      }.freeze

      InvalidConfig = Class.new(StandardError)
      ResponseError = Class.new(StandardError)

      attr_reader :config, :http, :serializer, :parser

      def initialize(config = VantivLite.default_config, http: nil, serializer: nil)
        raise InvalidConfig, 'invalid or missing config' unless config.is_a?(Config)

        @config = config
        @http = http || _http
        @parser = XML.parser_with(config.xml_lib)
        @serializer = serializer || XML.serializer_with(config.xml_lib)
      end

      def call(request_hash, *dig_keys)
        Response.new(
          post(serializer.(format_request(request_hash))),
          *dig_keys,
          'cnpOnlineResponse',
          parser: @parser
        )
      end

      def post(xml)
        http.dup.start { |h| h.request(post_request(xml)) }
      end

      V12_TRANSACTIONS.each do |name, request_key|
        define_method(name) do |hash|
          call({ request_key => hash }, "#{request_key.sub(/Request$/, '')}Response")
        end
      end

      def register_token(request_hash)
        xml = format_xml(:register_token_request, request_hash)
        return_response(xml, 'registerTokenResponse')
      end

      def auth_reversal(request_hash)
        xml = format_xml(:auth_reversal_request, request_hash)
        return_response(xml, 'authReversalResponse')
      end

      def authorization(request_hash)
        xml = format_xml(:authorization_request, request_hash)
        return_response(xml, 'authorizationResponse')
      end

      def capture(request_hash)
        xml = format_xml(:capture_request, request_hash)
        return_response(xml, 'captureResponse')
      end

      def format_xml(method_name, request_hash) # rubocop:disable Metrics/MethodLength
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

      def sale(request_hash)
        xml = format_xml(:sale_request, request_hash)
        return_response(xml, 'saleResponse')
      end

      def return_response(xml, xml_header)
        Response.new(post(xml), xml_header, 'cnpOnlineResponse', parser: @parser)
      end

      private

      def authorization_request(request_hash, xml) # rubocop:disable Metrics/MethodLength
        xml.authorization(
          'id' => id(request_hash),
          'reportGroup' => report_group(request_hash),
          'customerId' => request_hash['customerId']
        ) do
          xml.orderId request_hash['orderId']
          xml.amount request_hash['amount']
          xml.processingType hash['processingType'] if !!hash['processingType']
          xml.orderSource request_hash['orderSource'] || 'ecommerce'
          bill_to_address(request_hash, xml)
          card(request_hash, xml)
          token(request_hash, xml)
          cardholder_authentication(request_hash, xml)
          custom_billing(request_hash, xml)
        end
      end

      def report_group(request_hash)
        request_hash['reportGroup'] || config.report_group
      end

      def auth_reversal_request(request_hash, xml)
        xml.authReversal(
          'id' => id(request_hash),
          'reportGroup' => report_group(request_hash),
          'customerId' => request_hash['customerId']
        ) do
          xml.cnpTxnId request_hash['txnId']
          xml.amount request_hash['amount'] unless request_hash['amount'].nil?
        end
      end

      def custom_billing(request_hash, xml)
        return if request_hash['customBilling'].nil?

        xml.customBilling do
          xml.descriptor request_hash.dig('customBilling', 'descriptor')
        end
      end

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      def bill_to_address(request_hash, xml)
        address = request_hash['billToAddress']
        return nil if address.nil?

        xml.billToAddress do
          xml.name address['name']
          xml.addressLine1 address['addressLine1']
          xml.addressLine2 address['addressLine2']
          xml.city address['city']
          xml.state address['state']
          xml.zip address['zip']
          xml.country address['country']
          xml.email address['email']
        end
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize

      def capture_request(request_hash, xml)
        xml.capture(
          'id' => request_hash['id'] || SecureRandom.uuid,
          'reportGroup' => report_group(request_hash),
          'customerId' => request_hash['customerId']
        ) do
          xml.cnpTxnId request_hash['txnId']
          xml.orderId request_hash['orderId'] if request_hash['orderId']
          bill_to_address(request_hash, xml)
        end
      end

      def cardholder_authentication(request_hash, xml) # rubocop disable Metrics/MethodLength
        cardholder_info = request_hash['cardholderAuthentication']
        return nil if cardholder_info.nil?

        xml.cardholderAuthentication do
          xml.authenticationValue cardholder_info['authenticationValue']
          if cardholder_info['authenticationTransactionId'].present? && !visa?(request_hash)
            xml.authenticationTransactionId cardholder_info['authenticationTransactionId']
          end
          remaining_cardholder(cardholder_info, xml)
        end
      end

      def remaining_cardholder(cardholder_info, xml)
        xml.customerIpAddress cardholder_info['customerIpAddress'] if
          cardholder_info['customerIpAddress'].present?
        xml.authenticatedByMerchant cardholder_info['authenticatedByMerchant'] if
          cardholder_info['authenticatedByMerchant'].present?
        xml.authenticationProtocolVersion cardholder_info['authenticationProtocolVersion'] if
          cardholder_info['authenticationProtocolVersion'].present?
        xml.tokenAuthenticationValue cardholder_info['tokenAuthenticationValue'] if
          cardholder_info['tokenAuthenticationValue'].present?
      end

      def visa?(request_hash)
        request_hash.dig('card', 'type').to_s.upcase == 'VI'
      end

      def card(request_hash, xml)
        return nil if request_hash['token']

        card_info = request_hash['card']
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

      def default_attributes_with(request_hash)
        request_hash['id'] ||= '0'
        request_hash['reportGroup'] ||= config.report_group
        request_hash
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
        xml.registerTokenRequest(
          'id' => id(request_hash),
          'reportGroup' => report_group(request_hash),
          'customerId' => request_hash['customerId']
        ) do
          xml.accountNumber request_hash['accountNumber']
          xml.cardValidationNum request_hash['cardValidationNum']
          bill_to_address(request_hash, xml)
        end
      end

      def id(request_hash)
        request_hash['id'] || request_hash['authorizationRequestId'] || SecureRandom.uuid
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

      def sale_request(request_hash, xml)
        xml.sale('id' => id(request_hash), 'reportGroup' => report_group(request_hash)) do
          xml.orderId request_hash['orderId']
          xml.amount request_hash['amount'] if request_hash['amount']
          xml.orderSource request_hash['orderSource']
          card(request_hash, xml)
          bill_to_address(request_hash, xml)
        end
      end

      def token(request_hash, xml)
        return nil if request_hash['token'].nil?

        token_hash = request_hash['token']
        xml.token do
          xml.cnpToken token_hash['litleToken']
          xml.expDate token_hash['expDate']
          xml.cardValidationNum token_hash['cardValidationNum']
        end
      end
    end
  end
end
