require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'test/unit'
require 'shoulda'
require 'mocha/setup'
require 'pry'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'elastic_searchable'
require 'setup_database'

class DeprecationLogger < Logger
  def format_message(severity, timestamp, progname, msg)
    "#{severity} #{msg}\n"
  end
end

DEPRECATION_LOGGER = DeprecationLogger.new(File.join(File.dirname(__FILE__), "/deprecations.log"))
ActiveSupport::Deprecation.debug = false
ActiveSupport::Deprecation::DEFAULT_BEHAVIORS[:deprecation_log] = lambda { |message, callstack|
  DEPRECATION_LOGGER.warn(message)
#  DEPRECATION_LOGGER.warn(message + "\n\t" + callstack.join("\n\t"))
}
ActiveSupport::Deprecation.behavior = :deprecation_log

class Test::Unit::TestCase
  def delete_index
    ElasticSearchable.delete '/elastic_searchable' rescue nil
  end
end
