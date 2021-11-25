# Sdk4me::Client

Client for accessing the [4me REST API](https://developer.4me.com/v1/)

## Installation

Add this line to your application's Gemfile:

    gem '4me-sdk'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install 4me-sdk

## Configuration

### Global

```
Sdk4me.configure do |config|
  config.access_token = 'd41f5868feb65fc87fa2311a473a8766ea38bc40'
  config.account = 'my-sandbox'
  config.logger = Rails.logger
  ...
end
```

All options available:

* _logger_:         The [Ruby Logger](http://www.ruby-doc.org/stdlib-1.9.3/libdoc/logger/rdoc/Logger.html) instance, default: `Logger.new(STDOUT)`
* _host_:           The [4me REST API host](https://developer.4me.com/v1/#service-url), default: 'https://api.4me.com'
* _api_version_:    The [4me REST API version](https://developer.4me.com/v1/#service-url), default: 'v1'
* _access_token_:   (**required**) The [4me access token](https://developer.4me.com/v1/#authentication)
* _api_token_:      (**deprecated**) The [4me API token](https://developer.4me.com/v1/#api-tokens)
* _account_:        Specify a [different account](https://developer.4me.com/v1/#multiple-accounts) to work with
* _source_:         The [source](https://developer.4me.com/v1/general/source/) used when creating new records
* _user_agent_:     The User-Agent header of each request. Defaults to 4me-sdk-ruby/(version)
* _max_retry_time_: maximum nr of seconds to retry a request on a failed response (default = 300 = 5 minutes)<br/>
  The sleep time between retries starts at 2 seconds and doubles after each retry, i.e.
  2, 6, 18, 54, 162, 486, 1458, ... seconds.<br/>
  Set to 0 to prevent retries.
* _read_timeout_:   [HTTP read timeout](http://ruby-doc.org/stdlib-2.0.0/libdoc/net/http/rdoc/Net/HTTP.html#method-i-read_timeout-3D) in seconds (default = 25)
* _block_at_rate_limit_: Set to `true` to block the request until the [rate limit](https://developer.4me.com/v1/#rate-limiting) is lifted, default: `true`<br/>
  The `Retry-After` header is used to compute when the retry should be performed. If that moment is later than the _max_throttle_time_ the request will not be blocked and the throttled response is returned.
* _max_throttle_time_: maximum nr of seconds to retry a request on a rate limiter (default = 3660 = 1 hour and 1 minute)<br/>
* _proxy_host_:     Define in case HTTP traffic needs to go through a proxy
* _proxy_port_:     Port of the proxy, defaults to 8080
* _proxy_user_:     Proxy user
* _proxy_password_: Proxy password
* _ca_file_:        Certificate file (defaults to the provided ca-bundle.crt file from Mozilla)

### Override

Each time an 4me SDK Client is instantiated it is possible to override the [global configuration](#global) like so:

```
client = Sdk4me::Client.new(account: 'trusted-sandbox', source: 'my special integration')
```

### Proxy

The proxy settings are limited to basic authentication only. In case ISA-NTLM authentication is required, make sure to setup a local proxy configured to forward the requests. And example local proxy host for Windows is [Fiddle](http://www.telerik.com/fiddler).

## 4me SDK Client

Minimal example:

```
require 'sdk4me/client'

client = Sdk4me::Client.new(access_token: '3a4e4590179263839...')
response = client.get('me')
puts response[:primary_email]
```

### Retrieve a single record

The `get` method can be used to retrieve a single record from SDK4ME.

```
response = Sdk4me::Client.new.get('organizations/4321')
puts response[:name]
```

By default this call will return all [fields](https://developer.4me.com/v1/organizations/#fields) of the Organization.

The fields can be accessed using *symbols* and *strings*, and it is possible chain a number of keys in one go:
```
response = Sdk4me::Client.new.get('organizations/4321')
puts response[:parent][:name]    # this may throw an error when +parent+ is +nil+
puts response[:parent, :name]    # using this format you will retrieve +nil+ when +parent+ is +nil+
puts response['parent', 'name']  # strings are also accepted as keys
```

### Browse through a collection of records

Although the `get` method can be also used to retrieve a collection of records from SDK4ME, the preferred way is to use the `each` method.

```
count = Sdk4me::Client.new.each('organizations') do |organization|
  puts organization[:name]
end
puts "Found #{count} organizations"
```

By default this call will return all [collection fields](https://developer.4me.com/v1/organizations/#collection-fields) for each Organization.
For more fields, check out the [field selection](https://developer.4me.com/v1/general/field_selection/#collection-of-resources) documentation.

The fields can be accessed using *symbols* and *strings*, and it is possible chain a number of keys in one go:
```
count = Sdk4me::Client.new.each('organizations', fields: 'parent') do |organization|
  puts organization[:parent][:name]    # this may throw an error when +parent+ is +nil+
  puts organization[:parent, :name]    # using this format you will retrieve +nil+ when +parent+ is +nil+
  puts organization['parent', 'name']  # strings are also accepted as keys
end
```

Note that an `Sdk4me::Exception` could be thrown in case one of the API requests fails. When using the [blocking options](#blocking) the chances of this happening are rather small and you may decide not to explicitly catch the `Sdk4me::Exception` here, but leave it up to a generic exception handler.

### Retrieve a collection of records

The `each` method [described above](#browse-through-a-collection-of-records) is the preferred way to work with collections of data.

If you really want to [paginate](https://developer.4me.com/v1/general/pagination/) yourself, the `get` method is your friend.

```
@client = Sdk4me::Client.new
response = @client.get('organizations', { per_page: 100 })

puts response.json # all data in an array

puts "showing page #{response.current_page}/#{response.total_pages}, with #{response.per_page} records per page"
puts "total number of records #{response.total_entries}"

# retrieve collection for previous and next pages directly from the response
prev_page = @client.get(response.pagination_relative_link(:prev))
next_page = @client.get(response.pagination_relative_link(:next))
```

By default this call will return all [collection fields](https://developer.4me.com/v1/organizations/#collection-fields) for each Organization.
For more fields, check out the [field selection](https://developer.4me.com/v1/general/field_selection/#collection-of-resources) documentation.

The fields can be accessed using *symbols* and *strings*, and it is possible chain a number of keys in one go:
```
response = Sdk4me::Client.new.get('organizations', { per_page: 100, fields: 'parent' })
puts response[:parent, :name]    # an array with the parent organization names
puts response['parent', 'name']  # strings are also accepted as keys
```

### Create a new record

Creating new records is done using the `post` method.

```
response = Sdk4me::Client.new.post('people', {primary_email: 'new.user@example.com', organization_id: 777})
if response.valid?
  puts "New person created with id #{response[:id]}"
else
  puts response.message
end
```

Make sure to validate the success by calling `response.valid?` and to take appropriate action in case the response is not valid.


### Update an existing record

Updating records is done using the `put` method.

```
response = Sdk4me::Client.new.put('people/888', {name: 'Mrs. Susan Smith', organization_id: 777})
if response.valid?
  puts "Person with id #{response[:id]} successfully updated"
else
  puts response.message
end
```

Make sure to validate the success by calling `response.valid?` and to take appropriate action in case the response is not valid.

### Delete an existing record

Deleting records is done using the `delete` method.

```
response = Sdk4me::Client.new.delete('organizations/88/addresses/')
if response.valid?
  puts "Addresses of Organization with id #{response[:id]} successfully removed"
else
  puts response.message
end
```

Make sure to validate the success by calling `response.valid?` and to take appropriate action in case the response is not valid.


### Attachments

Adding attachments and inline images to rich text fields is a two-step process.
First upload the attachments to 4me, and then refer to the uploaded attachments
when creating or updating a 4me record.

To make this process easy, refer to the files using string filepaths or
File references:

```
response = Sdk4me::Client.new.put('requests/416621', {
  status: 'waiting_for_customer',
  note: 'Please complete the attached forms and assign the request back to us.',
  note_attachments: [
    '/tmp/forms/README.txt',
    File.open('/tmp/forms/PersonalData.xls', 'rb')
  ]
})
```

It is also possible to add inline attachments. Refer to attachments by their
array index, with the index being zero-based. Text can only refer to inline
images in its own attachments collection. For example:

```
begin
  data = {
    status: 'waiting_for_customer',
    note: 'See [note_attachments: 0] and [note_attachments: 1]',
    note_attachments: ['/tmp/info.png', '/tmp/help.png']
  }
  response = Sdk4me::Client.new.put('requests/416621', data)
  if response.valid?
    puts "Request #{response[:id]} updated and attachments added to the note"
  else
    puts "Update of request failed: #{response.message}"
  end
catch Sdk4me::UploadFailed => ex
  puts "Could not upload an attachment: #{ex.message}"
end
```

### Importing CSV files

4me also provides an [Import API](https://developer.4me.com/v1/import/). The 4me SDK Client can be used to upload files to that API.

```
response = Sdk4me::Client.new.import('\tmp\people.csv', 'people')
if response.valid?
  puts "Import queued with token #{response[:token]}"
else
  puts "Import upload failed: #{response.message}"
end

```

The second argument contains the [import type](https://developer.4me.com/v1/import/#parameters).

It is also possible to [monitor the progress](https://developer.4me.com/v1/import/#import-progress) of the import and block until the import is complete. In that case you will need to add some exception handling to your code.

```
begin
  response = Sdk4me::Client.new.import('\tmp\people.csv', 'people', true)
  puts response[:state]
  puts response[:results]
  puts response[:message]
catch Sdk4me::UploadFailed => ex
  puts "Could not upload the people import file: #{ex.message}"
catch Sdk4me::Exception => ex
  puts "Unable to monitor progress of the people import: #{ex.message}"
end
```

Note that blocking for the import to finish is required when you import multiple CSVs that are dependent on each other.


### Exporting CSV files

4me also provides an [Export API](https://developer.4me.com/v1/export/). The 4me SDK Client can be used to download (zipped) CSV files using that API.

```
response = Sdk4me::Client.new.export(['people', 'people_contact_details'], DateTime.new(2012,03,30,23,00,00))
if response.valid?
  puts "Export queued with token #{response[:token]}"
else
  puts "Export failed: #{response.message}"
end

```

The first argument contains the [export types](https://developer.4me.com/v1/export/#parameters).
The second argument is optional and limits the export to all changed records since the given time.

It is also possible to [monitor the progress](https://developer.4me.com/v1/export/#export-progress) of the export and block until the export is complete. In that case you will need to add some exception handling to your code.

```
require 'open-uri'

begin
  response = Sdk4me::Client.new.export(['people', 'people_contact_details'], nil, true)
  puts response[:state]
  # write the export file to disk
  File.open('/tmp/export.zip', 'wb') { |f| f.write(open(response[:url]).read) }
catch Sdk4me::UploadFailed => ex
  puts "Could not queue the people export: #{ex.message}"
catch Sdk4me::Exception => ex
  puts "Unable to monitor progress of the people export: #{ex.message}"
end
```

Note that blocking for the export to finish is recommended as you will get direct access to the exported file.


### Blocking

When the currently used API token hits the [4me rate limiter](https://developer.4me.com/v1/#rate-limiting) a HTTP 429 response is returned that specifies after how many seconds the rate limit will be lifted.

If that time lies within the _max_throttle_time_ the 4me SDK Client will wait and retry the action, if not, the throttled response will be returned. You can verify if a response was throttled using:
```
response = client.get('me')
puts response.throttled?
```

By setting the _block_at_rate_limit_ to `false` in the [configuration](#configuration) the 4me SDK Client will never wait when a rate limit is hit.

Note that 4me has different rate limiters. If the intention is to only wait when the short-burst (max 20 requests in 2 seconds) rate limiter is hit, you could set the _max_throttle_time_ to e.g. 5 seconds.

### Translations

When exporting translations, the _locale_ parameter is required:

```
  response = Itrp::Client.new.export('translations', nil, false, 'nl')
```

### Exception handling

The standard methods `get`, `post`, `put` and `delete` will always return a Response with an [error message](https://developer.4me.com/v1/#http-status-codes) in case something went wrong.

By calling `response.valid?` you will know if the action succeeded or not, and `response.message` provides additinal information in case the response was invalid.

```
response = Sdk4me::Client.new.get('organizations/1a2b')
puts response.valid?
puts response.message
```

The methods `each` and `import` may throw an `Sdk4me::Exception` in case something failed, see the examples above.

## Changelog

The changelog is available [here](CHANGELOG.md).

## Copyright

Copyright (c) 2020 4me, Inc. See [LICENSE](LICENSE) for further details.
