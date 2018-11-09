require "bundler/gem_tasks"

Bundler::GemHelper.install_tasks

require 'rake'
require 'rspec/core/rake_task'
#
RSpec::Core::RakeTask.new(:spec)

desc 'Run the specs.'
task :default => :spec
