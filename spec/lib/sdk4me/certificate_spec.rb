require 'spec_helper'

describe 'ca-bundle.crt' do
  it 'should be able to connect to the 4me REST API' do
    WebMock.allow_net_connect!
    client = Sdk4me::Client.new(api_token: 'invalid', max_retry_time: -1)
    result = {}

    # no exception concerning the certificate
    expect { result[:response] = client.get('me') }.not_to raise_error
    response = result[:response]
    expect(response.valid?).to be_falsey

    # expecting 401 error
    expect(response.message).to start_with('401:')
  end

  it 'should be able to connect to the 4me REST API (access token)' do
    WebMock.allow_net_connect!
    client = Sdk4me::Client.new(access_token: 'invalid', max_retry_time: -1)
    result = {}

    # no exception concerning the certificate
    expect { result[:response] = client.get('me') }.not_to raise_error
    response = result[:response]
    expect(response.valid?).to be_falsey

    # expecting 401 error
    expect(response.message).to start_with('401:')
  end

  it 'should be able to connect to S3' do
    WebMock.allow_net_connect!
    http = Net::HTTP.new('sdk4me-eu.s3-eu-west-1.amazonaws.com', 443)
    http.read_timeout = 1
    http.use_ssl = true

    # no OpenSSL::SSL::SSLError please
    expect { http.start { |transport| transport.request(Net::HTTP::Get.new('/exports/20141107/')) } }.not_to raise_error
  end
end
