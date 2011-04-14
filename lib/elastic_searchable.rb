require 'httparty'
require 'logger'
require 'elastic_searchable/active_record_extensions'

module ElasticSearchable
  include HTTParty
  format :json
  base_uri 'localhost:9200'
  #debug_output

  class ElasticError < StandardError; end
  class << self
    # setup the default index to use
    # one index can hold many object 'types'
    @@default_index = nil
    def default_index=(index)
      @@default_index = index
    end
    def default_index
      @@default_index || 'elastic_searchable'
    end

    @@logger = Logger.new(STDOUT)
    @@logger.level = Logger::INFO
    def logger=(logger)
      @@logger = logger
    end
    def logger
      @@logger
    end

    # execute a block of work without reindexing objects
    @@offline = false
    def offline?
      @@offline
    end
    def offline(&block)
      @@offline = true
      yield
    ensure
      @@offline = false
    end
    # perform a request to the elasticsearch server
    # configuration:
    # ElasticSearchable.base_uri 'host:port' controls where to send request to
    # ElasticSearchable.debug_output outputs all http traffic to console
    def request(method, url, options = {})
      response = self.send(method, url, options)
      logger.debug "elasticsearch request: #{method} #{url} #{"took #{response['took']}ms" if response['took']}"
      validate_response response
      response
    end

    private
    # all elasticsearch rest calls return a json response when an error occurs.  ex:
    # {error: 'an error occurred' }
    def validate_response(response)
      error = response['error'] || "Error executing request: #{response.inspect}"
      raise ElasticSearchable::ElasticError.new(error) if response['error'] || ![Net::HTTPOK, Net::HTTPCreated].include?(response.response.class)
    end
  end
end

