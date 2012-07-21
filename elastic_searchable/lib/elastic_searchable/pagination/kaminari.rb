module ElasticSearchable
  module Pagination
    class Kaminari < ::ElasticSearchable::Paginator
      attr_accessor :page, :limit_value, :total_entries, :total_pages

      def initialize(results, page, per_page, total = nil)
        self.page          = page
        self.limit_value   = per_page
        self.total_entries = total if total
        self.replace results
      end

      alias :current_page :page
      alias :per_page     :limit_value

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
