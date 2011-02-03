require 'crack'
require 'rest_client'
require 'elastic_searchable/active_record'

module ElasticSearchable

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

    #perform a request to the elasticsearch server
    def request(method, path, params = {})
      url = ['http://', 'localhost:9200', path].join
      RestClient.log = Logger.new(STDOUT)
      response = RestClient.send method, url, params
      json = Crack::JSON.parse(response.body)
      #puts "elasticsearch request: #{method} #{url} #{" finished in #{json['took']}ms" if json['took']}"
      json
    end
  end
end

ActiveRecord::Base.send(:include, ElasticSearchable::ActiveRecord)
