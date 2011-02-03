module ElasticSearchable
  module Callbacks
    def self.included(base)
      base.send :extend, ClassMethods
    end
    def self.backgrounded_options
      {:queue => 'elasticsearch'}
    end

    module ClassMethods
      def add_indexing_callbacks
        backgrounded :update_index_on_create => ElasticSearchable::Callbacks.backgrounded_options, :update_index_on_update => ElasticSearchable::Callbacks.backgrounded_options
        class << self
          backgrounded :delete_id_from_index => ElasticSearchable::Callbacks.backgrounded_options
        end

        define_callbacks :after_index_on_create, :after_index_on_update, :after_index
        after_commit_on_create :update_index_on_create_backgrounded, :if => :should_index?
        after_commit_on_update :update_index_on_update_backgrounded, :if => :should_index?
        after_commit_on_destroy Proc.new {|o| o.class.delete_id_from_index_backgrounded(o.id) }
      end
    end

    def update_index_on_create
      index_in_elastic_search :create
    end
    def update_index_on_update
      index_in_elastic_search :update
    end
  end
end
