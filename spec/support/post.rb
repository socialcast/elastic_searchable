class Post < ActiveRecord::Base
  Post.class_eval do
    elastic_searchable :index_options => SINGLE_NODE_CLUSTER_CONFIG
    after_index :indexed
    after_index :indexed_on_create, :on => :create
    after_index :indexed_on_update, :on => :update
    def indexed
      @indexed = true
    end
    def indexed?
      @indexed
    end
    def indexed_on_create
      @indexed_on_create = true
    end
    def indexed_on_create?
      @indexed_on_create
    end
    def indexed_on_update
      @indexed_on_update = true
    end
    def indexed_on_update?
      @indexed_on_update
    end
  end
end
