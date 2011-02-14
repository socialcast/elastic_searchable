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
require 'mocha'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'elastic_searchable'

config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config[ENV['DB'] || 'sqlite'])

class Test::Unit::TestCase
  def rebuild_index(*models)
    models.each do |model|
      begin
        model.delete_index
      rescue ElasticSearchable::ElasticError
        # no index
      end
    end

    models.each do |model|
      begin
        model.create_index
      rescue ElasticSearchable::ElasticError
        # index already exists
      end
    end

    models.each do |model|
      model.find_each do |record|
        record.index_in_elastic_search if record.should_index?
      end
      model.refresh_index
    end
  end
end
