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

    it 'can make convenient transactions' do
      xml = Request.new.format_xml(:authorization_request, authorization_params['authorization'])
      xml.include?('01').must_equal(true)

      xml = Request.new.format_xml(
        :register_token_request,
        register_token_params['registerTokenRequest']
      )
      xml.include?('4457010000000009').must_equal(true)
    end
  end
end
