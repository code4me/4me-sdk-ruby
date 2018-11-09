require 'spec_helper'

describe Sdk4me::Response do
  before(:each) do
    @client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
    @person_hash = {
        addresses:[],
        contacts:[ {id: 1365, label: 'work', telephone: '7139872946'} ],
        id: 562,
        information: 'Info about John.',
        job_title: 'rolling stone',
        locale: 'en-US',
        location: 'Top of John Hill',
        name: 'John',
        organization: {id: 20, name: 'SDK4ME Institute'},
        picture_uri: nil,
        primary_email: 'john@example.com',
        site: {id:14, name: 'IT Training Facility'},
        time_format_24h: false,
        time_zone: 'Central Time (US & Canada)'
    }
    stub_request(:get, 'https://api.4me.com/v1/me').with(basic_auth: ['secret', 'x']).to_return(body: @person_hash.to_json)
    @response_hash = @client.get('me')

    @client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
    @people_array = [
        {id: 562, name: 'John', organization: { id: 20, name: 'SDK4ME Institute'}, site: {id: 14, name: 'IT Training Facility'} },
        {id: 560, name: 'Lucas', organization: { id: 20, name: 'SDK4ME Institute', office: { name: 'The Office'}}, site: {id: 14, name: 'IT Training Facility'} },
        {id: 561, name: 'Sheryl', organization: { id: 20, name: 'SDK4ME Institute'}, site: {id: 14, name: 'IT Training Facility'} }
    ]
    stub_request(:get, 'https://api.4me.com/v1/people').to_return(body: @people_array.to_json).with(basic_auth: ['secret', 'x'])
    @response_array = @client.get('people')
  end

  it 'should contain the request' do
    expect(@response_hash.request.class.name).to eq('Net::HTTP::Get')
    expect(@response_hash.request.path).to eq('/v1/me')
  end

  it 'should contain the full request' do
    expect(@response_hash.response.class.name).to eq('Net::HTTPOK')
    expect(@response_hash.response).to respond_to(:body)
  end

  it 'should provide easy access to the body' do
    expect(@response_hash.body).to include(%("primary_email":"john@example.com"))
  end

  context 'json/message' do
    it 'should provide the JSON value for single records' do
      be_json_eql(@response_hash.json, @person_hash)
    end

    it 'should provide the JSON value for lists' do
      be_json_eql(@response_array.json, @people_array)
    end

    it 'should provide indifferent access for single records' do
      expect(@response_hash.json['organization']['name']).to eq('SDK4ME Institute')
      expect(@response_hash.json[:organization][:name]).to eq('SDK4ME Institute')
      expect(@response_hash.json[:organization]['name']).to eq('SDK4ME Institute')
      expect(@response_hash.json['organization'][:name]).to eq('SDK4ME Institute')
    end

    it 'should provide indifferent access for lists' do
      expect(@response_array.json.first['site']['name']).to eq('IT Training Facility')
      expect(@response_array.json.first[:site][:name]).to eq('IT Training Facility')
      expect(@response_array.json.last[:site]['name']).to eq('IT Training Facility')
      expect(@response_array.json.last['site'][:name]).to eq('IT Training Facility')
    end

    it 'should add a message if the body is empty' do
      stub_request(:get, 'https://api.4me.com/v1/organizations').with(basic_auth: ['secret', 'x']).to_return(status: 429, body: nil)
      response = @client.get('organizations')

      message = '429: empty body'
      expect(response.json[:message]).to eq(message)
      expect(response.json['message']).to eq(message)
      expect(response.message).to eq(message)
    end

    it 'should add a message if the HTTP response is not OK' do
      stub_request(:get, 'https://api.4me.com/v1/organizations').with(basic_auth: ['secret', 'x']).to_return(status: 429, body: {message: 'Too Many Requests'}.to_json)
      response = @client.get('organizations')

      message = '429: Too Many Requests'
      expect(response.json[:message]).to eq(message)
      expect(response.json['message']).to eq(message)
      expect(response.message).to eq(message)
    end

    it 'should add a message if the JSON body cannot be parsed' do
      stub_request(:get, 'https://api.4me.com/v1/organizations').with(basic_auth: ['secret', 'x']).to_return(body: '==$$!invalid')
      response = @client.get('organizations')

      message = "Invalid JSON - 765: unexpected token at '==$$!invalid' for:\n#{response.body}"
      expect(response.json[:message]).to eq(message)
      expect(response.json['message']).to eq(message)
      expect(response.message).to eq(message)
    end

    it 'should have a blank message when single record is succesfully retrieved' do
      expect(@response_hash.message).to be_nil
    end

    it 'should have a blank message when single record is succesfully retrieved' do
      expect(@response_array.message).to be_nil
    end

  end

  it 'should define empty' do
    stub_request(:get, 'https://api.4me.com/v1/organizations').with(basic_auth: ['secret', 'x']).to_return(status: 429, body: nil)
    response = @client.get('organizations')

    expect(response.empty?).to be_truthy
    expect(@person_hash.empty?).to be_falsey
    expect(@people_array.empty?).to be_falsey
  end

  context 'valid' do
    it 'should be valid when the message is nil' do
      expect(@response_hash).to receive(:message){ nil }
      expect(@response_hash.valid?).to be_truthy
    end

    it 'should not be valid when the message is not nil' do
      expect(@response_array).to receive(:message){ 'invalid' }
      expect(@response_array.valid?).to be_falsey
    end
  end

  context '[] access' do
    context 'single records' do
      it 'should delegate [] to the json' do
        expect(@response_hash[:name]).to eq('John')
      end

      it 'should allow multiple keys' do
        expect(@response_hash[:organization, 'name']).to eq('SDK4ME Institute')
      end

      it 'should allow nils when using multiple keys' do
        expect(@response_hash[:organization, :missing, 'name']).to be_nil
      end
    end

    context 'list of records' do
      it 'should delegate [] to the json of each record' do
        expect(@response_array['name']).to eq(['John', 'Lucas', 'Sheryl'])
      end

      it 'should allow multiple keys' do
        expect(@response_array[:organization, 'name']).to eq(['SDK4ME Institute', 'SDK4ME Institute', 'SDK4ME Institute'])
      end

      it 'should allow nils when using multiple keys' do
        expect(@response_array[:organization, :office, 'name']).to eq([nil, 'The Office', nil])
      end
    end
  end

  context 'size' do
    it 'should return 1 for single records' do
      expect(@response_hash.size).to eq(1)
    end

    it 'should return the array size for list records' do
      expect(@response_array.size).to eq(3)
    end

    it 'should return nil if an error message is present' do
      expect(@response_hash).to receive(:message){ 'error message' }
      expect(@response_hash.size).to eq(0)
    end
  end

  context 'count' do
    it 'should return 1 for single records' do
      expect(@response_hash.count).to eq(1)
    end

    it 'should return the array size for list records' do
      expect(@response_array.count).to eq(3)
    end

    it 'should return nil if an error message is present' do
      expect(@response_hash).to receive(:message){ 'error message' }
      expect(@response_hash.count).to eq(0)
    end
  end

  context 'pagination' do
    before(:each) do
      @pagination_header = {
          'X-Pagination-Per-Page' => 3,
          'X-Pagination-Current-Page' => 1,
          'X-Pagination-Total-Pages' => 2,
          'X-Pagination-Total-Entries' => 5,
          'Link' => '<https://api.4me.com/v1/people?page=1&per_page=3>; rel="first",<https://api.4me.com/v1/people?page=2&per_page=3>; rel="next", <https://api.4me.com/v1/people?page=2&per_page=3>; rel="last"',
      }
      allow(@response_array.response).to receive('header'){ @pagination_header }
    end

    it "should retrieve per_page from the 'X-Pagination-Per-Page' header" do
      expect(@response_array.per_page).to eq(3)
    end

    it "should retrieve current_page from the 'X-Pagination-Current-Page' header" do
      expect(@response_array.current_page).to eq(1)
    end

    it "should retrieve total_pages from the 'X-Pagination-Total-Pages' header" do
      expect(@response_array.total_pages).to eq(2)
    end

    it "should retrieve total_entries from the 'X-Pagination-Total-Entries' header" do
      expect(@response_array.total_entries).to eq(5)
    end

    {first: 'https://api.4me.com/v1/people?page=1&per_page=3',
     next: 'https://api.4me.com/v1/people?page=2&per_page=3',
     last: 'https://api.4me.com/v1/people?page=2&per_page=3'}.each do |relation, link|

      it "should define pagination link for :#{relation}" do
        expect(@response_array.pagination_link(relation)).to eq(link)
      end
    end

    {first: '/v1/people?page=1&per_page=3',
     next: '/v1/people?page=2&per_page=3',
     last: '/v1/people?page=2&per_page=3'}.each do |relation, link|

      it "should define pagination relative link for :#{relation}" do
        expect(@response_array.pagination_relative_link(relation)).to eq(link)
      end
    end
  end

  context 'throttled?' do
    it 'should not be trhottled by default' do
      expect(@response_hash.throttled?).to be_falsey
      expect(@response_array.throttled?).to be_falsey
    end

    it 'should check the return code' do
      stub_request(:get, 'https://api.4me.com/v1/organizations').with(basic_auth: ['secret', 'x']).to_return(status: 429, body: nil)
      response = @client.get('organizations')
      expect(response.throttled?).to be_truthy
    end

    it 'should check the return message' do
      stub_request(:get, 'https://api.4me.com/v1/organizations').with(basic_auth: ['secret', 'x']).to_return(status: 500, body: {message: 'Too Many Requests'}.to_json )
      response = @client.get('organizations')
      expect(response.throttled?).to be_truthy
    end
  end

  context 'to_s' do
    it 'should return the JSON as a string' do
      expect(@response_hash.to_s).to eq(JSON.parse(@person_hash.to_json).to_s)
    end

    it 'should return the message in case the response is not valid' do
      stub_request(:get, 'https://api.4me.com/v1/organizations').with(basic_auth: ['secret', 'x']).to_return(status: 429, body: nil)
      response = @client.get('organizations')
      expect(response.to_s).to eq('429: empty body')
    end
  end

end
