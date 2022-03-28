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

  let(:cardholder_authorization_params) do
    {
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
        'type' => 'MC',
        'number' => '5457010000000009',
        'expDate' => '0121',
        'cardValidationNum' => '349'
      },
      'cardholderAuthentication' => {
        'authenticationValue' => 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
        'authenticationProtocolVersion' => '2'
      }

    }
  end

  let(:visa_cardholder_authorization_params) do
    {
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
      },
      'cardholderAuthentication' => {
        'authenticationValue' => 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
        'authenticationProtocolVersion' => '2'
      }
    }
  end

  let(:register_token_params) do
    {
      'registerTokenRequest' => {
        'orderId' => '1',
        'accountNumber' => '4457010000000009',
        'cardValidationNum' => '349',
        'id' => '123',
        'customerId' => '123'
      }
    }
  end

  let(:auth_reversal_params) do
    {
      'id' => SecureRandom.uuid,
      'txnId' => SecureRandom.uuid,
      'amount' => '100'
    }
  end

  let(:v12_config) do
    VantivLite.default_config.with(
      version: '12.20',
      username: 'FUNDA12',
      password: 'CERT!1212',
      reportGroup: 'Prime Trust'
    )
  end

  it 'can use a custom configuration' do
    r = VantivLite::V12::Request.new(v12_config).(authorization_params)
    _(r['version']).must_equal('12.20')
  end

  it 'will correctly raise a ServerError' do
    request = VantivLite::V12::Request.new(v12_config)
    fake_response = Net::HTTPResponse.new('yes', '404', true)
    fake_response.body = 'test'
    response = nil
    _(fake_response.code).must_equal('404')
    begin
      response = VantivLite::Response.new(
        fake_response,
        'authorizationResponse',
        request,
        'cnpOnlineResponse',
        parser: request.parser
      )
    rescue StandardError => e
      _(e.message).must_equal('server responded with 404 instead of 200')
    ensure
      assert_nil(response)
    end
  end

  it 'can make convenient transactions' do
    request = VantivLite::V12::Request.new(v12_config)
    xml = request.format_xml(
      :authorization_request,
      authorization_params['authorization']
    )
    _(xml.include?('01')).must_equal(true)

    xml = request.format_xml(
      :register_token_request,
      register_token_params['registerTokenRequest']
    )
    _(xml.include?('4457010000000009')).must_equal(true)
    _(xml.include?('reportGroup="Prime Trust"')).must_equal(true)

    request.format_xml(
      :auth_reversal_request,
      auth_reversal_params
    )

    xml = request.format_xml(
      :authorization_request,
      cardholder_authorization_params
    )
    _(xml.include?('authenticationProtocolVersion')).must_equal(true)

    request.format_xml(
      :authorization_request,
      visa_cardholder_authorization_params
    )
  end

  it 'populates the response' do
    response = VantivLite.register_token(
      'id' => SecureRandom.uuid,
      'orderId' => nil,
      'customerId' => SecureRandom.uuid,
      'accountNumber' => '5222220000000005',
      'cardValidationNum' => '123'
    )
    _(response.to_h.nil?).must_equal(false)
  end
end
