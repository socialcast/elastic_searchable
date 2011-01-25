require 'rubberband'
require 'elastic_searchable/active_record'
require 'elastic_searchable/elastic_search_extensions'

module ElasticSearchable
  class << self
    attr_accessor :searcher
    def searcher
      @searcher ||= ElasticSearch.new("localhost:9200")
    end
  end
end

ActiveRecord::Base.class_eval do
  include ElasticSearchable::ActiveRecord
end

ElasticSearch::Api::Hit.class_eval do
  include ElasticSearchable::HitExtensions
end

ElasticSearch::Client.class_eval do
  include ElasticSearchable::AdminIndexVersions
end
