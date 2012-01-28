module ElasticSearchable
  module Indexing
    module ClassMethods
      # delete all documents of this type in the index
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/delete_mapping/
      def delete_mapping
        ElasticSearchable.request :delete, index_mapping_path
      end

      # configure the index for this type
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/put_mapping/
      def create_mapping
        return unless self.elastic_options[:mapping]
        ElasticSearchable.request :put, index_mapping_path('_mapping'), :json_body => {index_type => mapping}
      end

      # delete one record from the index
      # http://www.elasticsearch.com/docs/elasticsearch/rest_api/delete/
      def delete_id_from_index(id)
        ElasticSearchable.request :delete, index_mapping_path(id)
      rescue ElasticSearchable::ElasticError => e
        ElasticSearchable.logger.warn e
      end

      # helper method to generate elasticsearch url for this object type
      def index_mapping_path(action = nil)
        ElasticSearchable.request_path [index_type, action].compact.join('/')
      end

      # reindex all records using bulk api
      # see http://www.elasticsearch.org/guide/reference/api/bulk.html
      # options:
      #   :scope - scope to use for looking up records to reindex. defaults to self (all)
      #   :page - page/batch to begin indexing at. defaults to 1
      #   :per_page - number of records to index per batch. defaults to 1000
      #
      # TODO: move this to AREL relation to remove the options scope param
      def reindex(options = {})
        self.create_mapping
        options.reverse_merge! :page => 1, :per_page => 1000
        scope = options.delete(:scope) || self
        page = options[:page]
        per_page = options[:per_page]
        records = scope.limit(per_page).offset(per_page * (page -1)).all
        while records.any? do
          ElasticSearchable.logger.debug "reindexing batch ##{page}..."
          actions = []
          records.each do |record|
            next unless record.should_index?
            begin
              doc = ElasticSearchable.encode_json(record.as_json_for_index)
              actions << ElasticSearchable.encode_json({:index => {'_index' => ElasticSearchable.index_name, '_type' => index_type, '_id' => record.id}})
              actions << doc
            rescue => e
              ElasticSearchable.logger.warn "Unable to bulk index record: #{record.inspect} [#{e.message}]"
            end
          end
          begin
            ElasticSearchable.request(:put, '/_bulk', :body => "\n#{actions.join("\n")}\n") if actions.any?
          rescue ElasticError => e
            ElasticSearchable.logger.warn "Error indexing batch ##{page}: #{e.message}"
            ElasticSearchable.logger.warn e
          end

          page += 1
          records = scope.limit(per_page).offset(per_page* (page-1)).all
        end
      end

      private
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
        query[:percolate] = "*" if _percolate_callbacks.any?
        response = ElasticSearchable.request :put, self.class.index_mapping_path(self.id), :query => query, :json_body => self.as_json_for_index

        self.index_lifecycle = lifecycle ? lifecycle.to_sym : nil
        _run_index_callbacks

        self.percolations = response['matches'] || []
        _run_percolate_callbacks if self.percolations.any?
      end
      # document to index in elasticsearch
      def as_json_for_index
        original_include_root_in_json = self.class.include_root_in_json
        self.class.include_root_in_json = false
        return self.as_json self.class.elastic_options[:json]
      ensure
        self.class.include_root_in_json = original_include_root_in_json
      end
      def should_index?
        [self.class.elastic_options[:if]].flatten.compact.all? { |m| evaluate_elastic_condition(m) } &&
        ![self.class.elastic_options[:unless]].flatten.compact.any? { |m| evaluate_elastic_condition(m) }
      end
      # percolate this object to see what registered searches match
      # can be done on transient/non-persisted objects!
      # can be done automatically when indexing using :percolate => true config option
      # http://www.elasticsearch.org/blog/2011/02/08/percolator.html
      def percolate(percolator_query = nil)
        body = {:doc => self.as_json_for_index}
        body[:query] = percolator_query if percolator_query
        response = ElasticSearchable.request :get, self.class.index_mapping_path('_percolate'), :json_body => body
        self.percolations = response['matches'] || []
        self.percolations
      end

      private
      def elasticsearch_offline?
        ElasticSearchable.offline?
      end
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
