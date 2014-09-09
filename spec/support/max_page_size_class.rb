class MaxPageSizeClass < ActiveRecord::Base
  elastic_searchable :index_options => SINGLE_NODE_CLUSTER_CONFIG
  def self.max_per_page
    1
  end
end
