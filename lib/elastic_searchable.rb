require 'httparty'
require 'elastic_searchable/active_record'

module ElasticSearchable
  include HTTParty
  format :json
  base_uri 'localhost:9200'
  debug_output

  class ElasticError < StandardError; end
  class << self
    def assert_ok_response(response)
      error = response['error'] || "Error executing request: #{response.inspect}"
      raise ElasticSearchable::ElasticError.new(error) if response['error'] || !response.success?
    end
    def request(method, url, options = {})
      response = self.send(method, url, options)
      assert_ok_response response
      response
    end
  end
end

ActiveRecord::Base.send(:include, ElasticSearchable::ActiveRecord)
