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
        index_in_elastic_search :create
      end
      def update_index_on_update
        index_in_elastic_search :update
      end
    end
  end
end
