require File.join(File.dirname(__FILE__), 'helper')

class TestElasticSearchable < Test::Unit::TestCase
  def setup
    delete_index
  end
  ElasticSearchable.debug_output
  SINGLE_NODE_CLUSTER_CONFIG = {'number_of_replicas' => 0, 'number_of_shards' => 1}

  context 'non elastic activerecord class' do
    class Parent < ActiveRecord::Base
    end
    setup do
      @clazz = Parent
    end
    should 'not respond to elastic_options' do
      assert !@clazz.respond_to?(:elastic_options)
    end
  end
  context 'instance of non-elastic_searchable activerecord class' do
    class Parent < ActiveRecord::Base
    end
    setup do
      @instance = Parent.new
    end
    should 'not respond to percolations' do
      assert !@instance.respond_to?(:percolations)
    end
  end

  class Post < ActiveRecord::Base
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
  context 'activerecord class with default elastic_searchable config' do
    setup do
      @clazz = Post
    end
    should 'respond to :search' do
      assert @clazz.respond_to?(:search)
    end
    should 'define elastic_options' do
      assert @clazz.elastic_options
    end
    should 'respond to :percolations' do
      assert @clazz.new.respond_to?(:percolations)
      assert_equal [], @clazz.new.percolations
    end
  end

  context 'Model.request with invalid url' do
    should 'raise error' do
      assert_raises ElasticSearchable::ElasticError do
        ElasticSearchable.request :get, '/elastic_searchable/foobar/notfound'
      end
    end
  end

  context 'Model.create_index' do
    setup do
      Post.create_index
      Post.refresh_index
      @status = ElasticSearchable.request :get, '/elastic_searchable/_status'
    end
    should 'have created index' do
      assert @status['ok']
    end
  end

  context 'Model.create' do
    setup do
      @post = Post.create :title => 'foo', :body => "bar"
    end
    should 'have fired after_index callback' do
      assert @post.indexed?
    end
    should 'have fired after_index_on_create callback' do
      assert @post.indexed_on_create?
    end
    should 'not have fired after_index_on_update callback' do
      assert !@post.indexed_on_update?
    end
  end

  context 'Model.update' do
    setup do
      Post.create! :title => 'foo'
      @post = Post.last
      @post.update_attribute :title, 'bar'
    end
    should 'have fired after_index callback' do
      assert @post.indexed?
    end
    should 'not have fired after_index_on_create callback' do
      assert !@post.indexed_on_create?
    end
    should 'have fired after_index_on_update callback' do
      assert @post.indexed_on_update?
    end
  end

  context 'Model.create within ElasticSearchable.offline block' do
    setup do
      Post.any_instance.expects(:update_index_on_create).never
      ElasticSearchable.offline do
        @post = Post.create :title => 'foo', :body => "bar"
      end
    end
    should 'not have triggered indexing behavior' do end #see expectations
    should 'not have fired after_index callback' do
      assert !@post.indexed?
    end
    should 'not have fired after_index_on_create callback' do
      assert !@post.indexed_on_create?
    end
    should 'not have fired after_index_on_update callback' do
      assert !@post.indexed_on_update?
    end
  end

  context 'with empty index when multiple database records' do
    setup do
      Post.delete_all
      Post.create_index
      @first_post = Post.create :title => 'foo', :body => "first bar"
      @second_post = Post.create :title => 'foo', :body => "second bar"
      Post.delete_index
      Post.create_index
    end
    should 'not raise error if error occurs reindexing model' do
      ElasticSearchable.expects(:request).raises(ElasticSearchable::ElasticError.new('faux error'))
      assert_nothing_raised do
        Post.reindex
      end
    end
    should 'not raise error if destroying one instance' do
      Logger.any_instance.expects(:warn)
      assert_nothing_raised do
        @first_post.destroy
      end
    end
    context 'Model.reindex' do
      setup do
        Post.reindex :per_page => 1, :scope => Post.scoped(:order => 'body desc')
        Post.refresh_index
      end
      should 'have reindexed both records' do
        assert_nothing_raised do
          ElasticSearchable.request :get, "/elastic_searchable/posts/#{@first_post.id}"
          ElasticSearchable.request :get, "/elastic_searchable/posts/#{@second_post.id}"
        end
      end
    end
  end

  context 'with index containing multiple results' do
    setup do
      Post.create_index
      @first_post = Post.create :title => 'foo', :body => "first bar"
      @second_post = Post.create :title => 'foo', :body => "second bar"
      Post.refresh_index
    end

    context 'searching for results' do
      setup do
        @results = Post.search 'first'
      end
      should 'find created object' do
        assert_contains @results, @first_post
      end
      should 'be paginated' do
        assert_equal 1, @results.current_page
        assert_equal Post.per_page, @results.per_page
        assert_nil @results.previous_page
        assert_nil @results.next_page
      end
    end

    context 'searching for second page using will_paginate params' do
      setup do
        @results = Post.search 'foo', :page => 2, :per_page => 1, :sort => 'id'
      end
      should 'not find objects from first page' do
        assert_does_not_contain @results, @first_post
      end
      should 'find second object' do
        assert_contains @results, @second_post
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
        assert_equal @first_post, @results.last
      end
    end

    context 'destroying one object' do
      setup do
        @first_post.destroy
        Post.refresh_index
      end
      should 'be removed from the index' do
        @request = ElasticSearchable.get "/elastic_searchable/posts/#{@first_post.id}"
        assert @request.response.is_a?(Net::HTTPNotFound), @request.inspect
      end
    end
  end


  class Blog < ActiveRecord::Base
    elastic_searchable :if => proc {|b| b.should_index? }, :index_options => SINGLE_NODE_CLUSTER_CONFIG
    def should_index?
      false
    end
  end
  context 'activerecord class with optional :if=>proc configuration' do
    context 'when creating new instance' do
      setup do
        Blog.any_instance.expects(:reindex).never
        @blog = Blog.create! :title => 'foo'
      end
      should 'not index record' do end #see expectations
      should 'not be found in elasticsearch' do
        @request = ElasticSearchable.get "/elastic_searchable/blogs/#{@blog.id}"
        assert @request.response.is_a?(Net::HTTPNotFound), @request.inspect
      end
    end
  end

  class User < ActiveRecord::Base
    elastic_searchable :index_options => {
      'number_of_replicas' => 0,
      'number_of_shards' => 1,
      "analysis.analyzer.default.tokenizer" => 'standard',
      "analysis.analyzer.default.filter" => ["standard", "lowercase", 'porterStem']},
    :mapping => {:properties => {:name => {:type => :string, :index => :not_analyzed}}}
  end
  context 'activerecord class with :index_options and :mapping' do
    context 'creating index' do
      setup do
        User.create_index
      end
      should 'have used custom index_options' do
        @status = ElasticSearchable.request :get, '/elastic_searchable/_status'
        expected = {
          "index.number_of_replicas" => "0",
          "index.number_of_shards" => "1",
          "index.analysis.analyzer.default.tokenizer" => "standard",
          "index.analysis.analyzer.default.filter.0" => "standard",
          "index.analysis.analyzer.default.filter.1" => "lowercase",
          "index.analysis.analyzer.default.filter.2" => "porterStem"
        }
        assert_equal expected, @status['indices']['elastic_searchable']['settings'], @status.inspect
      end
      should 'have set mapping' do
        @status = ElasticSearchable.request :get, '/elastic_searchable/users/_mapping'
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
    belongs_to :book
    elastic_searchable :json => {:include => {:book => {:only => :title}}, :only => :name}, :index_options => SINGLE_NODE_CLUSTER_CONFIG
  end
  context 'activerecord class with optional :json config' do
    context 'creating index' do
      setup do
        Friend.create_index
        @book = Book.create! :isbn => '123abc', :title => 'another world'
        @friend = Friend.new :name => 'bob', :favorite_color => 'red'
        @friend.book = @book
        @friend.save!
        Friend.refresh_index
      end
      should 'index json with configuration' do
        @response = ElasticSearchable.request :get, "/elastic_searchable/friends/#{@friend.id}"
        # should not index:
        # friend.favorite_color
        # book.isbn
        expected = {
          "name" => 'bob',
          'book' => {'title' => 'another world'}
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
      ElasticSearchable.default_index = ElasticSearchable::DEFAULT_INDEX
    end
    should 'change default index' do
      assert_equal 'my_new_index', ElasticSearchable.default_index
    end
  end

  class Book < ActiveRecord::Base
    elastic_searchable
    after_percolate :on_percolated
    def on_percolated
      @percolated = percolations
    end
    def percolated
      @percolated
    end
  end
  context 'Book class with after_percolate callback' do
    context 'with created index' do
      setup do
        Book.create_index
      end
      context "when index has configured percolation" do
        setup do
          ElasticSearchable.request :put, '/_percolator/elastic_searchable/myfilter', :body => {:query => {:query_string => {:query => 'foo' }}}.to_json
          ElasticSearchable.request :post, '/_percolator/_refresh'
        end
        context 'creating an object that does not match the percolation' do
          setup do
            Book.any_instance.expects(:on_percolated).never
            @book = Book.create! :title => 'bar'
          end
          should 'not percolate the record' do end #see expectations
        end
        context 'creating an object that matches the percolation' do
          setup do
            @book = Book.create :title => "foo"
          end
          should 'return percolated matches in the callback' do
            assert_equal ['myfilter'], @book.percolated
          end
        end
        context 'percolating a non-persisted object' do
          setup do
            @matches = Book.new(:title => 'foo').percolate
          end
          should 'return percolated matches' do
            assert_equal ['myfilter'], @matches
          end
        end
      end
    end
  end

  class MaxPageSizeClass < ActiveRecord::Base
    elastic_searchable :index_options => SINGLE_NODE_CLUSTER_CONFIG
    def self.max_per_page
      1
    end
  end
  context 'with 2 MaxPageSizeClass instances' do
    setup do
      MaxPageSizeClass.create_index
      @first = MaxPageSizeClass.create! :name => 'foo one'
      @second = MaxPageSizeClass.create! :name => 'foo two'
      MaxPageSizeClass.refresh_index
    end
    context 'MaxPageSizeClass.search with default options' do
      setup do
        @results = MaxPageSizeClass.search 'foo'
      end
      should 'have one per page' do
        assert_equal 1, @results.per_page
      end
      should 'return one instance' do
        assert_equal 1, @results.length
      end
      should 'have second page' do
        assert_equal 2, @results.total_entries
      end
    end
  end
end

