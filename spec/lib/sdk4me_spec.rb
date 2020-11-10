require 'spec_helper'

describe Sdk4me do
  it 'should define a default configuration' do
    conf = Sdk4me.configuration.current

    expect(conf.keys.sort).to eq(%i[access_token account api_token api_version block_at_rate_limit ca_file host logger max_retry_time max_throttle_time proxy_host proxy_password proxy_port proxy_user read_timeout source])

    expect(conf[:logger].class).to eq(::Logger)
    expect(conf[:host]).to eq('https://api.4me.com')
    expect(conf[:api_version]).to eq('v1')

    expect(conf[:max_retry_time]).to eq(300)
    expect(conf[:read_timeout]).to eq(25)
    expect(conf[:block_at_rate_limit]).to be_truthy

    expect(conf[:proxy_port]).to eq(8080)

    %i[access_token api_token account source proxy_host proxy_user proxy_password].each do |no_default|
      expect(conf[no_default]).to be_nil
    end

    expect(conf[:ca_file]).to eq('../ca-bundle.crt')
  end

  it 'should define a logger' do
    expect(Sdk4me.logger.class).to eq(::Logger)
  end

  it 'should define an exception class' do
    expect { raise ::Sdk4me::Exception, 'test' }.to raise_error('test')
  end
end
