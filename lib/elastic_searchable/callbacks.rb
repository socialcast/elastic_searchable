module ElasticSearchable
  module Callbacks
    class << self
      def backgrounded_options
        {:queue => 'elasticsearch'}
      end
    end

    module ClassMethods
      puts 'defining'
      # override default after_index callback definition to support :on option
      # see ActiveRecord::Transactions::ClassMethods#after_commit for example
      def after_index(*args, &block)
        options = args.last
        if options.is_a?(Hash) && options[:on]
          puts 'registering!!!'
          options[:if] = Array.wrap(options[:if])
          options[:if] << lambda {|r| 
            puts 'checking!!!!'
            r.index_lifecycle == options[:on] }#"@index_lifecycle == :#{options[:on]}"
        end
        set_callback(:index, :after, *args, &block)
      end
    end

    module InstanceMethods
      private
      def delete_from_index
        self.class.delete_id_from_index_backgrounded self.id
      end
      def update_index_on_create
        reindex :create
      end
      def update_index_on_update
        reindex :update
      end
    end
  end
end
