module ElasticSearchable
  module ActiveRecord
    module Index

      def rebuild_index
        self.create_index
        ElasticSearchable.request :delete, "/#{index_name}/_query", :query => {:q => '*'}
        self.find_each do |record|
          record.index_in_elastic_search if record.should_index?
        end
        self.refresh_index
      end
      def create_index
        begin
          ElasticSearchable.request :put, "/#{index_name}"
        rescue ElasticSearchable::ElasticError
          #index already exists
        end
        if mapping = self.elastic_options[:mapping]
          ElasticSearchable.request :put, "/#{index_name}/#{index_type}/_mapping", :body => {index_type => mapping}.to_json
        end
      end
      # explicitly refresh the index, making all operations performed since the last refresh
      # available for search
      #
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/refresh/
      def refresh_index
        ElasticSearchable.request :post, "/#{index_name}/_refresh"
      end

      # deletes the index for this model
      def delete_index
        ElasticSearchable.request :delete, "/#{index_name}"
      end

      #delete one record from the index
      def delete_id_from_index(id)
        ElasticSearchable.request :delete, "/#{index_name}/#{index_type}/#{id}"
      end

      def index_name
        self.elastic_options[:index]
      end
      def index_type
        self.elastic_options[:type]
      end
      def index_options
        self.elastic_options.slice :index, :type
      end
    end
  end
end
