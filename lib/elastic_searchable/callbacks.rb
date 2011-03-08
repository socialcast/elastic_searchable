module ElasticSearchable
  module Callbacks
    class << self
      def backgrounded_options
        {:queue => 'elasticsearch'}
      end
    end

    module InstanceMethods
      private
      def delete_from_index
        self.class.delete_id_from_index_backgrounded self.id
      end
      def update_index_on_create
        reindex :create
      end
      def update_index_on_update
        reindex :update
      end
    end
  end
end
