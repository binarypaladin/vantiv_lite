require_relative 'spec_helper'

module VantivLite
  class RequestSpec < Minitest::Spec
    let(:authorization_params) do
      {
        'authorization' => {
          'orderId' => '01',
          'amount' => '10000',
          'orderSource' => 'ecommerce',
          'billToAddress' =>
          {
            'name' => 'John Johnson',
            'addressLine1' => '1 Main St',
            'city' => 'Las Vegas',
            'state' => 'NV',
            'zip' => '89139',
            'country' => 'US'
          },
          'card' => {
            'type' => 'VI',
            'number' => '4457010000000009',
            'expDate' => '0121',
            'cardValidationNum' => '349'
          }
        }
      }
    end

    let(:register_token_params) do
      {
        'registerTokenRequest' => {
          'orderId' => '1',
          'accountNumber' => '4457010000000009',
          'cardValidationNum' => '349'
        }
      }
    end

    it 'uses the default config by default' do
      Request.new.config.must_equal(VantivLite.default_config)
    end

    it 'can use a custom configuration' do
      config = VantivLite.default_config.with(version: '11.1')
      r = Request.new(config).(authorization_params)
      r['version'].must_equal('11.1')
    end

    it 'can post raw XML and return an XML string' do
      r = Request.new.post(FIXTURES_PATH.join('authorization_request.xml').read)
      r.code.must_equal('200')
      r.body.must_match(/litleOnlineResponse/)
      r.body.must_match(/response=\"0\"/)
      r.body.must_match(/Valid Format/)
    end

    it 'converts a hash to XML and posts it' do
      r = Request.new.(authorization_params)
      r.must_be_instance_of(Response)
      r['response'].must_equal('0')
      r.dig('authorizationResponse', 'orderId').must_equal('01')

      r = Request.new.(register_token_params)
      r.dig('registerTokenResponse', 'orderId').must_equal('1')
    end

    it 'can make convenient transactions' do
      r = Request.new.authorization(authorization_params['authorization'])
      r['orderId'].must_equal('01')

      r = Request.new.register_token(register_token_params['registerTokenRequest'])
      r['orderId'].must_equal('1')
    end
  end
end