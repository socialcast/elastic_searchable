module ElasticSearchable
  module Indexing
    module ClassMethods
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

    module InstanceMethods
      def indexed_json_document
        self.as_json self.class.elastic_options[:json]
      end
      def index_in_elastic_search(lifecycle = nil)
        ElasticSearchable.request :put, self.class.index_type_path(self.id), :body => self.indexed_json_document.to_json

        self.run_callbacks("after_index_on_#{lifecycle}".to_sym) if lifecycle
        self.run_callbacks(:after_index)
      end
      def should_index?
        [self.class.elastic_options[:if]].flatten.compact.all? { |m| evaluate_elastic_condition(m) } &&
        ![self.class.elastic_options[:unless]].flatten.compact.any? { |m| evaluate_elastic_condition(m) }
      end

      private
      #ripped from activesupport
      def evaluate_elastic_condition(method)
        case method
          when Symbol
            self.send method
          when String
            eval(method, self.instance_eval { binding })
          when Proc, Method
            method.call
          else
            if method.respond_to?(kind)
              method.send kind
            else
              raise ArgumentError,
                "Callbacks must be a symbol denoting the method to call, a string to be evaluated, " +
                "a block to be invoked, or an object responding to the callback method."
            end
        end
      end
    end
  end
end
