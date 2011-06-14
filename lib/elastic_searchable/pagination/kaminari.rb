module ElasticSearchable
  module Pagination
    class Kaminari < ::ElasticSearchable::Paginator
      attr_accessor :current_page, :per_page, :total_entries, :total_pages

      def initialize(results, page, per_page, total = nil)
        self.current_page = page
        self.per_page     = per_page
        self.total_entries = total if total
        self.replace results
      end

      # total item numbers of the original array
      def total_count
        total_entries
      end

      # Total number of pages
      def num_pages
        (total_count.to_f / per_page).ceil
      end

      # First page of the collection ?
      def first_page?
        current_page == 1
      end

      # Last page of the collection?
      def last_page?
        current_page >= num_pages
      end
    end
  end
end
