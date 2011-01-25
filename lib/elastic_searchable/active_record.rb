require 'will_paginate/collection'
require 'active_record'
require 'after_commit'
require 'backgrounded'

module ElasticSearchable
  module ActiveRecord
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      attr_accessor :index_name
      attr_accessor :elastic_search_type

      # Valid options:
      # :index_name (will default class name using method "underscore")
      def elastic_searchable(options = {})
        options.symbolize_keys!
        
        @index_name = options[:index_name] || self.name.underscore.gsub(/\//,'-')
        @elastic_search_type = options[:elastic_search_type] || self.name.underscore.singularize.gsub(/\//,'-')

        backgrounded :update_index_on_create => {:queue => 'searchindex'}, :update_index_on_update => {:queue => 'searchindex'}
        class << self
          backgrounded :delete_id_from_index => {:queue => 'searchindex'}
        end

        define_callbacks :after_index_on_create, :after_index_on_update, :after_index
        after_commit_on_create :update_index_on_create_backgrounded
        after_commit_on_update :update_index_on_update_backgrounded
        after_commit_on_destroy Proc.new {|o| o.class.delete_id_from_index_backgrounded(o.id) }

        @index_options = options[:index_options] || {}
        @mapping = options[:mapping] || false

        include ElasticSearchable::ActiveRecord::InstanceMethods
      end

      # search_hits returns a raw ElasticSearch::Api::Hits object for the search results
      # see #search for the valid options
      def search_hits(query, options = {})
        if query.kind_of?(Hash)
          query = {:query => query}
        end
        ElasticSearchable.searcher.search(query, options.merge({:index => self.index_name, :type => elastic_search_type}))
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
        results.replace hits.collect(&:to_activerecord)
        results
      end

      # counts the number of results for this query.
      def search_count(query = "*", options = {})
        if query.kind_of?(Hash)
          query = {:query => query}
        end
        ElasticSearchable.searcher.count(query, options.merge({:index => self.index_name, :type => elastic_search_type}))
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

        hits = ElasticSearchable.searcher.search(options, {:index => self.index_name, :type => elastic_search_type})
        out = {}
        
        fields_list.each do |field|
          out[field.to_sym] = {}
          hits.facets[field.to_s]["terms"].each do |term|
            out[field.to_sym][term["term"]] = term["count"]
          end
        end

        out
      end

      def create_index
        index_version = self.create_index_version

        self.find_in_batches do |batch|
          batch.each do |record|
            record.local_index_in_elastic_search(:index => index_version)
          end
        end

        ElasticSearchable.searcher.deploy_index_version(self.index_name, index_version)
      end
    
      # explicitly refresh the index, making all operations performed since the last refresh
      # available for search
      #
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/refresh/
      def refresh_index(index_version = nil)
        ElasticSearchable.searcher.refresh(index_version || index_name)
      end
      
      # creates a new index version for this model and sets the mapping options for the type
      def create_index_version
        index_version = ElasticSearchable.searcher.create_index_version(@index_name, @index_options)
        if @mapping
          ElasticSearchable.searcher.update_mapping(@mapping, :index => index_version, :type => elastic_search_type)
        end
        index_version
      end

      # deletes all index versions for this model
      def delete_index
        # deletes any index version
        ElasticSearchable.searcher.index_versions(index_name).each{|index_version|
          ElasticSearchable.searcher.delete_index(index_version)
        }
        
        # and delete the index itself if it exists
        begin
          ElasticSearchable.searcher.delete_index(index_name)
        rescue ElasticSearch::RequestError
          # it's ok, this means that the index doesn't exist
        end
      end
      
      def delete_id_from_index(id, options = {})
        options[:index] ||= self.index_name
        options[:type]  ||= elastic_search_type
        ElasticSearchable.searcher.delete(id.to_s, options)
      end
      
      def optimize_index
        ElasticSearchable.searcher.optimize(index_name)
      end
    end

    module InstanceMethods
      # default implementation of document to index
      # implementations can override this method to index custom document
      def indexed_json_document
        self.to_json
      end
      def update_index_on_create
        local_index_in_elastic_search :lifecycle => :create
      end
      def update_index_on_update
        local_index_in_elastic_search :lifecycle => :update
      end
      def local_index_in_elastic_search(options = {})
        options[:index] ||= self.class.index_name
        options[:type]  ||= self.class.elastic_search_type
        options[:id]    ||= self.id.to_s
        document = self.indexed_json_document
        ElasticSearchable.searcher.index document, options

        self.run_callbacks("after_index_on_#{options[:lifecycle]}".to_sym) if options[:lifecycle]
        self.run_callbacks(:after_index)
      end
    end
  end
end