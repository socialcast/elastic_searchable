require 'will_paginate/collection'
require 'active_record'
require 'after_commit'
require 'backgrounded'
require 'elastic_searchable/queries'

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

        include ElasticSearchable::Queries
        include ElasticSearchable::ActiveRecord::InstanceMethods
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