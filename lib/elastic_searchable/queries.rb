module ElasticSearchable
  module Queries
    PER_PAGE_DEFAULT = 20

    def per_page
      PER_PAGE_DEFAULT
    end

    # search returns a will_paginate collection of ActiveRecord objects for the search results
    # supported options:
    # :page - page of results to search for
    # :per_page - number of results per page
    #
    # http://www.elasticsearch.com/docs/elasticsearch/rest_api/search/
    def search(query, options = {})
      page = (options.delete(:page) || 1).to_i
      options[:fields] ||= '_id'
      options[:size] ||= per_page_for_search(options)
      options[:from] ||= options[:size] * (page - 1)
      if query.is_a?(Hash)
        options[:query] = query
      else
        options[:query] = {
          :query_string => {
            :query => query,
            :default_operator => options.delete(:default_operator)
          }
        }
      end
      query = {}
      case sort = options.delete(:sort)
      when Array,Hash
        options[:sort] = sort
      when String
        query[:sort] = sort
      end

      response = ElasticSearchable.request :get, index_type_path('_search'), :query => query, :json_body => options
      hits = response['hits']
      ids = hits['hits'].collect {|h| h['_id'].to_i }
      results = self.find(ids).sort_by {|result| ids.index(result.id) }

      ElasticSearchable::Paginator.handler.new(results, page, options[:size], hits['total'])
    end

    private
    # determine the number of search results per page
    # supports will_paginate configuration by using:
    # Model.per_page
    # Model.max_per_page
    def per_page_for_search(options = {})
      per_page = options.delete(:per_page) || (self.respond_to?(:per_page) ? self.per_page : nil) || ElasticSearchable::Queries::PER_PAGE_DEFAULT
      per_page = [per_page.to_i, self.max_per_page].min if self.respond_to?(:max_per_page)
      per_page
    end
  end
end
