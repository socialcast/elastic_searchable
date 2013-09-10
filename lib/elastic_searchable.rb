require 'httparty'
require 'multi_json'
require 'logger'
require 'elastic_searchable/active_record_extensions'

module ElasticSearchable
  include HTTParty
  format :json
  base_uri ENV['ELASTICSEARCH_URL'] || 'localhost:9200'

  class ElasticError < StandardError; end
  class << self
    attr_accessor :logger, :index_name, :index_settings
    @@offline = false

    # execute a block of work without reindexing objects
    def offline(&block)
      original_value = offline?
      @@offline = true
      yield
    ensure
      @@offline = original_value
    end
    def offline?
      !!@@offline
    end
    # encapsulate encoding hash into json string
    # support Yajl encoder if installed
    def encode_json(options = {})
      MultiJson.encode options
    end
    # perform a request to the elasticsearch server
    # configuration:
    # ElasticSearchable.base_uri 'host:port' controls where to send request to
    # ElasticSearchable.debug_output outputs all http traffic to console
    def request(method, url, options = {})
      options.merge! :headers => {'Content-Type' => 'application/json'}
      options.merge! :body => self.encode_json(options.delete(:json_body)) if options[:json_body]

      response = self.send(method, url, options)
      logger.debug "elasticsearch request: #{method} #{url} #{"took #{response['took']}ms" if response['took']}"
      validate_response response
      response
    end

    # options for automatic active record indexing
    def backgrounded_options
      {:queue => 'elasticsearch'}
    end

    # escape lucene special characters
    def escape_query(string)
      string.to_s.gsub(/([\(\)\[\]\{\}\?\\\"!\^\+\-\*:~])/,'\\\\\1')
    end

    # escape all lucene special characters except for ", (, and ) to allow for grouping of terms
    def allow_grouping_escape_query(string)
      open_parens = 0
      escape_quotes = false
      escape_parens = false
      string.to_s.gsub!(/([\[\]\{\}\?\\!\^\+\-\*:~])/,'\\\\\1')
      string.each_char do |char|
        case char
        when '('
          open_parens += 1
        when ')'
          open_parens -= 1
          (escape_parens = true && break) if open_parens < 0
        when '"'
          escape_quotes = !escape_quotes
        end
      end
      if escape_parens || (open_parens > 0)
        string.gsub!(/([\(\)])/,'\\\\\1')
      end
      if escape_quotes
        string.gsub!(/(\")/, '\\\\\1')
      end
      string
    end

    # create the index
    # http://www.elasticsearch.org/guide/reference/api/admin-indices-create-index.html
    def create_index
      options = {}
      options[:settings] = self.index_settings if self.index_settings
      self.request :put, self.request_path, :json_body => options
    end

    # explicitly refresh the index, making all operations performed since the last refresh
    # available for search
    #
    # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/refresh/
    def refresh_index
      self.request :post, self.request_path('_refresh')
    end

    # deletes the entire index
    # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/delete_index/
    def delete_index
      self.request :delete, self.request_path
    end

    # helper method to generate elasticsearch url for this index
    def request_path(action = nil)
      ['', index_name, action].compact.join('/')
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

# configure default logger to standard out with info log level
ElasticSearchable.logger = Logger.new STDOUT
ElasticSearchable.logger.level = Logger::INFO

# configure default index to be elastic_searchable
# one index can hold many object 'types'
ElasticSearchable.index_name = 'elastic_searchable'
