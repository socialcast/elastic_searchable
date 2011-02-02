module ElasticSearchable
  module ActiveRecord
    module Index
      def create_index
        self.delete_index

        Typhoeus::Request.put("http://localhost:9200/#{index_name}", :verbose => true)
        # if mapping = self.elastic_options[:mapping]
        #   ElasticSearchable.searcher.update_mapping mapping, self.index_options
        # end

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
        Typhoeus::Request.post("http://localhost:9200/#{index_name/_refresh}", :verbose => true)
      end

      # deletes the index for this model
      def delete_index
        Typhoeus::Request.delete("http://localhost:9200/#{index_name}", :verbose => true)
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
