require 'will_paginate/collection'

module ElasticSearchable
  module Queries
    # search_hits returns a raw ElasticSearch::Api::Hits object for the search results
    # see #search for the valid options
    def search_hits(query, options = {})
      if query.kind_of?(Hash)
        query = {:query => query}
      end
      ElasticSearchable.searcher.search query, elastic_search_options(options)
    end

    # search returns a will_paginate collection of ActiveRecord objects for the search results
    #
    # see ElasticSearch::Api::Index#search for the full list of valid options
    #
    # note that the collection may include nils if ElasticSearch returns a result hit for a
    # record that has been deleted on the database
    def search(query, options = {})
      hits = search_hits(query, options)
      results = WillPaginate::Collection.new(hits.current_page, hits.per_page, hits.total_entries)
      results.replace self.find(hits.collect(&:_id))
      results
    end

    # counts the number of results for this query.
    def search_count(query = "*", options = {})
      if query.kind_of?(Hash)
        query = {:query => query}
      end
      ElasticSearchable.searcher.count query, elastic_search_options(options)
    end

    def facets(fields_list, options = {})
      size = options.delete(:size) || 10
      fields_list = [fields_list] unless fields_list.kind_of?(Array)
      
      if !options[:query]
        options[:query] = {:match_all => true}
      elsif options[:query].kind_of?(String)
        options[:query] = {:query_string => {:query => options[:query]}}
      end

      options[:facets] = {}
      fields_list.each do |field|
        options[:facets][field] = {:terms => {:field => field, :size => size}}
      end

      hits = ElasticSearchable.searcher.search options, elastic_search_options
      out = {}
      
      fields_list.each do |field|
        out[field.to_sym] = {}
        hits.facets[field.to_s]["terms"].each do |term|
          out[field.to_sym][term["term"]] = term["count"]
        end
      end

      out
    end

    def elastic_search_options(options = {})
      options.merge(:index => self.index_name, :type => self.elastic_search_type)
    end
  end
end
