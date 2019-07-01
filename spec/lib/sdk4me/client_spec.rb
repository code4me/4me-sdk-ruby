require 'spec_helper'

describe Sdk4me::Client do

  context 'Sdk4me.config' do
    before(:each) do
      Sdk4me.configure do |config|
        config.max_retry_time = 120 # override default value (5400)
        config.api_token = 'secret' # set value
      end
    end

    it 'should define the MAX_PAGE_SIZE' do
      expect(Sdk4me::Client::MAX_PAGE_SIZE).to eq(100)
    end

    it 'should use the Sdk4me configuration' do
      client = Sdk4me::Client.new
      expect(client.option(:host)).to eq('https://api.4me.com') # default value
      expect(client.option(:api_token)).to eq('secret')          # value set using Sdk4me.config
      expect(client.option(:max_retry_time)).to eq(120)          # value overridden in Sdk4me.config
    end

    it 'should override the Sdk4me configuration' do
      client = Sdk4me::Client.new(host: 'https://demo.4me.com', api_token: 'unknown', block_at_rate_limit: true)
      expect(client.option(:read_timeout)).to eq(25)              # default value
      expect(client.option(:host)).to eq('https://demo.4me.com') # default value overridden in Client.new
      expect(client.option(:api_token)).to eq('unknown')          # value set using Sdk4me.config and overridden in Client.new
      expect(client.option(:max_retry_time)).to eq(120)           # value overridden in Sdk4me.config
      expect(client.option(:block_at_rate_limit)).to eq(true)     # value overridden in Client.new
    end

    [:host, :api_version, :api_token].each do |required_option|
      it "should require option #{required_option}" do
        expect { Sdk4me::Client.new(required_option => '') }.to raise_error("Missing required configuration option #{required_option}")
      end
    end

    [ ['https://api.4me.com',        true,  'api.4me.com',     443],
      ['https://api.example.com:777', true,  'api.example.com',  777],
      ['http://sdk4me.example.com',     false, 'sdk4me.example.com', 80],
      ['http://sdk4me.example.com:777', false, 'sdk4me.example.com', 777]
    ].each do |host, ssl, domain, port|
      it 'should parse ssl, host and port' do
        client = Sdk4me::Client.new(host: host)
        expect(client.instance_variable_get(:@ssl)).to eq(ssl)
        expect(client.instance_variable_get(:@domain)).to eq(domain)
        expect(client.instance_variable_get(:@port)).to eq(port)
      end
    end
  end

  it 'should set the ca-bundle.crt file' do
    http = Net::HTTP.new('https://api.4me.com')
    http.use_ssl = true

    on_disk = `ls #{http.ca_file}`
    expect(on_disk).not_to match(/cannot access/)
    expect(on_disk).to match(/\/ca-bundle.crt$/)
  end

  describe 'headers' do
    before(:each) do
      @client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
    end

    it 'should set the content type header' do
      stub = stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).with(headers: {'Content-Type' => 'application/json'}).to_return(body: {name: 'my name'}.to_json)
      @client.get('me')
      expect(stub).to have_been_requested
    end

    it 'should add the X-4me-Account header' do
      client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1, account: 'test')
      stub = stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).with(headers: {'X-4me-Account' => 'test'}).to_return(body: {name: 'my name'}.to_json)
      client.get('me')
      expect(stub).to have_been_requested
    end

    it 'should add the X-4me-Source header' do
      client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1, source: 'myapp')
      stub = stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).with(headers: {'X-4me-Source' => 'myapp'}).to_return(body: {name: 'my name'}.to_json)
      client.get('me')
      expect(stub).to have_been_requested
    end

    it 'should be able to override headers' do
      stub = stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).with(headers: {'Content-Type' => 'application/x-www-form-urlencoded'}).to_return(body: {name: 'my name'}.to_json)
      @client.get('me', {}, {'Content-Type' => 'application/x-www-form-urlencoded'})
      expect(stub).to have_been_requested
    end

    it 'should set the other headers' do
      stub = stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).with(headers: {'X-4me-Other' => 'value'}).to_return(body: {name: 'my name'}.to_json)
      @client.get('me', {}, {'X-4me-Other' => 'value'})
      expect(stub).to have_been_requested
    end

    it 'should accept headers in the each call' do
      stub = stub_request(:get, 'https://api.4me.com/v1/requests?fields=subject&page=1&per_page=100').with(basic_auth: ['secret', 'x']).with(headers: {'X-4me-Secret' => 'special'}).to_return(body: [{id: 1, subject: 'Subject 1'}, {id: 2, subject: 'Subject 2'}, {id: 3, subject: 'Subject 3'}].to_json)
      @client.each('requests', {fields: 'subject'}, {'X-4me-Secret' => 'special'}) do |request|
        expect(request[:subject]).to eq("Subject #{request[:id]}")
      end
      expect(stub).to have_been_requested
    end
  end

  context 'each' do
    before(:each) do
      @client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
    end

    it 'should yield each result' do
      stub_request(:get, 'https://api.4me.com/v1/requests?fields=subject&page=1&per_page=100').with(basic_auth: ['secret', 'x']).to_return(body: [{id: 1, subject: 'Subject 1'}, {id: 2, subject: 'Subject 2'}, {id: 3, subject: 'Subject 3'}].to_json)
      nr_of_requests = @client.each('requests', {fields: 'subject'}) do |request|
        expect(request[:subject]).to eq("Subject #{request[:id]}")
      end
      expect(nr_of_requests).to eq(3)
    end

    it 'should retrieve multiple pages' do
      stub_page1 = stub_request(:get, 'https://api.4me.com/v1/requests?page=1&per_page=2').with(basic_auth: ['secret', 'x']).to_return(body: [{id: 1, subject: 'Subject 1'}, {id: 2, subject: 'Subject 2'}].to_json, headers: {'Link' => '<https://api.4me.com/v1/requests?page=1&per_page=2>; rel="first",<https://api.4me.com/v1/requests?page=2&per_page=2>; rel="next",<https://api.4me.com/v1/requests?page=2&per_page=2>; rel="last"'})
      stub_page2 = stub_request(:get, 'https://api.4me.com/v1/requests?page=2&per_page=2').with(basic_auth: ['secret', 'x']).to_return(body: [{id: 3, subject: 'Subject 3'}].to_json, headers: {'Link' => '<https://api.4me.com/v1/requests?page=1&per_page=2>; rel="first",<https://api.4me.com/v1/requests?page=1&per_page=2>; rel="prev",<https://api.4me.com/v1/requests?page=2&per_page=2>; rel="last"'})
      nr_of_requests = @client.each('requests', {per_page: 2}) do |request|
        expect(request[:subject]).to eq("Subject #{request[:id]}")
      end
      expect(nr_of_requests).to eq(3)
      expect(stub_page2).to have_been_requested
    end
  end

  context 'get' do
    before(:each) do
      @client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
    end

    it 'should return a response' do
      stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).to_return(body: {name: 'my name'}.to_json)
      response = @client.get('me')
      expect(response[:name]).to eq('my name')
    end

    describe 'parameters' do

      [[nil, ''],
       [ 'normal',     'normal'],
       [ 'hello;<',    'hello%3B%3C'],
       [ true,         'true'],
       [ false,        'false'],
       [ DateTime.now, DateTime.now.new_offset(0).iso8601.gsub('+', '%2B')],
       [ Date.new,     Date.new.strftime('%Y-%m-%d')],
       [ Time.now,     Time.now.strftime('%H:%M')],
       [ ['first', 'second;<', true], 'first,second%3B%3C,true']
      ].each do |param_value, url_value|
        it "should cast #{param_value.class.name}: '#{param_value}' to '#{url_value}'" do
          stub = stub_request(:get, "https://api.4me.com/v1/me?value=#{url_value}").with(basic_auth: ['secret', 'x']).to_return(body: {name: 'my name'}.to_json)
          @client.get('me', {value: param_value})
          expect(stub).to have_been_requested
        end
      end

      it 'should not cast arrays in post and put calls' do
        client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
        stub = stub_request(:post, 'https://api.4me.com/v1/people').with(basic_auth: ['secret', 'x']).with(body: {user_ids: [1, 2, 3]}, headers: {'X-4me-Custom' => 'custom'}).to_return(body: {id: 101}.to_json)
        client.post('people', {user_ids: [1, 2, 3]}, {'X-4me-Custom' => 'custom'})
        expect(stub).to have_been_requested
      end

      it 'should not cast hashes in post and put calls' do
        client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
        stub = stub_request(:patch, 'https://api.4me.com/v1/people/55').with(basic_auth: ['secret', 'x']).with(body: '{"contacts_attributes":{"0":{"protocol":"email","label":"work","uri":"work@example.com"}}}', headers: {'X-4me-Custom' => 'custom'}).to_return(body: {id: 101}.to_json)
        client.put('people/55', {contacts_attributes: {0 => {protocol: :email, label: :work, uri: 'work@example.com'}}}, {'X-4me-Custom' => 'custom'})
        expect(stub).to have_been_requested
      end

      it 'should not double escape symbols' do
        client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
        stub = stub_request(:patch, 'https://api.4me.com/v1/people/55').with(basic_auth: ['secret', 'x']).with(body: '{"status":"waiting_for"}').to_return(body: {id: 101}.to_json)
        client.put('people/55', {status: :waiting_for})
        expect(stub).to have_been_requested
      end

      it 'should handle fancy filter operations' do
        now = DateTime.now
        stub = stub_request(:get, "https://api.4me.com/v1/people?created_at=>#{now.new_offset(0).iso8601.gsub('+', '%2B')}&id!=15").with(basic_auth: ['secret', 'x']).to_return(body: {name: 'my name'}.to_json)
        @client.get('people', {'created_at=>' => now, 'id!=' => 15})
        expect(stub).to have_been_requested
      end

      it 'should append parameters' do
        stub = stub_request(:get, 'https://api.4me.com/v1/people?id!=15&primary_email=me@example.com').with(basic_auth: ['secret', 'x']).to_return(body: {name: 'my name'}.to_json)
        @client.get('people?id!=15', {primary_email: 'me@example.com'})
        expect(stub).to have_been_requested
      end
    end
  end

  context 'patch' do
    [:put, :patch].each do |method|
      it 'should send patch requests with parameters and headers for #{method} calls' do
        client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
        stub = stub_request(:patch, 'https://api.4me.com/v1/people/1').with(basic_auth: ['secret', 'x']).with(body: {name: 'New Name'}, headers: {'X-4me-Custom' => 'custom'}).to_return(body: {id: 1}.to_json)
        client.send(method, 'people/1', {name: 'New Name'}, {'X-4me-Custom' => 'custom'})
        expect(stub).to have_been_requested
      end
    end
  end

  context 'post' do
    it 'should send post requests with parameters and headers' do
      client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
      stub = stub_request(:post, 'https://api.4me.com/v1/people').with(basic_auth: ['secret', 'x']).with(body: {name: 'New Name'}, headers: {'X-4me-Custom' => 'custom'}).to_return(body: {id: 101}.to_json)
      client.post('people', {name: 'New Name'}, {'X-4me-Custom' => 'custom'})
      expect(stub).to have_been_requested
    end
  end

  context 'delete' do
    it 'should send delete requests with parameters and headers' do
      client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
      stub = stub_request(:delete, 'https://api.4me.com/v1/people?id=value').with(basic_auth: ['secret', 'x']).with(headers: {'X-4me-Custom' => 'custom'}).to_return(body: '', status: 204)
      response = client.delete('people', {id: 'value'}, {'X-4me-Custom' => 'custom'})
      expect(stub).to have_been_requested
      expect(response.valid?).to be_truthy
      expect(response.json).to eq({})
    end
  end

  context 'attachments' do
    before(:each) do
      @client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
    end

    it 'should not log an error for XML responses' do
      xml = %(<?xml version="1.0" encoding="UTF-8"?>\n<details>some info</details>)
      stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).to_return(body: xml)
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug)
      expect_log("XML response:\n#{xml}", :debug)
      response = @client.get('me')
      expect(response.valid?).to be_falsey
      expect(response.raw.body).to eq(xml)
    end

    it 'should not log an error for redirects' do
      stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).to_return(body: '', status: 303, headers: {'Location' => 'http://redirect.example.com/to/here'})
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug)
      expect_log('Redirect: http://redirect.example.com/to/here', :debug)
      response = @client.get('me')
      expect(response.valid?).to be_falsey
      expect(response.raw.body).to be_nil
    end

    it "should not parse attachments for get requests" do
      expect(Sdk4me::Attachments).not_to receive(:new)
      stub_request(:get, 'https://api.4me.com/v1/requests/777?attachments=/tmp/first.png,/tmp/second.zip&note=note').with(basic_auth: ['secret', 'x']).to_return(body: {id: 777, upload_called: false}.to_json)

      response = @client.get('/requests/777', {note: 'note', attachments: ['/tmp/first.png', '/tmp/second.zip'] })
      expect(response.valid?).to be_truthy
      expect(response[:upload_called]).to be_falsey
    end

    [:post, :patch].each do |method|
      it "should parse attachments for #{method} requests" do
        attachments = double('Sdk4me::Attachments')
        expect(attachments).to receive(:upload_attachments!) do |path, data|
          expect(path).to eq '/requests/777'
          expect(data[:attachments]).to eq ['/tmp/first.png', '/tmp/second.zip']
          data.delete(:attachments)
          data[:note_attachments] = 'processed'
        end
        expect(Sdk4me::Attachments).to receive(:new).with(@client){ attachments }
        stub_request(method, 'https://api.4me.com/v1/requests/777').with(basic_auth: ['secret', 'x']).with(body: {note: 'note', note_attachments: 'processed' }).to_return(body: {id: 777, upload_called: true}.to_json)

        response = @client.send(method, '/requests/777', {note: 'note', attachments: ['/tmp/first.png', '/tmp/second.zip'] })
        expect(response.valid?).to be_truthy
        expect(response[:upload_called]).to be_truthy
      end
    end

  end

  context 'import' do
    before(:each) do
      @client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
      csv_mime_type = ['text/csv', 'text/comma-separated-values'].detect{|t| MIME::Types[t].any?} # which mime type is used depends on version of mime-types gem
      @multi_part_body = "--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"type\"\r\n\r\npeople\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"file\"; filename=\"#{@fixture_dir}/people.csv\"\r\nContent-Type: #{csv_mime_type}\r\n\r\nPrimary Email,Name\nchess.cole@example.com,Chess Cole\ned.turner@example.com,Ed Turner\r\n--0123456789ABLEWASIEREISAWELBA9876543210--"
      @multi_part_headers = {'Accept'=>'*/*', 'Content-Type'=>'multipart/form-data; boundary=0123456789ABLEWASIEREISAWELBA9876543210', 'User-Agent'=>'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/523.10.6 (KHTML, like Gecko) Version/3.0.4 Safari/523.10.6'}

      @import_queued_response = {body: {state: 'queued'}.to_json}
      @import_processing_response = {body: {state: 'processing'}.to_json}
      @import_done_response = {body: {state: 'done', results: {errors: 0, updated: 1, created: 1, failures: 0, unchanged: 0, deleted: 0}}.to_json}
      @import_failed_response = {body: {state: 'error', message: 'Invalid byte sequence in UTF-8 on line 2', results: {errors: 1, updated: 1, created: 0, failures: 1, unchanged: 0, deleted: 0}}.to_json}
      allow(@client).to receive(:sleep)
      WebMock.disable_net_connect!
    end

    it 'should import a CSV file' do
      stub_request(:post, 'https://api.4me.com/v1/import').with(basic_auth: ['secret', 'x']).with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      expect_log("Import file '#{@fixture_dir}/people.csv' successfully uploaded with token '68ef5ef0f64c0'.")

      response = @client.import(File.new("#{@fixture_dir}/people.csv"), 'people')
      expect(response[:token]).to eq('68ef5ef0f64c0')
    end

    it 'should import a CSV file by filename' do
      stub_request(:post, 'https://api.4me.com/v1/import').with(basic_auth: ['secret', 'x']).with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      response = @client.import("#{@fixture_dir}/people.csv", 'people')
      expect(response[:token]).to eq('68ef5ef0f64c0')
    end

    it 'should wait for the import to complete' do
      stub_request(:post, 'https://api.4me.com/v1/import').with(basic_auth: ['secret', 'x']).with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      progress_stub = stub_request(:get, 'https://api.4me.com/v1/import/68ef5ef0f64c0').with(basic_auth: ['secret', 'x'])
                        .to_return(@import_queued_response, @import_processing_response)
                        .then.to_raise(StandardError.new('network error'))
                        .then.to_return(@import_done_response)

      # verify the correct log statement are made
      expect_log('Sending POST request to api.4me.com:443/v1/import', :debug)
      expect_log("Response:\n{\n  \"token\": \"68ef5ef0f64c0\"\n}", :debug)
      expect_log("Import file '#{@fixture_dir}/people.csv' successfully uploaded with token '68ef5ef0f64c0'.")
      expect_log('Sending GET request to api.4me.com:443/v1/import/68ef5ef0f64c0', :debug)
      expect_log("Response:\n{\n  \"state\": \"queued\"\n}", :debug)
      expect_log("Import of '#{@fixture_dir}/people.csv' is queued. Checking again in 30 seconds.", :debug)
      expect_log('Sending GET request to api.4me.com:443/v1/import/68ef5ef0f64c0', :debug)
      expect_log("Response:\n{\n  \"state\": \"processing\"\n}", :debug)
      expect_log("Import of '#{@fixture_dir}/people.csv' is processing. Checking again in 30 seconds.", :debug)
      expect_log('Sending GET request to api.4me.com:443/v1/import/68ef5ef0f64c0', :debug)
      expect_log("GET request to api.4me.com:443/v1/import/68ef5ef0f64c0 failed: 500: No Response from Server - network error for 'api.4me.com:443/v1/import/68ef5ef0f64c0'", :error)
      expect_log('Sending GET request to api.4me.com:443/v1/import/68ef5ef0f64c0', :debug)
      expect_log("Response:\n{\n  \"state\": \"done\",\n  \"results\": {\n    \"errors\": 0,\n    \"updated\": 1,\n    \"created\": 1,\n    \"failures\": 0,\n    \"unchanged\": 0,\n    \"deleted\": 0\n  }\n}", :debug)

      response = @client.import("#{@fixture_dir}/people.csv", 'people', true)
      expect(response[:state]).to eq('done')
      expect(response[:results][:updated]).to eq(1)
      expect(progress_stub).to have_been_requested.times(4)
    end

    it 'should wait for the import to fail' do
      stub_request(:post, 'https://api.4me.com/v1/import').with(basic_auth: ['secret', 'x']).with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      progress_stub = stub_request(:get, 'https://api.4me.com/v1/import/68ef5ef0f64c0').with(basic_auth: ['secret', 'x']).to_return(@import_queued_response, @import_processing_response, @import_failed_response)

      expect{ @client.import("#{@fixture_dir}/people.csv", 'people', true) }.to raise_error(Sdk4me::Exception, "Unable to monitor progress for people import. Invalid byte sequence in UTF-8 on line 2")
      expect(progress_stub).to have_been_requested.times(4)
    end

    it 'should not continue when there is an error connecting to 4me' do
      stub_request(:post, 'https://api.4me.com/v1/import').with(basic_auth: ['secret', 'x']).with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      progress_stub = stub_request(:get, 'https://api.4me.com/v1/import/68ef5ef0f64c0').with(basic_auth: ['secret', 'x'])
                        .to_return(@import_queued_response, @import_processing_response)
                        .then.to_raise(StandardError.new('network error')) # twice

      expect{ @client.import("#{@fixture_dir}/people.csv", 'people', true) }.to raise_error(Sdk4me::Exception, "Unable to monitor progress for people import. 500: No Response from Server - network error for 'api.4me.com:443/v1/import/68ef5ef0f64c0'")
      expect(progress_stub).to have_been_requested.times(4)
    end

    it 'should return an invalid response in case waiting for progress is false' do
      stub_request(:post, 'https://api.4me.com/v1/import').with(basic_auth: ['secret', 'x']).with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {message: 'oops!'}.to_json)
      response = @client.import("#{@fixture_dir}/people.csv", 'people', false)
      expect(response.valid?).to be_falsey
      expect(response.message).to eq('oops!')
    end

    it 'should raise an UploadFailed exception in case waiting for progress is true' do
      stub_request(:post, 'https://api.4me.com/v1/import').with(basic_auth: ['secret', 'x']).with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {message: 'oops!'}.to_json)
      expect{ @client.import("#{@fixture_dir}/people.csv", 'people', true) }.to raise_error(Sdk4me::UploadFailed, 'Failed to queue people import. oops!')
    end

  end


  context 'export' do
    before(:each) do
      @client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)

      @export_queued_response = {body: {state: 'queued'}.to_json}
      @export_processing_response = {body: {state: 'processing'}.to_json}
      @export_done_response = {body: {state: 'done', url: 'https://download.example.com/export.zip?AWSAccessKeyId=12345'}.to_json}
      allow(@client).to receive(:sleep)
    end

    it 'should export multiple types' do
      stub_request(:post, 'https://api.4me.com/v1/export').with(basic_auth: ['secret', 'x']).with(body: {type: 'people,people_contact_details'}).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      expect_log("Export for 'people,people_contact_details' successfully queued with token '68ef5ef0f64c0'.")

      response = @client.export(['people', 'people_contact_details'])
      expect(response[:token]).to eq('68ef5ef0f64c0')
    end

    it 'should indicate when nothing is exported' do
      stub_request(:post, 'https://api.4me.com/v1/export').with(basic_auth: ['secret', 'x']).with(body: {type: 'people', from: '2012-03-30T23:00:00+00:00'}).to_return(status: 204)
      expect_log("No changed records for 'people' since 2012-03-30T23:00:00+00:00.")

      response = @client.export('people', DateTime.new(2012,03,30,23,00,00))
      expect(response[:token]).to be_nil
    end

    it 'should export since a certain time' do
      stub_request(:post, 'https://api.4me.com/v1/export').with(basic_auth: ['secret', 'x']).with(body: {type: 'people', from: '2012-03-30T23:00:00+00:00'}).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      expect_log("Export for 'people' successfully queued with token '68ef5ef0f64c0'.")

      response = @client.export('people', DateTime.new(2012,03,30,23,00,00))
      expect(response[:token]).to eq('68ef5ef0f64c0')
    end

    it 'should export with locale' do
      stub_request(:post, 'https://api.4me.com/v1/export').with(basic_auth: ['secret', 'x']).with(body: {type: 'translations', locale: 'nl'}).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      expect_log("Export for 'translations' successfully queued with token '68ef5ef0f64c0'.")

      response = @client.export('translations', nil, nil, 'nl')
      expect(response[:token]).to eq('68ef5ef0f64c0')
    end

    it 'should wait for the export to complete' do
      stub_request(:post, 'https://api.4me.com/v1/export').with(basic_auth: ['secret', 'x']).with(body: {type: 'people'}).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      progress_stub = stub_request(:get, 'https://api.4me.com/v1/export/68ef5ef0f64c0').with(basic_auth: ['secret', 'x'])
                        .to_return(@export_queued_response, @export_processing_response)
                        .then.to_raise(StandardError.new('network error'))
                        .then.to_return(@export_done_response)

      # verify the correct log statement are made
      expect_log('Sending POST request to api.4me.com:443/v1/export', :debug)
      expect_log(%(Response:\n{\n  "token": "68ef5ef0f64c0"\n}), :debug)
      expect_log("Export for 'people' successfully queued with token '68ef5ef0f64c0'.")
      expect_log('Sending GET request to api.4me.com:443/v1/export/68ef5ef0f64c0', :debug)
      expect_log(%(Response:\n{\n  "state": "queued"\n}), :debug)
      expect_log("Export of 'people' is queued. Checking again in 30 seconds.", :debug)
      expect_log('Sending GET request to api.4me.com:443/v1/export/68ef5ef0f64c0', :debug)
      expect_log(%(Response:\n{\n  "state": "processing"\n}), :debug)
      expect_log("Export of 'people' is processing. Checking again in 30 seconds.", :debug)
      expect_log('Sending GET request to api.4me.com:443/v1/export/68ef5ef0f64c0', :debug)
      expect_log("GET request to api.4me.com:443/v1/export/68ef5ef0f64c0 failed: 500: No Response from Server - network error for 'api.4me.com:443/v1/export/68ef5ef0f64c0'", :error)
      expect_log('Sending GET request to api.4me.com:443/v1/export/68ef5ef0f64c0', :debug)
      expect_log(%(Response:\n{\n  "state": "done",\n  "url": "https://download.example.com/export.zip?AWSAccessKeyId=12345"\n}), :debug)

      response = @client.export('people', nil, true)
      expect(response[:state]).to eq('done')
      expect(response[:url]).to eq('https://download.example.com/export.zip?AWSAccessKeyId=12345')
      expect(progress_stub).to have_been_requested.times(4)
    end

    it 'should not continue when there is an error connecting to 4me' do
      stub_request(:post, 'https://api.4me.com/v1/export').with(basic_auth: ['secret', 'x']).with(body: {type: 'people'}).to_return(body: {token: '68ef5ef0f64c0'}.to_json)
      progress_stub = stub_request(:get, 'https://api.4me.com/v1/export/68ef5ef0f64c0').with(basic_auth: ['secret', 'x'])
                        .to_return(@export_queued_response, @export_processing_response)
                        .then.to_raise(StandardError.new('network error')) # twice

      expect{ @client.export('people', nil, true) }.to raise_error(Sdk4me::Exception, "Unable to monitor progress for 'people' export. 500: No Response from Server - network error for 'api.4me.com:443/v1/export/68ef5ef0f64c0'")
      expect(progress_stub).to have_been_requested.times(4)
    end

    it 'should return an invalid response in case waiting for progress is false' do
      stub_request(:post, 'https://api.4me.com/v1/export').with(basic_auth: ['secret', 'x']).with(body: {type: 'people'}).to_return(body: {message: 'oops!'}.to_json)
      response = @client.export('people')
      expect(response.valid?).to be_falsey
      expect(response.message).to eq('oops!')
    end

    it 'should raise an UploadFailed exception in case waiting for progress is true' do
      stub_request(:post, 'https://api.4me.com/v1/export').with(basic_auth: ['secret', 'x']).with(body: {type: 'people'}).to_return(body: {message: 'oops!'}.to_json)
      expect{ @client.export('people', nil, true) }.to raise_error(Sdk4me::UploadFailed, "Failed to queue 'people' export. oops!")
    end

  end

  context 'retry' do
    it 'should not retry when max_retry_time = -1' do
      stub = stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).to_raise(StandardError.new('network error'))
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug )
      expect_log("GET request to api.4me.com:443/v1/me failed: 500: No Response from Server - network error for 'api.4me.com:443/v1/me'", :error)

      client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
      response = client.get('me')
      expect(stub).to have_been_requested.times(1)
      expect(response.valid?).to be_falsey
      expect(response.message).to eq("500: No Response from Server - network error for 'api.4me.com:443/v1/me'")
    end

    it 'should not retry 4 times when max_retry_time = 16' do
      stub = stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).to_raise(StandardError.new('network error'))
      [2,4,8].each_with_index do |secs, i|
        expect_log('Sending GET request to api.4me.com:443/v1/me', :debug )
        expect_log("Request failed, retry ##{i+1} in #{secs} seconds: 500: No Response from Server - network error for 'api.4me.com:443/v1/me'", :warn)
      end
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug )

      client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: 16)
      allow(client).to receive(:sleep)
      response = client.get('me')
      expect(stub).to have_been_requested.times(4)
      expect(response.valid?).to be_falsey
      expect(response.message).to eq("500: No Response from Server - network error for 'api.4me.com:443/v1/me'")
    end

    it 'should return the response after retry succeeds' do
      stub = stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).to_raise(StandardError.new('network error')).then.to_return(body: {name: 'my name'}.to_json)
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug )
      expect_log("Request failed, retry #1 in 2 seconds: 500: No Response from Server - network error for 'api.4me.com:443/v1/me'", :warn)
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug )
      expect_log(%(Response:\n{\n  "name": "my name"\n}), :debug )

      client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: 16)
      allow(client).to receive(:sleep)
      response = client.get('me')
      expect(stub).to have_been_requested.times(2)
      expect(response.valid?).to be_truthy
      expect(response[:name]).to eq('my name')
    end
  end

  context 'rate limiting' do
    it 'should not block on rate limit when block_at_rate_limit is false' do
      stub = stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).to_return(status: 429, body: {message: 'Too Many Requests'}.to_json)
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug )
      expect_log("GET request to api.4me.com:443/v1/me failed: 429: Too Many Requests", :error)

      client = Sdk4me::Client.new(api_token: 'secret', block_at_rate_limit: false)
      response = client.get('me')
      expect(stub).to have_been_requested.times(1)
      expect(response.valid?).to be_falsey
      expect(response.message).to eq('429: Too Many Requests')
    end

    it 'should block on rate limit when block_at_rate_limit is true' do
      stub = stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).to_return(status: 429, body: {message: 'Too Many Requests'}.to_json).then.to_return(body: {name: 'my name'}.to_json)
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug )
      expect_log('Request throttled, trying again in 300 seconds: 429: Too Many Requests', :warn)
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug )
      expect_log(%(Response:\n{\n  "name": "my name"\n}), :debug )

      client = Sdk4me::Client.new(api_token: 'secret', block_at_rate_limit: true, max_retry_time: 500)
      allow(client).to receive(:sleep)
      response = client.get('me')
      expect(stub).to have_been_requested.times(2)
      expect(response.valid?).to be_truthy
      expect(response[:name]).to eq('my name')
    end

    it 'should block on rate limit using Retry-After when block_at_rate_limit is true' do
      stub = stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).to_return(status: 429, body: {message: 'Too Many Requests'}.to_json, headers: {'Retry-After' => '20'}).then.to_return(body: {name: 'my name'}.to_json)
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug )
      expect_log('Request throttled, trying again in 20 seconds: 429: Too Many Requests', :warn)
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug )
      expect_log(%(Response:\n{\n  "name": "my name"\n}), :debug )

      client = Sdk4me::Client.new(api_token: 'secret', block_at_rate_limit: true)
      allow(client).to receive(:sleep)
      response = client.get('me')
      expect(stub).to have_been_requested.times(2)
      expect(response.valid?).to be_truthy
      expect(response[:name]).to eq('my name')
    end

    it 'should block on rate limit using Retry-After with minimum of 2 seconds when block_at_rate_limit is true' do
      stub = stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).to_return(status: 429, body: {message: 'Too Many Requests'}.to_json, headers: {'Retry-After' => '1'}).then.to_return(body: {name: 'my name'}.to_json)
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug )
      expect_log('Request throttled, trying again in 2 seconds: 429: Too Many Requests', :warn)
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug )
      expect_log(%(Response:\n{\n  "name": "my name"\n}), :debug )

      client = Sdk4me::Client.new(api_token: 'secret', block_at_rate_limit: true)
      allow(client).to receive(:sleep)
      response = client.get('me')
      expect(stub).to have_been_requested.times(2)
      expect(response.valid?).to be_truthy
      expect(response[:name]).to eq('my name')
    end
  end

  context 'logger' do
    before(:each) do
      @logger = Logger.new(STDOUT)
      @client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1, logger: @logger)
    end

    it 'should be possible to override the default logger' do
      stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).to_return(body: {name: 'my name'}.to_json)
      expect_log('Sending GET request to api.4me.com:443/v1/me', :debug, @logger )
      expect_log(%(Response:\n{\n  "name": "my name"\n}), :debug, @logger )
      @client.get('me')
    end
  end
end
