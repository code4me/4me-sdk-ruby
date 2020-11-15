require 'spec_helper'
require 'tempfile'

describe Sdk4me::Attachments do
  def attachments(authentication, path)
    @client = if authentication == :api_token
                Sdk4me::Client.new(api_token: 'secret', max_retry_time: -1)
              else
                Sdk4me::Client.new(access_token: 'secret', max_retry_time: -1)
              end
    Sdk4me::Attachments.new(@client, path)
  end

  def credentials(authentication)
    if authentication == :api_token
      { basic_auth: %w[secret x] }
    else
      { headers: { 'Authorization' => 'Bearer secret' } }
    end
  end

  %i[api_token access_token].each do |authentication|
    context "#{authentication} -" do
      context 'upload_attachments! -' do
        context 'field attachments' do
          it 'should not do anything when no attachments are present' do
            a = attachments(authentication, '/requests')
            expect(@client).not_to receive(:send_file)
            a.upload_attachments!({ status: :in_progress })
          end

          it 'should not do anything when attachments is nil' do
            a = attachments(authentication, '/requests')
            expect(@client).not_to receive(:send_file)
            a.upload_attachments!({ note_attachments: nil })
          end

          it 'should not do anything when attachments is empty' do
            a = attachments(authentication, '/requests')
            expect(@client).not_to receive(:send_file)
            a.upload_attachments!({ note_attachments: [] })
            a.upload_attachments!({ note_attachments: [nil] })
          end

          it 'should raise an error if no attachment provider can be determined' do
            a = attachments(authentication, '/requests')
            expect(@client).not_to receive(:send_file)
            stub_request(:get, 'https://api.4me.com/v1/attachments/storage').with(credentials(authentication)).to_return(status: 404, body: { message: 'Not Found' }.to_json)
            expect_log('GET request to api.4me.com:443/v1/attachments/storage failed: 404: Not Found', :error)
            expect_log('Attachment upload failed: No provider found', :error)
            expect { a.upload_attachments!({ note_attachments: ['file1.png'] }) }.to raise_error(::Sdk4me::UploadFailed, 'Attachment upload failed: No provider found')
          end

          it 'should upload' do
            a = attachments(authentication, '/requests')
            resp = {
              provider: 'local',
              upload_uri: 'https://widget.example.com/attachments',
              local: {
                key: 'attachments/5/requests/000/000/777/abc/${filename}',
                x_4me_expiration: '2020-11-01T23:59:59Z',
                x_4me_signature: 'foobar'
              }
            }
            stub_request(:get, 'https://api.4me.com/v1/attachments/storage').with(credentials(authentication)).to_return(status: 200, body: resp.to_json)

            expect(a).to(receive(:upload_attachment).with('/tmp/file1.png').ordered { { key: 'attachments/5/requests/000/000/777/abc/file1.png', filesize: 1234 } })
            expect(a).to(receive(:upload_attachment).with('/tmp/file2.zip').ordered { { key: 'attachments/5/requests/000/000/777/abc/file2.zip', filesize: 9876 } })

            data = { subject: 'Foobar', note_attachments: ['/tmp/file1.png', '/tmp/file2.zip'] }
            a.upload_attachments!(data)
            expect(data).to eq({ subject: 'Foobar', note_attachments: [
                                 { filesize: 1234, key: 'attachments/5/requests/000/000/777/abc/file1.png' },
                                 { filesize: 9876, key: 'attachments/5/requests/000/000/777/abc/file2.zip' }
                               ] })
          end
        end

        context 'rich text inline attachments' do
          it 'should not do anything when no [note_attachments: <idx>] is present in the note' do
            a = attachments(authentication, '/requests')
            expect(@client).not_to receive(:send_file)
            data = { note: '[note_attachments: foo]' }
            a.upload_attachments!(data)
            expect(data).to eq({ note: '[note_attachments: foo]' })
          end

          it 'should not do anything when note attachments is empty' do
            a = attachments(authentication, '/requests')
            expect(@client).not_to receive(:send_file)
            data = { note: '[note_attachments: 0]' }
            a.upload_attachments!(data)
            expect(data).to eq({ note: '[note_attachments: 0]' })
          end

          it 'should raise an error if no attachment provider can be determined' do
            a = attachments(authentication, '/requests')
            expect(@client).not_to receive(:send_file)
            stub_request(:get, 'https://api.4me.com/v1/attachments/storage').with(credentials(authentication)).to_return(status: 404, body: { message: 'Not Found' }.to_json)
            expect_log('GET request to api.4me.com:443/v1/attachments/storage failed: 404: Not Found', :error)
            expect_log('Attachment upload failed: No provider found', :error)
            data = {
              note: '[note_attachments: 0]', note_attachments: ['/tmp/doesnotexist.log']
            }
            expect { a.upload_attachments!(data) }.to raise_error(::Sdk4me::UploadFailed, 'Attachment upload failed: No provider found')
          end

          it 'should upload' do
            a = attachments(authentication, '/requests')
            resp = {
              provider: 'local',
              upload_uri: 'https://widget.example.com/attachments',
              local: {
                key: 'attachments/5/requests/000/000/777/abc/${filename}',
                x_4me_expiration: '2020-11-01T23:59:59Z',
                x_4me_signature: 'foobar'
              }
            }
            stub_request(:get, 'https://api.4me.com/v1/attachments/storage').with(credentials(authentication)).to_return(status: 200, body: resp.to_json)

            expect(a).to(receive(:upload_attachment).with('/tmp/file1.png').ordered { { key: 'attachments/5/requests/000/000/777/abc/file1.png', filesize: 1234 } })
            expect(a).to(receive(:upload_attachment).with('/tmp/file2.jpg').ordered { { key: 'attachments/5/requests/000/000/777/abc/file2.jpg', filesize: 9876 } })

            data = {
              subject: 'Foobar',
              note: 'Foo [note_attachments: 0] Bar [note_attachments: 1]',
              note_attachments: ['/tmp/file1.png', '/tmp/file2.jpg']
            }
            a.upload_attachments!(data)

            expect(data).to eq({
                                 note: 'Foo ![](attachments/5/requests/000/000/777/abc/file1.png) Bar ![](attachments/5/requests/000/000/777/abc/file2.jpg)',
                                 note_attachments: [
                                   { filesize: 1234, inline: true, key: 'attachments/5/requests/000/000/777/abc/file1.png' },
                                   { filesize: 9876, inline: true, key: 'attachments/5/requests/000/000/777/abc/file2.jpg' }
                                 ],
                                 subject: 'Foobar'
                               })
          end
        end

        context 'field attachments and rich text inline attachments' do
          it 'should upload, and replace the data in place' do
            a = attachments(authentication, '/requests')
            resp = {
              provider: 'local',
              upload_uri: 'https://widget.example.com/attachments',
              local: {
                key: 'attachments/5/requests/000/000/777/abc/${filename}',
                x_4me_expiration: '2020-11-01T23:59:59Z',
                x_4me_signature: 'foobar'
              }
            }
            stub_request(:get, 'https://api.4me.com/v1/attachments/storage').with(credentials(authentication)).to_return(status: 200, body: resp.to_json)

            expect(a).to(receive(:upload_attachment).with('/tmp/file3.log').ordered { { key: 'attachments/5/requests/000/000/777/abc/file3.log', filesize: 5678 } })
            expect(a).to(receive(:upload_attachment).with('/tmp/file1.png').ordered { { key: 'attachments/5/requests/000/000/777/abc/file1.png', filesize: 1234 } })
            expect(a).to(receive(:upload_attachment).with('/tmp/file2.jpg').ordered { { key: 'attachments/5/requests/000/000/777/abc/file2.jpg', filesize: 9876 } })

            data = {
              subject: 'Foobar',
              note: 'Foo [note_attachments: 2] Bar [note_attachments: 1]',
              note_attachments: ['/tmp/file3.log', '/tmp/file1.png', '/tmp/file2.jpg']
            }
            a.upload_attachments!(data)

            expect(data).to eq({
                                 note: 'Foo ![](attachments/5/requests/000/000/777/abc/file2.jpg) Bar ![](attachments/5/requests/000/000/777/abc/file1.png)',
                                 note_attachments: [
                                   { filesize: 5678, key: 'attachments/5/requests/000/000/777/abc/file3.log' },
                                   { filesize: 1234, inline: true, key: 'attachments/5/requests/000/000/777/abc/file1.png' },
                                   { filesize: 9876, inline: true, key: 'attachments/5/requests/000/000/777/abc/file2.jpg' }
                                 ],
                                 subject: 'Foobar'
                               })
          end

          it 'failed uploads' do
            a = attachments(authentication, '/requests')
            resp = {
              provider: 'local',
              upload_uri: 'https://widget.example.com/attachments',
              local: {
                key: 'attachments/5/requests/000/000/777/abc/${filename}',
                x_4me_expiration: '2020-11-01T23:59:59Z',
                x_4me_signature: 'foobar'
              }
            }
            stub_request(:get, 'https://api.4me.com/v1/attachments/storage').with(credentials(authentication)).to_return(status: 200, body: resp.to_json)

            expect_log('Attachment upload failed: file does not exist: /tmp/doesnotexist.png', :error)

            data = {
              subject: 'Foobar',
              note: 'Foo [note_attachments: 2] Bar [note_attachments: 1]',
              note_attachments: ['/tmp/doesnotexist.png']
            }
            expect { a.upload_attachments!(data) }.to raise_error(::Sdk4me::UploadFailed, 'Attachment upload failed: file does not exist: /tmp/doesnotexist.png')
          end
        end
      end

      context :upload_attachment do
        before(:each) do
          resp = {
            provider: 'local',
            upload_uri: 'https://widget.example.com/attachments',
            local: {
              key: 'attachments/5/requests/000/000/777/abc/${filename}',
              x_4me_expiration: '2020-11-01T23:59:59Z',
              x_4me_signature: 'foobar'
            }
          }
          stub_request(:get, 'https://api.4me.com/v1/attachments/storage').with(credentials(authentication)).to_return(status: 200, body: resp.to_json)
        end

        it 'should raise an error when the file could not be found' do
          a = attachments(authentication, '/requests')
          expect(@client).not_to receive(:send_file)
          message = 'Attachment upload failed: file does not exist: /tmp/unknown_file'
          expect_log(message, :error)
          expect { a.send(:upload_attachment, '/tmp/unknown_file') }.to raise_error(::Sdk4me::UploadFailed, message)
        end
      end

      context :s3 do
        before(:each) do
          resp = {
            provider: 's3',
            upload_uri: 'https://example.s3-accelerate.amazonaws.com/',
            s3: {
              acl: 'private',
              key: 'attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/${filename}',
              policy: 'eydlgIH0=',
              success_action_status: 201,
              x_amz_algorithm: 'AWS4-HMAC-SHA256',
              x_amz_credential: 'AKIATRO999Z9E9D2EQ7B/20201107/us-east-1/s3/aws4_request',
              x_amz_date: '20201107T000000Z',
              x_amz_server_side_encryption: 'AES256',
              x_amz_signature: 'nbhdec4k='
            }
          }
          stub_request(:get, 'https://api.4me.com/v1/attachments/storage').with(credentials(authentication)).to_return(status: 200, body: resp.to_json)
        end

        it 'should upload a file from disk' do
          Tempfile.create('4me_attachments_spec.txt') do |file|
            file << 'foobar'
            file.flush

            a = attachments(authentication, '/requests')

            stub_request(:post, 'https://example.s3-accelerate.amazonaws.com/')
              .with(
                body: "--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"Content-Type\"\r\n\r\napplication/octet-stream\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"acl\"\r\n\r\nprivate\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"key\"\r\n\r\nattachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/${filename}\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"policy\"\r\n\r\neydlgIH0=\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"success_action_status\"\r\n\r\n201\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x_amz_algorithm\"\r\n\r\nAWS4-HMAC-SHA256\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x_amz_credential\"\r\n\r\nAKIATRO999Z9E9D2EQ7B/20201107/us-east-1/s3/aws4_request\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x_amz_date\"\r\n\r\n20201107T000000Z\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x_amz_server_side_encryption\"\r\n\r\nAES256\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x_amz_signature\"\r\n\r\nnbhdec4k=\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"file\"; filename=\"#{file.path}\"\r\nContent-Type: application/octet-stream\r\n\r\nfoobar\r\n--0123456789ABLEWASIEREISAWELBA9876543210--",
                headers: {
                  'Accept' => '*/*',
                  'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                  'Content-Type' => 'multipart/form-data; boundary=0123456789ABLEWASIEREISAWELBA9876543210',
                  'User-Agent' => "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/523.10.6 (KHTML, like Gecko) Version/3.0.4 Safari/523.10.6 4me/#{Sdk4me::Client::VERSION}"
                }
              )
              .to_return(status: 200, headers: {}, body: %(<?xml version="1.0" encoding="UTF-8"?>\n<PostResponse><Location>foo</Location><Bucket>example</Bucket><Key>attachments/5/zxxb4ot60xfd6sjg/s3test.txt</Key><ETag>"bar"</ETag></PostResponse>))

            expect(a.send(:upload_attachment, file.path)).to eq({
                                                                  key: 'attachments/5/zxxb4ot60xfd6sjg/s3test.txt',
                                                                  filesize: 6
                                                                })
          end
        end

        it 'should report an error when upload fails' do
          Tempfile.create('4me_attachments_spec.txt') do |file|
            file << 'foobar'
            file.flush

            a = attachments(authentication, '/requests')

            stub_request(:post, 'https://example.s3-accelerate.amazonaws.com/')
              .with(
                body: "--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"Content-Type\"\r\n\r\napplication/octet-stream\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"acl\"\r\n\r\nprivate\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"key\"\r\n\r\nattachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/${filename}\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"policy\"\r\n\r\neydlgIH0=\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"success_action_status\"\r\n\r\n201\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x_amz_algorithm\"\r\n\r\nAWS4-HMAC-SHA256\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x_amz_credential\"\r\n\r\nAKIATRO999Z9E9D2EQ7B/20201107/us-east-1/s3/aws4_request\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x_amz_date\"\r\n\r\n20201107T000000Z\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x_amz_server_side_encryption\"\r\n\r\nAES256\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x_amz_signature\"\r\n\r\nnbhdec4k=\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"file\"; filename=\"#{file.path}\"\r\nContent-Type: application/octet-stream\r\n\r\nfoobar\r\n--0123456789ABLEWASIEREISAWELBA9876543210--",
                headers: {
                  'Accept' => '*/*',
                  'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                  'Content-Type' => 'multipart/form-data; boundary=0123456789ABLEWASIEREISAWELBA9876543210',
                  'User-Agent' => "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/523.10.6 (KHTML, like Gecko) Version/3.0.4 Safari/523.10.6 4me/#{Sdk4me::Client::VERSION}"
                }
              )
              .to_return(status: 400, body: '<Error><Message>Foo Bar Failure</Message></Error>', headers: {})

            key = "attachments/5/reqs/000/070/451/zxxb4ot60xfd6sjg/#{File.basename(file.path)}"
            message = "Attachment upload failed: AWS S3 upload to https://example.s3-accelerate.amazonaws.com/ for #{key} failed: Foo Bar Failure"
            # expect_log(message, :error)
            expect { a.send(:upload_attachment, file.path) }.to raise_error(::Sdk4me::UploadFailed, message)
          end
        end
      end

      context '4me local' do
        before(:each) do
          resp = {
            provider: 'local',
            upload_uri: 'https://widget.example.com/attachments',
            local: {
              key: 'attachments/5/requests/000/000/777/abc/${filename}',
              x_4me_expiration: '2020-11-01T23:59:59Z',
              x_4me_signature: 'foobar'
            }
          }
          stub_request(:get, 'https://api.4me.com/v1/attachments/storage').with(credentials(authentication)).to_return(status: 200, body: resp.to_json)
        end

        it 'should upload a file from disk' do
          Tempfile.create('4me_attachments_spec.txt') do |file|
            file << 'foobar'
            file.flush

            a = attachments(authentication, '/requests')

            stub_request(:post, 'https://widget.example.com/attachments')
              .with(
                body: "--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"Content-Type\"\r\n\r\napplication/octet-stream\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"key\"\r\n\r\nattachments/5/requests/000/000/777/abc/${filename}\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x_4me_expiration\"\r\n\r\n2020-11-01T23:59:59Z\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"x_4me_signature\"\r\n\r\nfoobar\r\n--0123456789ABLEWASIEREISAWELBA9876543210\r\nContent-Disposition: form-data; name=\"file\"; filename=\"#{file.path}\"\r\nContent-Type: application/octet-stream\r\n\r\nfoobar\r\n--0123456789ABLEWASIEREISAWELBA9876543210--",
                headers: {
                  'Accept' => '*/*',
                  'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                  'Authorization' => (authentication == :api_token ? 'Basic c2VjcmV0Ong=' : 'Bearer secret'),
                  'Content-Type' => 'multipart/form-data; boundary=0123456789ABLEWASIEREISAWELBA9876543210',
                  'User-Agent' => "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/523.10.6 (KHTML, like Gecko) Version/3.0.4 Safari/523.10.6 4me/#{Sdk4me::Client::VERSION}"
                }
              )
              .to_return(status: 204, body: '', headers: {})

            expect(a.send(:upload_attachment, file.path)).to eq({
                                                                  key: "attachments/5/requests/000/000/777/abc/#{File.basename(file.path)}",
                                                                  filesize: 6
                                                                })
          end
        end
      end
    end
  end
end
