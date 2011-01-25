require File.join(File.dirname(__FILE__), 'helper')

class TestElasticSearchable < Test::Unit::TestCase
  ActiveRecord::Schema.define(:version => 1) do
    create_table :posts, :force => true do |t|
      t.column :title, :string
      t.column :body, :string
    end
  end

  class Post < ActiveRecord::Base
    elastic_searchable
  end

  context 'a new Post instance' do
    setup do
      @post = Post.new 
    end
    should 'respond to :search' do
      assert @post.respond_to?(:search)
    end
  end
end
