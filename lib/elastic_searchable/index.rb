module ElasticSearchable
  module ActiveRecord
    module Index

      # helper method to clean out existing index and reindex all objects
      def rebuild_index
        begin
          self.delete_index
        rescue ElasticSearchable::ElasticError
          # no index
        end
        self.create_index
        self.find_each do |record|
          record.index_in_elastic_search if record.should_index?
        end
        self.refresh_index
      end

      # delete all documents of this type in the index
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/delete_mapping/
      def clean_index
        ElasticSearchable.request :delete, index_type_path
      end

      # configure the index for this type
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/put_mapping/
      def update_index_mapping
        if mapping = self.elastic_options[:mapping]
          ElasticSearchable.request :put, index_type_path('_mapping'), :body => {index_type => mapping}.to_json
        end
      end

      # create the index
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/create_index/
      def create_index
        options = self.elastic_options[:index_options] ? self.elastic_options[:index_options].to_json : ''
        ElasticSearchable.request :put, index_path, :body => options
        self.update_index_mapping
      end

      # explicitly refresh the index, making all operations performed since the last refresh
      # available for search
      #
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/refresh/
      def refresh_index
        ElasticSearchable.request :post, index_path('_refresh')
      end

      # deletes the entire index
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/delete_index/
      def delete_index
        ElasticSearchable.request :delete, index_path
      end

      # delete one record from the index
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/delete/
      def delete_id_from_index(id)
        ElasticSearchable.request :delete, index_type_path(id)
      end

      # helper method to generate elasticsearch url for this object type
      def index_type_path(action = nil)
        index_path [index_type, action].compact.join('/')
      end

      # helper method to generate elasticsearch url for this index
      def index_path(action = nil)
        ['', index_name, action].compact.join('/')
      end

      private
      def index_name
        self.elastic_options[:index] || ElasticSearchable.default_index
      end
      def index_type
        self.elastic_options[:type] || self.table_name
      end
    end
  end
end
