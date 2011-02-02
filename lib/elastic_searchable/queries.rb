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

      response = Typhoeus::Request.get("http://localhost:9200/#{index_name}/#{self.elastic_options[:type]}/_search", :params => options, :verbose => true)
      hits = JSON.parse(response.body)
      
      hits = ElasticSearchable.searcher.search query, index_options.merge(options)
      ids = hits.collect {|h| h._id.to_i }
      results = self.find(ids).sort_by {|result| ids.index(result.id) }

      page = WillPaginate::Collection.new(hits.current_page, hits.per_page, hits.total_entries)
      page.replace results
      page
    end
  end
end
