require 'rubygems'
require 'bundler'
require 'yaml'
require 'byebug'

begin
  Bundler.setup
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rspec/matchers'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'elastic_searchable'
require 'prefactory'

SINGLE_NODE_CLUSTER_CONFIG = {
  'number_of_replicas' => 0,
  'number_of_shards' => 1
}

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.include Prefactory
end
