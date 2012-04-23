require 'active_record'
require 'backgrounded'
require 'elastic_searchable/paginator'

module ElasticSearchable
  module ActiveRecordExtensions
    extend ActiveSupport::Concern

    included do
      define_model_callbacks :index, :percolate, :only => :after
    end

    module ClassMethods
      # Valid options:
      # :type (optional) configue type to store data in.  default to model table name
      # :mapping (optional) configure field properties for this model (ex: skip analyzer for field)
      # :if (optional) reference symbol/proc condition to only index when condition is true
      # :unless (optional) reference symbol/proc condition to skip indexing when condition is true
      # :json (optional) configure the json document to be indexed (see http://api.rubyonrails.org/classes/ActiveModel/Serializers/JSON.html#method-i-as_json for available options)
      #
      # after_percolate
      # called after object is indexed in elasticsearch
      # only fires if the update index call returns a non-empty set of registered percolations
      # use the "percolations" instance method from within callback to inspect what percolations were returned
      def elastic_searchable(options = {})
        include ElasticSearchable::ActiveRecordExtensions::LocalMethods

        cattr_accessor :elastic_options
        self.elastic_options = options.symbolize_keys.merge(:unless => Array.wrap(options[:unless]).push(:elasticsearch_offline?))
        attr_reader :hit
        attr_accessor :index_lifecycle

        if self.elastic_options[:index_options]
          ActiveSupport::Deprecation.warn ":index_options has been deprecated.  Use ElasticSearchable.index_settings instead.", caller
        end
        if self.elastic_options[:index]
          ActiveSupport::Deprecation.warn ":index has been deprecated.  Use ElasticSearchable.index_name instead.", caller
        end

        backgrounded :update_index_on_create => ElasticSearchable.backgrounded_options, :update_index_on_update => ElasticSearchable.backgrounded_options
        class << self
          backgrounded :delete_id_from_index => ElasticSearchable.backgrounded_options
        end

        after_commit :update_index_on_create_backgrounded, :if => :should_index?, :on => :create
        after_commit :update_index_on_update_backgrounded, :if => :should_index?, :on => :update
        after_commit :delete_from_index, :unless => :elasticsearch_offline?, :on => :destroy
      end
    end

    module LocalMethods
      extend ActiveSupport::Concern

      module ClassMethods
        PER_PAGE_DEFAULT = 20

        # Available callback method after indexing is complete
        # called after the object is indexed in elasticsearch
        # (optional) :on => :create/:update can be used to only fire callback when object is created or updated
        # override default after_index callback definition to support :on option
        # see ActiveRecord::Transactions::ClassMethods#after_commit for example
        def after_index(*args, &block)
          options = args.last
          if options.is_a?(Hash) && options[:on]
            options[:if] = Array.wrap(options[:if])
            options[:if] << "self.index_lifecycle == :#{options[:on]}"
          end
          set_callback(:index, :after, *args, &block)
        end

        # default number of search results for this model
        # can be overridden by implementing classes
        def per_page
          PER_PAGE_DEFAULT
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

        # search returns a will_paginate collection of ActiveRecord objects for the search results
        # supported options:
        # :page - page of results to search for
        # :per_page - number of results per page
        #
        # http://www.elasticsearch.com/docs/elasticsearch/rest_api/search/
        def search(query, options = {})
          page = (options.delete(:page) || 1).to_i
          options[:fields] ||= '_id'
          options[:size] ||= per_page_for_search(options)
          options[:from] ||= options[:size] * (page - 1)
          options[:query] ||= if query.is_a?(Hash)
            query
          else
            {}.tap do |q|
              q[:query_string] = { :query => query }
              q[:query_string][:default_operator] = options.delete(:default_operator) if options.has_key?(:default_operator)
            end
          end
          query = {}
          case sort = options.delete(:sort)
          when Array,Hash
            options[:sort] = sort
          when String
            query[:sort] = sort
          end

          response = ElasticSearchable.request :get, index_mapping_path('_search'), :query => query, :json_body => options
          hits = response['hits']
          ids = hits['hits'].collect {|h| h['_id'].to_i }
          results = self.find(ids).sort_by {|result| ids.index(result.id) }

          results.each do |result|
            result.instance_variable_set '@hit', hits['hits'][ids.index(result.id)]
          end

          ElasticSearchable::Paginator.handler.new(results, page, options[:size], hits['total'])
        end

        def index_type
          self.elastic_options[:type] || self.table_name
        end

        # helper method to generate elasticsearch url for this object type
        def index_mapping_path(action = nil)
          ElasticSearchable.request_path [index_type, action].compact.join('/')
        end

        # delete all documents of this type in the index
        # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/delete_mapping/
        def delete_mapping
          ElasticSearchable.request :delete, index_mapping_path
        end

        # configure the index for this type
        # http://www.elasticsearch.com/docs/elasticsearch/rest_api/admin/indices/put_mapping/
        def create_mapping
          return unless self.elastic_options[:mapping]
          ElasticSearchable.request :put, index_mapping_path('_mapping'), :json_body => {index_type => self.elastic_options[:mapping]}
        end

        # delete one record from the index
        # http://www.elasticsearch.com/docs/elasticsearch/rest_api/delete/
        def delete_id_from_index(id)
          ElasticSearchable.request :delete, index_mapping_path(id)
        rescue ElasticSearchable::ElasticError => e
          ElasticSearchable.logger.warn e
        end

        private
        # determine the number of search results per page
        # supports will_paginate configuration by using:
        # Model.per_page
        # Model.max_per_page
        def per_page_for_search(options = {})
          per_page = (options.delete(:per_page) || self.per_page).to_i
          per_page = [per_page, self.max_per_page].min if self.respond_to?(:max_per_page)
          per_page
        end
      end

      # retuns list of percolation matches found during indexing
      # usable when the model is configured with an :after_index callback
      def percolations
        @percolations || []
      end

      # reindex the object in elasticsearch
      # fires after_index callbacks after operation is complete
      # see http://www.elasticsearch.org/guide/reference/api/index_.html
      def reindex(lifecycle = nil)
        query = {}
        query[:percolate] = "*" if _percolate_callbacks.any?
        response = ElasticSearchable.request :put, self.class.index_mapping_path(self.id), :query => query, :json_body => self.as_json_for_index

        self.index_lifecycle = lifecycle ? lifecycle.to_sym : nil
        _run_index_callbacks

        @percolations = response['matches'] || []
        _run_percolate_callbacks if @percolations.any?
      end

      # document to index in elasticsearch
      # can be overridden by implementing class to customize the content
      def as_json_for_index
        original_include_root_in_json = self.class.include_root_in_json
        self.class.include_root_in_json = false
        return self.as_json self.class.elastic_options[:json]
      ensure
        self.class.include_root_in_json = original_include_root_in_json
      end

      # flag to tell if this instance should be indexed
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
        @percolations = response['matches'] || []
      end

      private
      def delete_from_index
        self.class.delete_id_from_index_backgrounded self.id
      end
      def update_index_on_create
        reindex :create
      end
      def update_index_on_update
        reindex :update
      end
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

ActiveRecord::Base.send(:include, ElasticSearchable::ActiveRecordExtensions)
