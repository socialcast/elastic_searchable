require 'will_paginate/collection'

module ElasticSearchable
  module Queries
    # search returns a will_paginate collection of ActiveRecord objects for the search results
    # options:
    # :per_page/:limit
    # :page/:offset
    #
    # http://www.elasticsearch.com/docs/elasticsearch/rest_api/search/
    def search(query, options = {})
      options[:fields] ||= '_id'
      options[:q] ||= query
      options[:size] ||= (options[:per_page] || options[:limit] || 10)
      options[:from] ||= options[:size] * (options[:page].to_i-1) if options[:page] && options[:page].to_i > 1
      options[:from] ||= options[:offset] if options[:offset]

      response = ElasticSearchable.request :get, index_type_path('_search'), :query => options
      hits = response['hits']
      ids = hits['hits'].collect {|h| h['_id'].to_i }
      results = self.find(ids).sort_by {|result| ids.index(result.id) }

      page = WillPaginate::Collection.new(1, 20, hits['total'])
      page.replace results
      page
    end
  end
end
