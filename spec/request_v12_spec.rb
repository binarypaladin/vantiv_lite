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

  it 'will correctly raise a ServerError' do
    request = VantivLite::V12::Request.new(v12_config)
    fake_response = Net::HTTPResponse.new('yes', '404', true)
    fake_response.body = 'test'
    response = nil
    fake_response.code.must_equal('404')
    begin
      response = VantivLite::Response.new(
        fake_response,
        'authorizationResponse',
        request,
        parser: request.parser
      )
    rescue StandardError => e
      e.message.must_equal('server responded with 404 instead of 200')
    ensure
      assert_nil(response)
    end
  end

  it 'will correctly raise a ServerError' do
    request = VantivLite::V12::Request.new(v12_config)
    fake_response = Net::HTTPResponse.new('yes', '200', true)
    fake_response.body = '<cnp></cnp>'
    response = nil
    begin
      response = VantivLite::Response.new(
        fake_response,
        'authorizationResponse',
        request,
        parser: request.parser
      )
    rescue StandardError => e
      p e
    ensure
      assert_nil(response)
    end
  end

  it 'will correctly raise an Error' do
    request = VantivLite::V12::Request.new(v12_config)
    fake_response = Net::HTTPResponse.new('yes', '200', true)
    fake_response.body =
      '<cnpOnlineResponse response=\"20\" message=\"Error\"></cnpOnlineResponse>'
    response = nil
    begin
      response = VantivLite::Response.new(
        fake_response,
        'authorizationResponse',
        request,
        parser: request.parser
      )
    rescue StandardError => e
      p e
    ensure
      response.must_equal(nil)
    end
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

