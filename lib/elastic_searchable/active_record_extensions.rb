require 'active_record'
require 'backgrounded'
require 'elastic_searchable/queries'
require 'elastic_searchable/callbacks'
require 'elastic_searchable/index'
require 'elastic_searchable/paginator'

module ElasticSearchable
  module ActiveRecordExtensions
    # Valid options:
    # :index (optional) configure index to store data in.  default to ElasticSearchable.default_index
    # :type (optional) configue type to store data in.  default to model table name
    # :index_options (optional) configure index properties (ex: tokenizer)
    # :index_model_timeout (optional) configure timeout in seconds to wait for elasticsearch to respond when indexing a model (defaults to Net::HTTP default of 60 seconds)
    # :mapping (optional) configure field properties for this model (ex: skip analyzer for field)
    # :if (optional) reference symbol/proc condition to only index when condition is true
    # :unless (optional) reference symbol/proc condition to skip indexing when condition is true
    # :json (optional) configure the json document to be indexed (see http://api.rubyonrails.org/classes/ActiveModel/Serializers/JSON.html#method-i-as_json for available options)
    #
    # Available callbacks:
    # after_index
    # called after the object is indexed in elasticsearch
    # (optional) :on => :create/:update can be used to only fire callback when object is created or updated
    #
    # after_percolate
    # called after object is indexed in elasticsearch
    # only fires if the update index call returns a non-empty set of registered percolations
    # use the "percolations" instance method from within callback to inspect what percolations were returned
    def elastic_searchable(options = {})
      cattr_accessor :elastic_options
      self.elastic_options = options.symbolize_keys.merge(:unless => Array.wrap(options[:unless]).push(:elasticsearch_offline?))

      extend ElasticSearchable::Indexing::ClassMethods
      extend ElasticSearchable::Queries

      include ElasticSearchable::Indexing::InstanceMethods
      include ElasticSearchable::Callbacks::InstanceMethods

      backgrounded :update_index_on_create => ElasticSearchable::Callbacks.backgrounded_options, :update_index_on_update => ElasticSearchable::Callbacks.backgrounded_options
      class << self
        backgrounded :delete_id_from_index => ElasticSearchable::Callbacks.backgrounded_options
      end

      attr_reader :hit # the hit json for this result
      attr_accessor :index_lifecycle, :percolations
      define_model_callbacks :index, :percolate, :only => :after
      after_commit :update_index_on_create_backgrounded, :if => :should_index?, :on => :create
      after_commit :update_index_on_update_backgrounded, :if => :should_index?, :on => :update
      after_commit :delete_from_index, :unless => :elasticsearch_offline?, :on => :destroy

      class_eval do
        # retuns list of percolation matches found during indexing
        def percolations
          @percolations || []
        end

        class << self
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
      end
    end
  end
end

ActiveRecord::Base.send(:extend, ElasticSearchable::ActiveRecordExtensions)
