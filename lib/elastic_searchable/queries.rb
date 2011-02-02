require 'will_paginate/collection'

module ElasticSearchable
  module Queries
    # search returns a will_paginate collection of ActiveRecord objects for the search results
    #
    # see ElasticSearch::Api::Index#search for the full list of valid options
    #
    # note that the collection may include nils if ElasticSearch returns a result hit for a
    # record that has been deleted on the database
    def search(query, options = {})
      options[:fields] ||= '_id'
      options[:q] ||= query

      response = ElasticSearchable.get "/#{index_name}/#{self.elastic_options[:type]}/_search", :query => options
      hits = response['hits']
      ids = hits['hits'].collect {|h| h['_id'] }
      results = self.find(ids).sort_by {|result| ids.index(result.id) }

      page = WillPaginate::Collection.new(1, 20, hits['total'])
      page.replace results
      page
    end
  end
end
