lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sdk4me/client/version'

Gem::Specification.new do |spec|
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.name                  = '4me-sdk'
  spec.version               = Sdk4me::Client::VERSION
  spec.platform              = Gem::Platform::RUBY
  spec.required_ruby_version = '>= 2.5.0'
  spec.authors               = ['4me']
  spec.email                 = 'developers@4me.com'
  spec.description           = 'SDK for accessing the 4me REST API'
  spec.summary               = 'The official 4me SDK for Ruby. Provides easy access to the REST APIs found at https://developer.4me.com'
  spec.homepage              = 'https://github.com/code4me/4me-sdk-ruby'
  spec.license               = 'MIT'

  spec.files = Dir.glob('lib/**/*') + %w[
    LICENSE
    README.md
    Gemfile
    Gemfile.lock
    4me-sdk.gemspec
  ]
  spec.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.rdoc_options = ['--charset=UTF-8']

  spec.add_runtime_dependency 'activesupport', '>= 4.2'
  spec.add_runtime_dependency 'gem_config', '>=0.3'
  spec.add_runtime_dependency 'mime-types', '>= 3.0'
end
