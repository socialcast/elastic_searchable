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
      # :index (optional) configure index to store data in.  default to model table name
      # :type (optional) configue type to store data in.  default to model table name
      # :index_options (optional) configure index properties (ex: tokenizer)
      # :mapping (optional) configure field properties for this model (ex: skip analyzer for field)
      # :if (optional) reference symbol/proc condition to only index when condition is true 
      # :unless (optional) reference symbol/proc condition to skip indexing when condition is true
      # :json (optional) configure the json document to be indexed (see http://api.rubyonrails.org/classes/ActiveModel/Serializers/JSON.html#method-i-as_json for available options)
      def elastic_searchable(options = {})
        options.symbolize_keys!
        options[:index] ||= self.table_name
        options[:type] ||= self.table_name
        options[:index_options] ||= {}
        options[:mapping] ||= false
        options[:json] ||= {}
        self.elastic_options = options

        extend ElasticSearchable::ActiveRecord::Index
        extend ElasticSearchable::Queries

        include ElasticSearchable::ActiveRecord::InstanceMethods
        include ElasticSearchable::Callbacks

        add_indexing_callbacks
      end
    end

    module InstanceMethods
      def indexed_json_document
        self.as_json self.class.elastic_options[:json]
      end
      def index_in_elastic_search(lifecycle = nil)
        ElasticSearchable.request :put, "/#{self.class.index_name}/#{self.class.elastic_options[:type]}/#{self.id}", :body => self.indexed_json_document.to_json

        self.run_callbacks("after_index_on_#{lifecycle}".to_sym) if lifecycle
        self.run_callbacks(:after_index)
      end
      def should_index?
        [self.class.elastic_options[:if]].flatten.compact.all? { |m| evaluate_elastic_condition(m) } &&
        ![self.class.elastic_options[:unless]].flatten.compact.any? { |m| evaluate_elastic_condition(m) }
      end

      private
      #ripped from activesupport
      def evaluate_elastic_condition(method)
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