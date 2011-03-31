require 'active_record'
require 'after_commit'
require 'backgrounded'
require 'elastic_searchable/queries'
require 'elastic_searchable/callbacks'
require 'elastic_searchable/index'

module ElasticSearchable
  module ActiveRecordExtensions
    attr_accessor :elastic_options

    # Valid options:
    # :index (optional) configure index to store data in.  default to ElasticSearchable.default_index
    # :type (optional) configue type to store data in.  default to model table name
    # :index_options (optional) configure index properties (ex: tokenizer)
    # :mapping (optional) configure field properties for this model (ex: skip analyzer for field)
    # :if (optional) reference symbol/proc condition to only index when condition is true 
    # :unless (optional) reference symbol/proc condition to skip indexing when condition is true
    # :json (optional) configure the json document to be indexed (see http://api.rubyonrails.org/classes/ActiveModel/Serializers/JSON.html#method-i-as_json for available options)
    def elastic_searchable(options = {})
      options.symbolize_keys!
      self.elastic_options = options

      extend ElasticSearchable::Indexing::ClassMethods
      extend ElasticSearchable::Queries

      include ElasticSearchable::Indexing::InstanceMethods
      include ElasticSearchable::Callbacks::InstanceMethods

      backgrounded :update_index_on_create => ElasticSearchable::Callbacks.backgrounded_options, :update_index_on_update => ElasticSearchable::Callbacks.backgrounded_options
      class << self
        backgrounded :delete_id_from_index => ElasticSearchable::Callbacks.backgrounded_options
      end

      define_callbacks :after_index_on_create, :after_index_on_update, :after_index
      after_commit_on_create :update_index_on_create_backgrounded, :if => :should_index?
      after_commit_on_update :update_index_on_update_backgrounded, :if => :should_index?
      after_commit_on_destroy :delete_from_index
    end
  end
end
