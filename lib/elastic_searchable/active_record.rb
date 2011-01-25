require 'active_record'
require 'after_commit'
require 'backgrounded'
require 'elastic_searchable/queries'
require 'elastic_searchable/callbacks'
require 'elastic_searchable/index'

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

        @index_options = options[:index_options] || {}
        @mapping = options[:mapping] || false

        extend ElasticSearchable::ActiveRecord::Index
        extend ElasticSearchable::Queries

        include ElasticSearchable::ActiveRecord::InstanceMethods
        include ElasticSearchable::Callbacks

        add_indexing_callbacks
      end
    end

    module InstanceMethods
      # build json document to index in elasticsearch
      # default implementation simply calls to_json
      # implementations can override this method to index custom content
      def indexed_json_document
        self.to_json
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