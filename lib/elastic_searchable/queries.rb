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
      options[:size] ||= per_page_for_search(options)
      options[:fields] ||= '_id'
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
      ids = collect_hit_ids(hits)
      results = collect_result_records(ids, hits)
      ids_to_delete = []
      hits_total = hits['total'].to_i

      until results.size == ids.size
        options[:from] = options[:from] + options[:size]
        options[:size] = ids.size - results.size

        ids_to_delete += (ids - results.map(&:id))
        ids -= ids_to_delete

        response = ElasticSearchable.request :get, index_type_path('_search'), :query => query, :json_body => options
        hits = response['hits']
        new_ids = collect_hit_ids(hits)
        ids += new_ids
        results += collect_result_records(new_ids, hits)
      end

      ids_to_delete.each do |id|
        delete_id_from_index_backgrounded id
      end

      ElasticSearchable::Paginator.handler.new(results, page, size, hits_total - ids_to_delete.size)
    end

    private

    def collect_hit_ids(hits)
      hits['hits'].collect {|h| h['_id'].to_i }
    end

    def collect_result_records(ids, hits)
      self.where(:id => ids).to_a.sort_by{ |result| ids.index(result.id) }.each do |result|
        result.instance_variable_set '@hit', hits['hits'][ids.index(result.id)]
      end
    end

    # determine the number of search results per page
    # supports will_paginate configuration by using:
    # Model.per_page
    # Model.max_per_page
    def per_page_for_search(options = {})
      per_page = (options.delete(:per_page) || (self.respond_to?(:per_page) ? self.per_page : nil) || ElasticSearchable::Queries::PER_PAGE_DEFAULT).to_i
      per_page = [per_page, self.max_per_page].min if self.respond_to?(:max_per_page)
      per_page
    end
  end
end
