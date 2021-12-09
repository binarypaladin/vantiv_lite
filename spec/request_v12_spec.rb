require_relative 'spec_helper'

class RequestV12Spec < Minitest::Spec
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

  let(:v12_config) do
    VantivLite.default_config.with(version: '12.20', username: 'FUNDA12', password: 'CERT!1212')
  end

  it 'can use a custom configuration' do
    r = VantivLite::V12::Request.new(v12_config).(authorization_params)
    r['version'].must_equal('12.20')
  end

  it 'can make convenient transactions' do
    xml = VantivLite::V12::Request.new(v12_config).format_xml(
      :authorization_request,
      authorization_params['authorization']
    )
    xml.include?('01').must_equal(true)

    xml = VantivLite::V12::Request.new(v12_config).format_xml(
      :register_token_request,
      register_token_params['registerTokenRequest']
    )
    xml.include?('4457010000000009').must_equal(true)
  end
end
