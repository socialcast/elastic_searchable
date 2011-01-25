require 'rubberband'
require 'elastic_searchable/active_record'

module ElasticSearchable
  class << self
    attr_accessor :searcher
    def searcher
      @searcher ||= ElasticSearch.new("localhost:9200")
    end
  end
end

ActiveRecord::Base.send(:include, ElasticSearchable::ActiveRecord)
