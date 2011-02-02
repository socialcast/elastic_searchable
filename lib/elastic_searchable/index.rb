module ElasticSearchable
  module ActiveRecord
    module Index

      def create_index
        self.delete_index
        ElasticSearchable.assert_ok_response ElasticSearchable.put "/#{index_name}"

        self.find_each do |record|
          record.index_in_elastic_search if record.should_index?
        end
        self.refresh_index
      end
      # explicitly refresh the index, making all operations performed since the last refresh
      # available for search
      #
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/refresh/
      def refresh_index
        ElasticSearchable.assert_ok_response ElasticSearchable.post "/#{index_name}/_refresh"
      end

      # deletes the index for this model
      def delete_index
        ElasticSearchable.assert_ok_response ElasticSearchable.delete "/#{index_name}"
      end

      #delete one record from the index
      def delete_id_from_index(id)
        ElasticSearchable.searcher.delete id.to_s, index_options
      end

      def index_name
        self.elastic_options[:index]
      end
      def index_options
        self.elastic_options.slice :index, :type
      end
    end
  end
end
