require 'spec_helper'

describe Sdk4me::Attachments do

  before(:each) do
    @client = Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
    @attachments = Sdk4me::Attachments.new(@client)
  end

  context 'upload_attachments!' do
    context 'normal' do
      it 'should not do anything when no :attachments are present' do
        expect(@attachments.upload_attachments!('/requests', {status: :in_progress})).to be_nil
      end

      it 'should not do anything when :attachments is nil' do
        expect(@attachments.upload_attachments!('/requests', {attachments: nil})).to be_nil
      end

      it 'should not do anything when :attachments is empty' do
        expect(@attachments.upload_attachments!('/requests', {attachments: []})).to be_nil
        expect(@attachments.upload_attachments!('/requests', {attachments: [nil]})).to be_nil
      end

      it 'should show a error if no attachment may be uploaded' do
        stub_request(:get, 'https://api.4me.com/v1/sites/1?attachment_upload_token=true').with(basic_auth: ['secret', 'x']).to_return(body: {name: 'site 1'}.to_json)
        expect_log('Attachments not allowed for /sites/1', :error)
        expect(@attachments.upload_attachments!('/sites/1', {attachments: ['file1.png']})).to be_nil
      end

      it 'should raise an exception if no attachment may be uploaded' do
        stub_request(:get, 'https://api.4me.com/v1/sites/1?attachment_upload_token=true').with(basic_auth: ['secret', 'x']).to_return(body: {name: 'site 1'}.to_json)
        message = 'Attachments not allowed for /sites/1'
        expect{ @attachments.upload_attachments!('/sites/1', {attachments: ['file1.png'], attachments_exception: true}) }.to raise_error(::Sdk4me::UploadFailed, message)
      end

      it 'should add /new to the path for new records' do
        stub_request(:get, 'https://api.4me.com/v1/sites/new?attachment_upload_token=true').with(basic_auth: ['secret', 'x']).to_return(body: {missing: 'storage'}.to_json)
        expect_log('Attachments not allowed for /sites', :error)
        expect(@attachments.upload_attachments!('/sites', {attachments: ['file1.png']})).to be_nil
      end

      [ [:requests,          :note],
        [:problems,          :note],
        [:contracts,         :remarks],
        [:cis,               :remarks],
        [:flsas,             :remarks],
        [:slas,              :remarks],
        [:service_instances, :remarks],
        [:service_offerings, :summary],
        [:any_other_model,   :note]].each do |model, attribute|

        it "should replace :attachments with :#{attribute}_attachments after upload at /#{model}" do
          stub_request(:get, "https://api.4me.com/v1/#{model}/new?attachment_upload_token=true").with(basic_auth: ['secret', 'x']).to_return(body: {storage_upload: 'conf'}.to_json)
          expect(@attachments).to receive(:upload_attachment).with('conf', 'file1.png', false).ordered{ 'uploaded file1.png' }
          expect(@attachments).to receive(:upload_attachment).with('conf', 'file2.zip', false).ordered{ 'uploaded file2.zip' }
          data = {leave: 'me alone', attachments: %w(file1.png file2.zip)}
          @attachments.upload_attachments!("/#{model}", data)
          expect(data[:attachments]).to be_nil
          expect(data[:leave]).to eq('me alone')
          expect(data[:"#{attribute}_attachments"]).to eq(['uploaded file1.png', 'uploaded file2.zip'].to_json)
        end
      end

      it 'should set raise_exception flag to true when :attachments_exception is set' do
        stub_request(:get, 'https://api.4me.com/v1/requests/new?attachment_upload_token=true').with(basic_auth: ['secret', 'x']).to_return(body: {storage_upload: 'conf'}.to_json)
        expect(@attachments).to receive(:upload_attachment).with('conf', 'file1.png', true).ordered{ 'uploaded file1.png' }
        data = {leave: 'me alone', attachments: 'file1.png', attachments_exception: true}
        @attachments.upload_attachments!('/requests', data)
        expect(data[:attachments]).to be_nil
        expect(data[:attachments_exception]).to be_nil
        expect(data[:leave]).to eq('me alone')
        expect(data[:note_attachments]).to eq(['uploaded file1.png'].to_json)
      end
    end

    context 'inline' do
      it 'should not do anything when no [attachment:...] is present in the note' do
        expect(@attachments.upload_attachments!('/requests', {note: '[attachmen:/type]'})).to be_nil
      end

      it 'should not do anything when attachment is empty' do
        expect(@attachments.upload_attachments!('/requests', {note: '[attachment:]'})).to be_nil
      end

      it 'should show a error if no attachment may be uploaded' do
        stub_request(:get, 'https://api.4me.com/v1/sites/1?attachment_upload_token=true').with(basic_auth: ['secret', 'x']).to_return(body: {name: 'site 1'}.to_json)
        expect_log('Attachments not allowed for /sites/1', :error)
        expect(@attachments.upload_attachments!('/sites/1', {note: '[attachment:file1.png]'})).to be_nil
      end

      it 'should raise an exception if no attachment may be uploaded' do
        stub_request(:get, 'https://api.4me.com/v1/sites/1?attachment_upload_token=true').with(basic_auth: ['secret', 'x']).to_return(body: {name: 'site 1'}.to_json)
        message = 'Attachments not allowed for /sites/1'
        expect{ @attachments.upload_attachments!('/sites/1', {note: '[attachment:file1.png]', attachments_exception: true}) }.to raise_error(::Sdk4me::UploadFailed, message)
      end

      it 'should add /new to the path for new records' do
        stub_request(:get, 'https://api.4me.com/v1/sites/new?attachment_upload_token=true').with(basic_auth: ['secret', 'x']).to_return(body: {missing: 'storage'}.to_json)
        expect_log('Attachments not allowed for /sites', :error)
        expect(@attachments.upload_attachments!('/sites', {note: '[attachment:file1.png]'})).to be_nil
      end

      [ [:requests,          :note],
        [:problems,          :note],
        [:contracts,         :remarks],
        [:cis,               :remarks],
        [:flsas,             :remarks],
        [:slas,              :remarks],
        [:service_instances, :remarks],
        [:service_offerings, :summary],
        [:any_other_model,   :note]].each do |model, attribute|

        it "should replace :attachments with :#{attribute}_attachments after upload at /#{model}" do
          stub_request(:get, "https://api.4me.com/v1/#{model}/new?attachment_upload_token=true").with(basic_auth: ['secret', 'x']).to_return(body: {storage_upload: 'conf'}.to_json)
          expect(@attachments).to receive(:upload_attachment).with('conf', 'file1.png', false).ordered{ {key: 'uploaded file1.png'} }
          expect(@attachments).to receive(:upload_attachment).with('conf', 'file2.zip', false).ordered{ {key: 'uploaded file2.zip'} }
          data = {leave: 'me alone', attribute => '[attachment:file1.png] and [attachment:file2.zip]'}
          @attachments.upload_attachments!("/#{model}", data)
          expect(data[:attachments]).to be_nil
          expect(data[:leave]).to eq('me alone')
          expect(data[:"#{attribute}_attachments"]).to eq([{key: 'uploaded file1.png', inline: true}, {key: 'uploaded file2.zip', inline: true}].to_json)
          expect(data[:"#{attribute}"]).to eq('![](uploaded file1.png) and ![](uploaded file2.zip)')
        end
      end

      it 'should set raise_exception flag to true when :attachments_exception is set' do
        stub_request(:get, 'https://api.4me.com/v1/requests/new?attachment_upload_token=true').with(basic_auth: ['secret', 'x']).to_return(body: {storage_upload: 'conf'}.to_json)
        expect(@attachments).to receive(:upload_attachment).with('conf', 'file1.png', true).ordered{ {key: 'uploaded file1.png'} }
        data = {leave: 'me alone', note: '[attachment:file1.png]', attachments_exception: true}
        @attachments.upload_attachments!('/requests', data)
        expect(data[:attachments]).to be_nil
        expect(data[:attachments_exception]).to be_nil
        expect(data[:leave]).to eq('me alone')
        expect(data[:note_attachments]).to eq([{key: 'uploaded file1.png', inline: true}].to_json)
        expect(data[:note]).to eq('![](uploaded file1.png)')
      end
    end

  end

  context 'upload_attachment' do

    it 'should log an exception when the file could not be found' do
      expect_log('Attachment upload failed: file does not exist: unknown_file', :error)
      expect(@attachments.send(:upload_attachment, nil, 'unknown_file', false)).to be_nil
    end

    it 'should raise an exception when the file could not be found' do
      message = 'Attachment upload failed: file does not exist: unknown_file'
      expect{ @attachments.send(:upload_attachment, nil, 'unknown_file', true) }.to raise_error(::Sdk4me::UploadFailed, message)
    end

    context 'aws' do
      before(:each) do
        @aws_conf = {
            provider: 'aws',
            upload_uri: 'https://itrp.s3.amazonaws.com/',
            access_key: 'AKIA6RYQ',
            success_url: 'https://mycompany.4me.com/s3_success?sig=99e82e8a046',
            policy: 'eydlgIH0=',
            signature: 'nbhdec4k=',
            upload_path: 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/'
        }
        @key_template = 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/${filename}'
        @key = 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/upload.txt'

        @multi_part_body = "--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"Content-Type\"\r\n\r\napplication/octet-stream\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x-amz-server-side-encryption\"\r\n\r\nAES256\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"key\"\r\n\r\nattachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/${filename}\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"AWSAccessKeyId\"\r\n\r\nAKIA6RYQ\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"acl\"\r\n\r\nprivate\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"signature\"\r\n\r\nnbhdec4k=\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"success_action_status\"\r\n\r\n201\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"policy\"\r\n\r\neydlgIH0=\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"file\"; filename=\"#{@fixture_dir}/upload.txt\"\r\nContent-Type: text/plain\r\n\r\ncontent\r\n--0123456789ABLEWASIEREISAWELBA9876543210--"
        @multi_part_headers = {'Accept'=>'*/*', 'Content-Type'=>'multipart/form-data; boundary=0123456789ABLEWASIEREISAWELBA9876543210', 'User-Agent'=>'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/523.10.6 (KHTML, like Gecko) Version/3.0.4 Safari/523.10.6'}
      end

      it 'should open a file from disk' do
        expect(@attachments).to receive(:aws_upload).with(@aws_conf, @key_template, @key, kind_of(File))
        expect(@attachments.send(:upload_attachment, @aws_conf, "#{@fixture_dir}/upload.txt", false)).to eq({key: @key, filesize: 7})
      end

      it 'should sent the upload to AWS' do
        stub_request(:post, 'https://itrp.s3.amazonaws.com/').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: 'OK', status: 303, headers: {'Location' => 'https://mycompany.4me.com/s3_success?sig=99e82e8a046'})
        stub_request(:get, "https://api.4me.com/v1/s3_success?sig=99e82e8a046&key=#{@key}").with(basic_auth: ['secret', 'x']).to_return(body: {}.to_json)
        expect(@attachments.send(:upload_attachment, @aws_conf, "#{@fixture_dir}/upload.txt", false)).to eq({key: @key, filesize: 7})
      end

      it 'should report an error when AWS upload fails' do
        stub_request(:post, 'https://itrp.s3.amazonaws.com/').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: %(<?xml version="1.0" encoding="UTF-8"?>\n<Error><Code>AccessDenied</Code><Message>Invalid according to Policy</Message><RequestId>1FECC4B719E426B1</RequestId><HostId>15+14lXt+HlF</HostId></Error>), status: 303, headers: {'Location' => 'https://mycompany.4me.com/s3_success?sig=99e82e8a046'})
        expect_log("Attachment upload failed: AWS upload to https://itrp.s3.amazonaws.com/ for #{@key} failed: Invalid according to Policy", :error)
        expect(@attachments.send(:upload_attachment, @aws_conf, "#{@fixture_dir}/upload.txt", false)).to be_nil
      end

      it 'should report an error when 4me confirmation fails' do
        stub_request(:post, 'https://itrp.s3.amazonaws.com/').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: 'OK', status: 303, headers: {'Location' => 'https://mycompany.4me.com/s3_success?sig=99e82e8a046'})
        stub_request(:get, "https://api.4me.com/v1/s3_success?sig=99e82e8a046&key=#{@key}").with(basic_auth: ['secret', 'x']).to_return(body: {message: 'oops!'}.to_json)
        expect_log('GET request to api.4me.com:443/v1/s3_success?sig=99e82e8a046&key=attachments%2F5%2Freqs%2F000%2F070%2F451%2Fzxxb4ot60xfd6sjg%2Fupload%2Etxt failed: oops!', :error)
        expect_log("Attachment upload failed: 4me confirmation s3_success?sig=99e82e8a046 for #{@key} failed: oops!", :error)
        expect(@attachments.send(:upload_attachment, @aws_conf, "#{@fixture_dir}/upload.txt", false)).to be_nil
      end

      it 'should raise an exception when AWS upload fails' do
        stub_request(:post, 'https://itrp.s3.amazonaws.com/').with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: %(<?xml version="1.0" encoding="UTF-8"?>\n<Error><Code>AccessDenied</Code><Message>Invalid according to Policy</Message><RequestId>1FECC4B719E426B1</RequestId><HostId>15+14lXt+HlF</HostId></Error>), status: 303, headers: {'Location' => 'https://mycompany.4me.com/s3_success?sig=99e82e8a046'})
        message = "Attachment upload failed: AWS upload to https://itrp.s3.amazonaws.com/ for #{@key} failed: Invalid according to Policy"
        expect{ @attachments.send(:upload_attachment, @aws_conf, "#{@fixture_dir}/upload.txt", true) }.to raise_error(::Sdk4me::UploadFailed, message)
      end
    end

    context '4me' do
      before(:each) do
        @sdk4me_conf = {
            provider: 'local',
            upload_uri: 'https://api.4me.com/attachments',
            upload_path: 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/'
        }
        @key_template = 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/${filename}'
        @key = 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/upload.txt'

        @multi_part_body = "--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"Content-Type\"\r\n\r\napplication/octet-stream\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"file\"; filename=\"#{@spec_dir}/support/fixtures/upload.txt\"\r\nContent-Type: text/plain\r\n\r\ncontent\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"key\"\r\n\r\nattachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/${filename}\r\n--0123456789ABLEWASIEREISAWELBA9876543210--"
        @multi_part_headers = {'Accept'=>'*/*', 'Content-Type'=>'multipart/form-data; boundary=0123456789ABLEWASIEREISAWELBA9876543210', 'User-Agent'=>'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/523.10.6 (KHTML, like Gecko) Version/3.0.4 Safari/523.10.6'}
      end

      it 'should open a file from disk' do
        expect(@attachments).to receive(:upload_to_4me).with(@sdk4me_conf, @key_template, @key, kind_of(File))
        expect(@attachments.send(:upload_attachment, @sdk4me_conf, "#{@fixture_dir}/upload.txt", false)).to eq({key: @key, filesize: 7})
      end

      it 'should sent the upload to 4me' do
        stub_request(:post, 'https://api.4me.com/v1/attachments').with(basic_auth: ['secret', 'x']).with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {}.to_json)
        expect(@attachments.send(:upload_attachment, @sdk4me_conf, "#{@fixture_dir}/upload.txt", false)).to eq({key: @key, filesize: 7})
      end

      it 'should report an error when 4me upload fails' do
        stub_request(:post, 'https://api.4me.com/v1/attachments').with(basic_auth: ['secret', 'x']).with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {message: 'oops!'}.to_json)
        expect_log('POST request to api.4me.com:443/v1/attachments failed: oops!', :error)
        expect_log("Attachment upload failed: 4me upload to https://api.4me.com/attachments for #{@key} failed: oops!", :error)
        expect(@attachments.send(:upload_attachment, @sdk4me_conf, "#{@fixture_dir}/upload.txt", false)).to be_nil
      end

      it 'should raise an exception when 4me upload fails' do
        stub_request(:post, 'https://api.4me.com/v1/attachments').with(basic_auth: ['secret', 'x']).with(body: @multi_part_body, headers: @multi_part_headers).to_return(body: {message: 'oops!'}.to_json)
        expect_log('POST request to api.4me.com:443/v1/attachments failed: oops!', :error)
        message = "Attachment upload failed: 4me upload to https://api.4me.com/attachments for #{@key} failed: oops!"
        expect{ @attachments.send(:upload_attachment, @sdk4me_conf, "#{@fixture_dir}/upload.txt", true) }.to raise_error(::Sdk4me::UploadFailed, message)
      end
    end

  end
end
