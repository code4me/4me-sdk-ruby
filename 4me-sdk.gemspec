# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sdk4me/client/version'

Gem::Specification.new do |spec|
  spec.name                  = '4me-sdk'
  spec.version               = Sdk4me::Client::VERSION
  spec.platform              = Gem::Platform::RUBY
  spec.required_ruby_version = '>= 2.0.0'
  spec.authors               = ['4me']
  spec.email                 = %q{developers@4me.com}
  spec.description           = %q{SDK for accessing the 4me}
  spec.summary               = %q{The official 4me SDK for Ruby. Provides easy access to the APIs found at https://developer.4me.com}
  spec.homepage              = %q{https://github.com/code4me/4me-sdk-ruby}
  spec.license               = 'MIT'

  spec.files = Dir.glob('lib/**/*') + %w(
    LICENSE
    README.md
    Gemfile
    Gemfile.lock
    4me-sdk.gemspec
  )
  spec.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  spec.test_files    = `git ls-files -- {test,spec}/*`.split("\n")
  spec.require_paths = ['lib']
  spec.rdoc_options = ['--charset=UTF-8']

  spec.add_runtime_dependency 'gem_config', '>=0.3'
  spec.add_runtime_dependency 'activesupport', '>= 4.2'
  spec.add_runtime_dependency 'mime-types', '>= 3.0'

  spec.add_development_dependency 'bundler', '~> 1'
  spec.add_development_dependency 'rake', '~> 12'
  spec.add_development_dependency 'rspec', '~> 3.3'
  spec.add_development_dependency 'webmock', '~> 2'
  spec.add_development_dependency 'simplecov', '~> 0'

end
