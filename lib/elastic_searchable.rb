require 'rubberband'
require 'elastic_searchable/active_record'
require 'elastic_searchable/versioned_admin_index'
require 'elastic_searchable/hit_finder'

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
  include ElasticSearchable::HitFinder
end
ElasticSearch::Client.class_eval do
  include ElasticSearchable::VersionedAdminIndex
end
