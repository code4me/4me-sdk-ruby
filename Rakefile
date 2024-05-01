require 'bundler/gem_tasks'

Bundler::GemHelper.install_tasks

require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

desc 'Run rubocop'
task :rubocop do
  sh 'rubocop --format simple'
end

desc 'Run the specs.'
task default: %i[spec rubocop]
