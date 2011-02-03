require File.join(File.dirname(__FILE__), 'helper')

module ElasticSearch
  class Client
    def index_mapping(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      indices = args.empty? ? [(default_index || :all)] : args.flatten
      indices.collect! { |i| [:all].include?(i) ? "_#{i}" : i }
      execute(:index_mapping, indices, options)
    end
  end
  module Transport
    class HTTP
      def index_mapping(index_list, options={})
        standard_request(:get, {:index => index_list, :op => "_mapping"})
      end
    end
  end
end


class TestElasticSearchable < Test::Unit::TestCase
  ActiveRecord::Schema.define(:version => 1) do
    create_table :posts, :force => true do |t|
      t.column :title, :string
      t.column :body, :string
    end
    create_table :blogs, :force => true do |t|
      t.column :title, :string
      t.column :body, :string
    end
    create_table :users, :force => true do |t|
      t.column :name, :string
    end
    create_table :friends, :force => true do |t|
      t.column :name, :string
      t.column :favorite_color, :string
    end
  end

  class Post < ActiveRecord::Base
    elastic_searchable
    after_index :indexed
    after_index_on_create :indexed_on_create
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
  end

  context 'Post class with default elastic_searchable config' do
    setup do
      @clazz = Post
    end
    should 'respond to :search' do
      assert @clazz.respond_to?(:search)
    end
    should 'define elastic_options' do
      assert @clazz.elastic_options
    end
    should 'define index_name' do
      assert_equal 'posts', @clazz.index_name
    end
  end

  context 'Post.create_index' do
    setup do
      Post.create_index
      @status = ElasticSearchable.request :get, '/posts/_status'
    end
    should 'have created index' do
      assert @status['ok']
    end
  end

  context 'creating new instance' do
    setup do
      Post.delete_all
      @post = Post.create :title => 'foo', :body => "bar"
      Post.rebuild_index
    end
    should 'have fired after_index callback' do
      assert @post.indexed?
    end
    should 'have fired after_index_on_create callback' do
      assert @post.indexed_on_create?
    end

    context 'searching for results' do
      setup do
        @results = Post.search 'foo'
      end
      should 'find created object' do
        assert_equal @post, @results.first
      end
      should 'be paginated' do
        assert_equal 1, @results.total_entries
      end
    end

    context 'sorting search results' do
      setup do
        @second_post = Post.create :title => 'foo', :body => "second bar"
        @results = Post.search 'foo', :sort => 'id:reverse'
      end
      should 'sort results correctly' do
        assert_equal @second_post, @results.first
      end
    end
  end

  class Blog < ActiveRecord::Base
    elastic_searchable :if => proc {|b| b.should_index? }
    def should_index?
      false
    end
  end
  context 'activerecord class with :if=>proc' do
    context 'when creating new instance' do
      setup do
        Blog.any_instance.expects(:index_in_elastic_search).never
        Blog.create! :title => 'foo'
      end
      teardown do
        Blog.destroy_all
      end
      should 'not index record' do end #see expectations
    end
    context 'rebuilding new index' do
      setup do
        Blog.any_instance.expects(:index_in_elastic_search).never
        Blog.create! :title => 'foo'
        Blog.rebuild_index
      end
      should 'not index record' do end #see expectations
    end
  end

  class User < ActiveRecord::Base
    elastic_searchable :mapping => {:properties => {:name => {:type => :string, :index => :not_analyzed}}}
  end
  context 'activerecord class with :mapping=>{}' do
    context 'creating index' do
      setup do
        User.create_index
        @status = ElasticSearchable.request :get, '/users/_mapping'
      end
      should 'have set mapping' do
        expected = {
          "users"=> {
            "users"=> {
              "properties"=> {
                "name"=> {"type"=>"string", "index"=>"not_analyzed"}
              }
            }
          }
        }
        assert_equal expected, @status
      end
    end
  end

  class Friend < ActiveRecord::Base
    elastic_searchable :json => {:only => [:name]}
  end
  context 'activerecord class with :json=>{}' do
    context 'creating index' do
      setup do
        Friend.delete_all
        @friend = Friend.create! :name => 'bob', :favorite_color => 'red'
        Friend.create_index
      end
      should 'index json with configuration' do
        @response = ElasticSearchable.request :get, "/friends/friends/#{@friend.id}"
        assert_equal 'bob', @response.name
        assert_nil @response.favorite_color
      end
    end
  end
end
