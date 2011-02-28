require 'will_paginate/collection'

module ElasticSearchable
  module Queries
    PER_PAGE_DEFAULT = 20

    # search returns a will_paginate collection of ActiveRecord objects for the search results
    # supported options:
    # :page - page of results to search for
    # :per_page - number of results per page
    #
    # http://www.elasticsearch.com/docs/elasticsearch/rest_api/search/
    def search(query, options = {})
      page = (options.delete(:page) || 1).to_i
      options[:fields] ||= '_id'
      options[:q] ||= query
      options[:size] ||= per_page_for_search(options)
      options[:from] ||= options[:size] * (page - 1)

      response = ElasticSearchable.request :get, index_type_path('_search'), :query => options
      hits = response['hits']
      ids = hits['hits'].collect {|h| h['_id'].to_i }
      results = self.find(ids).sort_by {|result| ids.index(result.id) }

      page = WillPaginate::Collection.new(page, options[:size], hits['total'])
      page.replace results
      page
    end

    private
    # determine the number of search results per page
    # supports will_paginate configuration by using:
    # Model.per_page
    # Model.max_per_page
    def per_page_for_search(options = {})
      per_page = options.delete(:per_page) || (self.respond_to?(:per_page) ? self.per_page : nil) || ElasticSearchable::Queries::PER_PAGE_DEFAULT
      self.respond_to?(:max_per_page) ? [per_page.to_i, self.max_per_page].min : per_page
    end
  end
end
