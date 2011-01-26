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
  end

  class Post < ActiveRecord::Base
    elastic_searchable
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
      @status = ElasticSearchable.searcher.index_status Post.index_name
    end
    should 'have created index' do
      assert @status['ok']
    end
  end

  context 'creating new instance' do
    setup do
      Post.delete_all
      @post = Post.create :title => 'foo', :body => "bar"
      Post.create_index
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
        Blog.delete_all
        Blog.create_index
        Blog.create! :title => 'foo'
      end
      should 'not index record' do end #see expectations

      context 'recreating new index' do
        setup do
          Blog.any_instance.expects(:index_in_elastic_search).never
          Blog.create_index
        end
        should 'not index record' do end #see expectations
      end
    end
  end

  class User < ActiveRecord::Base
    elastic_searchable :mapping => {:properties => {:name => {:type => :string, :index => :not_analyzed}}}
  end
  context 'activerecord class with :mapping=>{}' do
    context 'creating index' do
      setup do
        User.create_index
        @status = ElasticSearchable.searcher.index_mapping User.index_name
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
end
