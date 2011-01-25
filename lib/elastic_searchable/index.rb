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

      #delete one record from the index
      def delete_id_from_index(id, options = {})
        options[:index] ||= self.index_name
        options[:type]  ||= elastic_search_type
        ElasticSearchable.searcher.delete(id.to_s, options)
      end

      def optimize_index
        ElasticSearchable.searcher.optimize index_name
      end
    end
  end
end
