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
  end

  context 'requesting invalid url' do
    should 'raise error' do
      assert_raises RestClient::InternalServerError do
        ElasticSearchable.request :get, '/elastic_searchable/foobar/notfound'
      end
    end
  end

  context 'with empty index' do
    setup do
      begin
        ElasticSearchable.request :delete, '/elastic_searchable'
      rescue RestClient::ResourceNotFound
        #already deleted
      end
    end
    context 'Post.rebuild_index' do
      should 'not error out' do
        Post.rebuild_index
      end
    end
    context 'Post.create_index' do
      setup do
        Post.create_index
        @status = ElasticSearchable.request :get, '/elastic_searchable/_status'
      end
      should 'have created index' do
        assert @status['ok']
      end
    end
  end

  context 'Post.create' do
    setup do
      @post = Post.create :title => 'foo', :body => "bar"
    end
    should 'have fired after_index callback' do
      assert @post.indexed?
    end
    should 'have fired after_index_on_create callback' do
      assert @post.indexed_on_create?
    end
  end

  context 'with index containing multiple results' do
    setup do
      Post.delete_all
      @first_post = Post.create :title => 'foo', :body => "first bar"
      @second_post = Post.create :title => 'foo', :body => "second bar"
      Post.rebuild_index
      Post.refresh_index
    end

    context 'searching for results' do
      setup do
        @results = Post.search 'first'
      end
      should 'find created object' do
        assert_equal @first_post, @results.first
      end
      should 'be paginated' do
        assert_equal 1, @results.current_page
        assert_equal 20, @results.per_page
        assert_nil @results.previous_page
        assert_nil @results.next_page
      end
    end

    context 'searching for second page using will_paginate params' do
      setup do
        @results = Post.search 'foo', :page => 2, :per_page => 1, :sort => 'id'
      end
      should 'find object' do
        assert_equal @second_post, @results.first
      end
      should 'be paginated' do
        assert_equal 2, @results.current_page
        assert_equal 1, @results.per_page
        assert_equal 1, @results.previous_page
        assert_nil @results.next_page
      end
    end

    context 'sorting search results' do
      setup do
        @results = Post.search 'foo', :sort => 'id:desc'
      end
      should 'sort results correctly' do
        assert_equal @second_post, @results.first
      end
    end

    context 'destroying one object' do
      setup do
        @first_post.destroy
        Post.refresh_index
      end
      should 'be removed from the index' do
        assert_raises RestClient::ResourceNotFound do
          ElasticSearchable.request :get, "/elastic_searchable/posts/#{@first_post.id}"
        end
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
        User.update_index_mapping
        @status = ElasticSearchable.request :get, '/elastic_searchable/users/_mapping'
      end
      should 'have set mapping' do
        expected = {
          "users"=> {
            "properties"=> {
              "name"=> {"type"=>"string", "index"=>"not_analyzed"}
            }
          }
        }
        assert_equal expected, @status['elastic_searchable'], @status.inspect
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
        Friend.rebuild_index
      end
      should 'index json with configuration' do
        @response = ElasticSearchable.request :get, "/friends/friends/#{@friend.id}"
        expected = {
          "name" => 'bob' #favorite_color should not be indexed
        }
        assert_equal expected, @response['_source'], @response.inspect
      end
    end
  end

  context 'updating ElasticSearchable.default_index' do
    setup do
      ElasticSearchable.default_index = 'my_new_index'
    end
    teardown do
      ElasticSearchable.default_index = nil
    end
    should 'change default index' do
      assert_equal 'my_new_index', ElasticSearchable.default_index
    end
  end
end
