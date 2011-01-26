module ElasticSearchable
  module ActiveRecord
    module Index
      def create_index
        self.delete_index
        ElasticSearchable.searcher.create_index index_name, self.elastic_options[:index_options]
        if mapping = self.elastic_options[:mapping]
          ElasticSearchable.searcher.update_mapping mapping, self.index_options
        end

        self.find_each do |record|
          record.run_callbacks :after_commit_on_update
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
