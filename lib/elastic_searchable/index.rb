module ElasticSearchable
  module ActiveRecord
    module Index
      def create_index
        self.delete_index
        ElasticSearchable.searcher.create_index(index_name, @index_options)
        self.find_each do |record|
          record.local_index_in_elastic_search
        end
        self.refresh_index
      end

      # explicitly refresh the index, making all operations performed since the last refresh
      # available for search
      #
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/refresh/
      def refresh_index
        ElasticSearchable.searcher.refresh index_name
      end

      # deletes the index for this model
      def delete_index
        begin
          ElasticSearchable.searcher.delete_index index_name
        rescue ElasticSearch::RequestError
          # it's ok, this means that the index doesn't exist
        end
      end

      #optimize the index
      def optimize_index
        ElasticSearchable.searcher.optimize index_name
      end

      #delete one record from the index
      def delete_id_from_index(id, options = {})
        ElasticSearchable.searcher.delete id.to_s, elastic_search_options(options)
      end
    end
  end
end
