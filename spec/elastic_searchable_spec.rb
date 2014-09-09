require 'spec_helper'

describe ElasticSearchable do
  before do
    begin
      ElasticSearchable.delete '/elastic_searchable'
    rescue
    end
  end

  describe 'an ActiveRecord class that has not invoked elastic_searchable' do
    before do
      stub_const('Parent', Class.new(ActiveRecord::Base))
    end
    let(:clazz) { Parent }
    let(:instance) { clazz.new }
    it do
      expect(clazz).to_not respond_to :elastic_options
      expect(instance).to_not respond_to :percolations
    end
  end

  describe 'with an ActiveRecord class with elastic_searchable config' do
    let(:clazz) { Post }
    let(:instance) { Post.new }
    it do
      expect(clazz).to respond_to :search
      expect(clazz).to respond_to :elastic_options
      expect(clazz.elastic_options[:unless]).to include :elasticsearch_offline?
      expect(instance).to respond_to :percolations
      expect(instance.percolations).to eq []
    end

    describe '.request' do
      subject(:sending_request) { ElasticSearchable.request method, url }
      context 'GET' do
        let(:method) { :get }
        context 'with invalid url' do
          let(:url) { '/elastic_searchable/foobar/notfound' }
          it { expect { sending_request }.to raise_error ElasticSearchable::ElasticError }
        end
      end
    end

    describe '.create_index' do
      let(:index_status) { ElasticSearchable.request :get, '/elastic_searchable/_status' }
      context 'when it has not been called' do
        it { expect { index_status }.to raise_error }
      end
      context 'when it has been called' do
        before do
          Post.create_index
          Post.refresh_index
        end
        it { expect { index_status }.not_to raise_error }
      end
    end

    describe 'create callbacks' do
      let!(:post) { Post.create :title => 'foo', :body => "bar" }
      it 'fires index callbacks' do
        expect(post).to be_indexed
        expect(post).to be_indexed_on_create
        expect(post).not_to be_indexed_on_update
      end
    end

    describe 'update callbacks' do
      before do
        Post.create :title => 'foo', :body => 'bar'
      end
      let(:post) do
        Post.last.tap do |post|
          post.title = 'baz'
          post.save
        end
      end
      it do
        expect(post).to be_indexed
        expect(post).not_to be_indexed_on_create
        expect(post).to be_indexed_on_update
      end
    end

    describe 'ElasticSearchable.offline' do
      let!(:post) do
        ElasticSearchable.offline do
          Post.create :title => 'foo', :body => "bar"
        end
      end
      it do
        expect(post).not_to be_indexed
        expect(post).not_to be_indexed_on_create
        expect(post).not_to be_indexed_on_update
      end
    end

    context 'with an empty index and multiple database records' do
      before do
        Post.delete_all
        Post.create_index
        Post.create :title => 'foo', :body => "first bar"
        Post.create :title => 'foo', :body => "second bar"
        Post.delete_index
        Post.create_index
        Post.refresh_index
      end
      let!(:first_post) { Post.where(:body => "first bar").first }
      let!(:second_post) { Post.where(:body => "second bar").first }
      it 'does not raise error if an error occurs when reindexing model' do
        expect_any_instance_of(Logger).to receive(:warn).at_least(:once)
        expect(ElasticSearchable).to receive(:request).and_raise(ElasticSearchable::ElasticError.new('faux error'))
        expect { Post.reindex }.not_to raise_error
      end
      it 'does not raise error when destroying one instance' do
        expect_any_instance_of(Logger).to receive(:warn).at_least(:once)
        expect { first_post.destroy }.not_to raise_error
      end
      describe ".reindex" do
        before do
          Post.reindex :per_page => 1, :scope => Post.order('body desc')
          Post.refresh_index
        end
        it do
          expect { ElasticSearchable.request :get, "/elastic_searchable/posts/#{first_post.id}" }.to_not raise_error
          expect { ElasticSearchable.request :get, "/elastic_searchable/posts/#{second_post.id}" }.to_not raise_error
        end
      end
    end

    context 'with the index containing multiple results' do
      before do
        Post.create_index
        Post.create :title => 'foo', :body => "first bar"
        Post.create :title => 'foo', :body => "second bar"
        Post.refresh_index
      end
      let!(:first_post) { Post.where(:body => "first bar").first }
      let!(:second_post) { Post.where(:body => "second bar").first }

      context 'searching on a term that returns one result' do
        subject(:results) { Post.search 'first' }
        it do
          is_expected.to include first_post
          expect(results.current_page).to eq 1
          expect(results.per_page).to eq Post.per_page
          expect(results.previous_page).to be_nil
          expect(results.next_page).to be_nil
          expect(results.first.hit['_id']).to eq first_post.id.to_s
        end
      end
      context 'searching on a term that returns multiple results' do
        subject(:results) { Post.search 'foo' }
        it do
          is_expected.to include first_post
          is_expected.to include second_post
          expect(results.current_page).to eq 1
          expect(results.per_page).to eq Post.per_page
          expect(results.previous_page).to be_nil
          expect(results.next_page).to be_nil
          expect(results.first.hit['_id']).to eq first_post.id.to_s
          expect(results.last.hit['_id']).to eq second_post.id.to_s
        end
      end
      context 'searching for results using a query Hash' do
        subject(:results) do
          Post.search({
            :filtered => {
              :query => {
                :term => {:title => 'foo'},
              },
              :filter => {
                :or => [
                  {:term => {:body => 'second'}},
                  {:term => {:body => 'third'}}
                ]
              }
            }
          })
        end
        it do
          is_expected.to_not include first_post
          is_expected.to include second_post
        end
      end

      context 'when per_page is a string' do
        subject(:results) { Post.search 'foo', :per_page => 1.to_s, :sort => 'id' }
        it { expect(results).to include first_post }
      end

      context 'searching for second page using will_paginate params' do
        subject(:results) { Post.search 'foo', :page => 2, :per_page => 1, :sort => 'id' }
        it do
          expect(results).not_to include first_post
          expect(results).to include second_post
          expect(results.current_page).to eq 2
          expect(results.per_page).to eq 1
          expect(results.previous_page).to eq 1
          expect(results.next_page).to be_nil
        end
      end

      context 'sorting search results' do
        subject(:results) { Post.search 'foo', :sort => 'id:desc' }
        it 'sorts results correctly' do
          expect(results).to eq [second_post, first_post]
        end
      end

      context 'advanced sort options' do
        subject(:results) { Post.search 'foo', :sort => [{:id => 'desc'}] }
        it 'sorts results correctly' do
          expect(results).to eq [second_post, first_post]
        end
      end

      context 'destroying one object' do
        before do
          first_post.destroy
          Post.refresh_index
        end
        it 'is removed from the index' do
          expect(ElasticSearchable.get("/elastic_searchable/posts/#{first_post.id}").response).to be_a Net::HTTPNotFound
        end
      end
    end

    context 'deleting a record without updating the index' do

      context 'backfilling partial result pages' do
        let!(:posts) do
          posts = (1..8).map do |i|
            Post.create :title => 'foo', :body => "#{i} bar"
          end
          Post.refresh_index
          posts
        end
        subject(:results) { Post.search 'foo', :size => 4, :sort => 'id:desc' }
        it 'backfills the first page with results from other pages' do
          removed_posts = []
          posts.each_with_index do |post, i|
            if i % 2 == 1
              removed_posts << post
              expect(Post).to receive(:delete_id_from_index_backgrounded).with(post.id)
              post.delete
            end
          end
          expect(results).to match_array(posts - removed_posts)
          expect(results.total_entries).to eq 4
        end
      end
    end
  end

  context 'activerecord class with optional :if=>proc configuration' do
    context 'when creating new instance' do
      it do
        expect_any_instance_of(Blog).to_not receive(:reindex)
        blog = Blog.create! :title => 'foo'
        expect(ElasticSearchable.get("/elastic_searchable/blogs/#{blog.id}").response).to be_a Net::HTTPNotFound
      end
    end
  end

  context 'activerecord class with :index_options and :mapping' do
    context 'creating index' do
      before do
        User.create_index
      end
      it 'uses custom index_options' do
        settings = ElasticSearchable.request(:get, '/elastic_searchable/_settings')['elastic_searchable']['settings']['index']
        settings.delete('version')
        settings.delete('uuid')
        expect(settings).to eq(
          "analysis" => {
            "analyzer" => {
              "default"=> {
                "filter" => [ "standard", "lowercase", "porterStem"],
                "tokenizer" => "standard"
              }
            }
          },
          "number_of_shards"=>"1",
          "number_of_replicas"=>"0"
        )
      end
      it 'has set mapping' do
        status = ElasticSearchable.request :get, '/elastic_searchable/users/_mapping'
        expect(status['elastic_searchable']['mappings']['users']['properties']).to eq(
          "name"=> {"type"=>"string", "index"=>"not_analyzed"}
        )
      end
    end
  end

  context 'activerecord class with optional :json config' do
    context 'creating index' do
      let!(:friend) do
        Friend.create_index
        book = Book.create! :isbn => '123abc', :title => 'another world'
        friend = Friend.new :name => 'bob', :favorite_color => 'red'
        friend.book = book
        friend.save!
        Friend.refresh_index
        friend
      end
      subject(:json) { ElasticSearchable.request(:get, "/elastic_searchable/friends/#{friend.id}")['_source'] }
      it 'indexes json with configuration' do
        expect(json['favorite_color']).to be_nil
        expect(json['book'].key?('isbn')).to be_falsey
        expect(json).to eq(
          "name" => 'bob',
          'book' => { 'title' => 'another world' }
        )
      end
    end
  end

  context 'updating ElasticSearchable.default_index' do
    before do
      ElasticSearchable.default_index = 'my_new_index'
    end
    after do
      ElasticSearchable.default_index = ElasticSearchable::DEFAULT_INDEX
    end
    it { expect(ElasticSearchable.default_index).to eq 'my_new_index' }
  end

  context 'Book class with after_percolate callback' do
    context 'with created index and populated fields' do
      before do
        Book.create_index
        Book.create! :title => 'baz'
      end
      context "when index has configured percolation" do
        before do
          ElasticSearchable.request :put, '/elastic_searchable/.percolator/myfilter', :json_body => {:query => {:query_string => {:query => 'foo' }}}
          ElasticSearchable.request :post, '/elastic_searchable/_refresh'
        end
        context 'creating an object that does not match the percolation' do
          it 'does not percolate the record' do
            expect_any_instance_of(Book).to_not receive(:on_percolated)
            Book.create! :title => 'bar'
          end
        end
        context 'creating an object that matches the percolation' do
          let!(:book) do
            Book.create :title => "foo"
          end
          it do
            expect(book.percolated).to eq ['myfilter']
          end
        end
        context 'percolating a non-persisted object' do
          let!(:matches) { Book.new(:title => 'foo').percolate }
          it do
            expect(matches).to eq ['myfilter']
          end
        end
        context "with multiple percolators in the index" do
          before do
            ElasticSearchable.request :put, '/elastic_searchable/.percolator/greenfilter', :json_body => { :color => 'green', :query => {:query_string => {:query => 'foo' }}}
            ElasticSearchable.request :put, '/elastic_searchable/.percolator/bluefilter', :json_body => { :color => 'blue', :query => {:query_string => {:query => 'foo' }}}
            ElasticSearchable.request :post, '/elastic_searchable/_refresh'
          end
          context 'percolating a non-persisted object with no limitation' do
            let!(:matches) { Book.new(:title => 'foo').percolate }
            it 'returns all percolated matches' do
              expect(matches).to match_array ['myfilter', 'greenfilter', 'bluefilter']
              expect(matches.size).to eq 3
            end
          end
          context 'percolating a non-persisted object with limitations' do
            let!(:matches) { Book.new(:title => 'foo').percolate(:term => { :color => 'green' }) }
            it 'returns limited percolated matches' do
              expect(matches).to eq ['greenfilter']
            end
          end
        end
      end
    end
  end

  context 'with 2 MaxPageSizeClass instances' do
    before do
      MaxPageSizeClass.create_index
      MaxPageSizeClass.create! :name => 'foo one'
      MaxPageSizeClass.create! :name => 'foo two'
      MaxPageSizeClass.refresh_index
    end
    let!(:first) { MaxPageSizeClass.where(:name => 'foo one').first }
    let!(:second) { MaxPageSizeClass.where(:name => 'foo two').first }
    subject(:results) { MaxPageSizeClass.search 'foo' }
    context 'MaxPageSizeClass.search with default options and WillPaginate' do
      before do
        ElasticSearchable::Paginator.handler = ElasticSearchable::Pagination::WillPaginate
      end
      it do
        expect(results.per_page).to eq 1
        expect(results.length).to eq 1
        expect(results.total_entries).to eq 2
      end
    end

    context 'MaxPageSizeClass.search with default options and Kaminari' do
      before do
        ElasticSearchable::Paginator.handler = ElasticSearchable::Pagination::Kaminari
        @results = MaxPageSizeClass.search 'foo'
      end
      it do
        expect(results.per_page).to eq 1
        expect(results.length).to eq 1
        expect(results.total_entries).to eq 2
        expect(results.num_pages).to eq 2
      end
    end

    describe '.escape_query' do
      let(:backslash) { "\\" }
      shared_examples_for "escaped" do
        it { expect(ElasticSearchable.escape_query(queryString)).to eq(backslash + queryString) }
      end
      %w| ! ^ + - { } [ ] ~ * : ? ( ) "|.each do |mark|
        context "escaping '#{mark}'" do
          let(:queryString) { mark }
          it_behaves_like "escaped"
        end
      end
    end
  end
end

