require 'httparty'
require 'elastic_searchable/active_record'

module ElasticSearchable
  include HTTParty
  format :json
  base_uri 'localhost:9200'
  debug_output

  class ElasticError < StandardError; end
  class << self
    #setup the default index to use
    attr_accessor :default_index
    @@default_index = nil
    def default_index
      @@default_index || 'elastic_searchable'
    end

    #perform a request to the elasticsearch server
    def request(method, url, options = {})
      response = self.send(method, url, options)
      assert_ok_response response
      puts "elasticsearch request: #{url} finished in #{response['took'] || 'unknown'} millis"
      response
    end

    private
    def assert_ok_response(response)
      error = response['error'] || "Error executing request: #{response.inspect}"
      raise ElasticSearchable::ElasticError.new(error) if response['error'] || !response.success?
    end
  end
end

ActiveRecord::Base.send(:include, ElasticSearchable::ActiveRecord)
