class Blog < ActiveRecord::Base
  elastic_searchable :if => proc {|b| b.should_index? }, :index_options => SINGLE_NODE_CLUSTER_CONFIG
  def should_index?
    false
  end
end
