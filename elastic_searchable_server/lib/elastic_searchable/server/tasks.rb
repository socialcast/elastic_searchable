namespace :elastic_searchable do
  namespace :server do

    desc "Start an ElasticSearch instance in the background"
    task :start => :environment do
      case RUBY_PLATFORM
      when /w(in)?32$/, /java$/
        abort("This command is not supported on #{RUBY_PLATFORM}. " +
              "Use rake elastic_searchable:server:run to run ElasticSearch in the foreground.")
      end

      ElasticSearchable::Server::ElasticSearch.new.start

      puts "Successfully started ElasticSearch ..."
    end

    desc 'Run the ElasticSearch instance in the foreground'
    task :run => :environment do
      ElasticSearchable::Server::ElasticSearch.new.run
    end

    desc 'Stop the ElasticSearch instance'
    task :stop => :environment do
      case RUBY_PLATFORM
      when /w(in)?32$/, /java$/
        abort("This command is not supported on #{RUBY_PLATFORM}. " +
              "Use rake elastic_searchable:server:run to run ElasticSearch in the foreground.")
      end

      ElasticSearchable::Server::ElasticSearch.new.stop

      puts "Successfully stopped ElasticSearch ..."
    end
  end
end
