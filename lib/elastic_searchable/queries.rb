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
      page = (options.delete(:page) || 1).to_i
      options[:fields] ||= '_id'
      options[:q] ||= query
      options[:size] ||= (options.delete(:per_page) || 20)
      options[:from] ||= options[:size] * (page - 1)

      response = ElasticSearchable.request :get, index_type_path('_search'), :params => options
      hits = response['hits']
      ids = hits['hits'].collect {|h| h['_id'].to_i }
      results = self.find(ids).sort_by {|result| ids.index(result.id) }

      page = WillPaginate::Collection.new(page, options[:size], hits['total'])
      page.replace results
      page
    end
  end
end
