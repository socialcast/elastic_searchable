class Friend < ActiveRecord::Base
  belongs_to :book
  elastic_searchable :json => {:include => {:book => {:only => :title}}, :only => :name}, :index_options => SINGLE_NODE_CLUSTER_CONFIG
end
