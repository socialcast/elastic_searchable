module ElasticSearchable
  module Server
    class Railtie < ::Rails::Railtie

      rake_tasks do
        load 'elastic_searchable/server/tasks.rb'
      end

    end
  end
end
