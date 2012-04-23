require 'active_record'
require 'backgrounded'
require 'elastic_searchable/queries'
require 'elastic_searchable/callbacks'
require 'elastic_searchable/index'
require 'elastic_searchable/paginator'

module ElasticSearchable
  module ActiveRecordExtensions
    extend ActiveSupport::Concern

    included do
      define_model_callbacks :index, :percolate, :only => :after
    end

    module ClassMethods
      # Valid options:
      # :type (optional) configue type to store data in.  default to model table name
      # :mapping (optional) configure field properties for this model (ex: skip analyzer for field)
      # :if (optional) reference symbol/proc condition to only index when condition is true
      # :unless (optional) reference symbol/proc condition to skip indexing when condition is true
      # :json (optional) configure the json document to be indexed (see http://api.rubyonrails.org/classes/ActiveModel/Serializers/JSON.html#method-i-as_json for available options)
      #
      # after_percolate
      # called after object is indexed in elasticsearch
      # only fires if the update index call returns a non-empty set of registered percolations
      # use the "percolations" instance method from within callback to inspect what percolations were returned
      def elastic_searchable(options = {})
        cattr_accessor :elastic_options
        self.elastic_options = options.symbolize_keys.merge(:unless => Array.wrap(options[:unless]).push(:elasticsearch_offline?))
        attr_reader :hit
        attr_accessor :index_lifecycle

        if self.elastic_options[:index_options]
          ActiveSupport::Deprecation.warn ":index_options has been deprecated.  Use ElasticSearchable.index_settings instead.", caller
        end
        if self.elastic_options[:index]
          ActiveSupport::Deprecation.warn ":index has been deprecated.  Use ElasticSearchable.index_name instead.", caller
        end

        extend ElasticSearchable::Indexing::ClassMethods
        extend ElasticSearchable::Queries

        include ElasticSearchable::Indexing::InstanceMethods
        include ElasticSearchable::Callbacks::InstanceMethods

        include ElasticSearchable::ActiveRecordExtensions::LocalMethods

        backgrounded :update_index_on_create => ElasticSearchable::Callbacks.backgrounded_options, :update_index_on_update => ElasticSearchable::Callbacks.backgrounded_options
        class << self
          backgrounded :delete_id_from_index => ElasticSearchable::Callbacks.backgrounded_options
        end

        after_commit :update_index_on_create_backgrounded, :if => :should_index?, :on => :create
        after_commit :update_index_on_update_backgrounded, :if => :should_index?, :on => :update
        after_commit :delete_from_index, :unless => :elasticsearch_offline?, :on => :destroy
      end
    end

    module LocalMethods
      extend ActiveSupport::Concern

      module ClassMethods
        # Available callback method after indexing is complete
        # called after the object is indexed in elasticsearch
        # (optional) :on => :create/:update can be used to only fire callback when object is created or updated
        # override default after_index callback definition to support :on option
        # see ActiveRecord::Transactions::ClassMethods#after_commit for example
        def after_index(*args, &block)
          options = args.last
          if options.is_a?(Hash) && options[:on]
            options[:if] = Array.wrap(options[:if])
            options[:if] << "self.index_lifecycle == :#{options[:on]}"
          end
          set_callback(:index, :after, *args, &block)
        end
      end

      # retuns list of percolation matches found during indexing
      # usable when the model is configured with an :after_index callback
      def percolations
        @percolations || []
      end
    end
  end
end

ActiveRecord::Base.send(:include, ElasticSearchable::ActiveRecordExtensions)
