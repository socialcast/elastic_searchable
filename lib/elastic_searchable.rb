require 'httparty'
require 'elastic_searchable/active_record'

module ElasticSearchable
  include HTTParty
  format :json
  base_uri 'localhost:9200'
  debug_output

  class << self
    def backgrounded_options
      {:queue => 'elasticsearch'}
    end

    def assert_ok_response(response)
      raise (response['error'] || "Error executing request")  unless response['ok']
    end
  end
end

ActiveRecord::Base.send(:include, ElasticSearchable::ActiveRecord)
