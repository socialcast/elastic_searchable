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

      # reindex all records using bulk api
      # options:
      #   :scope - scope the find_in_batches to only a subset of records
      #   :batch - counter to start indexing at
      #   :include - passed to find_in_batches to hydrate objects
      # see http://www.elasticsearch.org/guide/reference/api/bulk.html
      def reindex(options = {})
        self.update_index_mapping
        batch = options.delete(:batch) || 1
        options[:batch_size] ||= 1000
        options[:start] ||= (batch - 1) * options[:batch_size]
        scope = options.delete(:scope) || self
        scope.find_in_batches(options) do |records|
          ElasticSearchable.logger.info "reindexing batch ##{batch}..."
          batch += 1
          actions = []
          records.each do |record|
            next unless record.should_index?
            begin
              doc = record.as_json_for_index.to_json
              actions << {:index => {'_index' => index_name, '_type' => index_type, '_id' => record.id}}.to_json
              actions << doc
            rescue => e
              ElasticSearchable.logger.warn "Unable to bulk index record: #{record.inspect} [#{e.message}]"
            end
          end
          begin
            ElasticSearchable.request(:put, '/_bulk', :body => "\n#{actions.join("\n")}\n") if actions.any?
          rescue ElasticError => e
            ElasticSearchable.logger.warn "Error indexing batch ##{batch}: #{e.message}"
            ElasticSearchable.logger.warn e
          end
        end
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
      # reindex the object in elasticsearch
      # fires after_index callbacks after operation is complete 
      # see http://www.elasticsearch.org/guide/reference/api/index_.html
      def reindex(lifecycle = nil)
        query = {}
        query.merge! :percolate => "*" if self.class.elastic_options[:percolate]
        response = ElasticSearchable.request :put, self.class.index_type_path(self.id), :query => query, :body => self.as_json_for_index.to_json

        self.run_callbacks("after_index_on_#{lifecycle}".to_sym) if lifecycle
        self.run_callbacks(:after_index)

        if percolate_callback = self.class.elastic_options[:percolate]
          matches = response['matches']
          self.send percolate_callback, matches if matches.any?
        end
      end
      # document to index in elasticsearch
      def as_json_for_index
        self.as_json self.class.elastic_options[:json]
      end
      def should_index?
        [self.class.elastic_options[:if]].flatten.compact.all? { |m| evaluate_elastic_condition(m) } &&
        ![self.class.elastic_options[:unless]].flatten.compact.any? { |m| evaluate_elastic_condition(m) }
      end
      # percolate this object to see what registered searches match
      # can be done on transient/non-persisted objects!
      # can be done automatically when indexing using :percolate => true config option
      # http://www.elasticsearch.org/blog/2011/02/08/percolator.html
      def percolate
        response = ElasticSearchable.request :get, self.class.index_type_path('_percolate'), :body => {:doc => self.as_json_for_index}.to_json
        response['matches']
      end

      private
      # ripped from activesupport
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
