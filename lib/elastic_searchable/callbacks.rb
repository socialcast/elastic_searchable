module ElasticSearchable
  module Callbacks
    def update_index_on_create
      local_index_in_elastic_search :lifecycle => :create
    end
    def update_index_on_update
      local_index_in_elastic_search :lifecycle => :update
    end
  end
end
