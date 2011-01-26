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
      attr_accessor :elastic_options

      # Valid options:
      # :index_name (will default class name using method "underscore")
      # :if
      # :unless
      def elastic_searchable(options = {})
        options.symbolize_keys!
        options[:index] ||= self.table_name
        options[:type] ||= self.table_name
        options[:index_options] ||= {}
        options[:mapping] ||= false
        self.elastic_options = options

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
      def index_in_elastic_search(lifecycle = nil)
        document = self.indexed_json_document
        ElasticSearchable.searcher.index document, self.class.index_options.merge(:id => self.id.to_s)

        self.run_callbacks("after_index_on_#{lifecycle}".to_sym) if lifecycle
        self.run_callbacks(:after_index)
      end
      def should_index?
        [self.class.elastic_options[:if]].flatten.compact.all? { |m| evaluate_condition(m) } &&
        ![self.class.elastic_options[:unless]].flatten.compact.any? { |m| evaluate_condition(m) }
      end

      private
      #ripped from activesupport
      def evaluate_condition(method)
        case method
          when Symbol
            self.send method
          when String
            eval(method, self.instance_eval { binding })
          when Proc, Method
            method.call
          else
            if method.respond_to?(kind)
              method.send kind
            else
              raise ArgumentError,
                "Callbacks must be a symbol denoting the method to call, a string to be evaluated, " +
                "a block to be invoked, or an object responding to the callback method."
            end
        end
      end
    end
  end
end