require "elastic_searchable/server/elasticsearch"

if defined?(Rails) && Rails::VERSION::MAJOR == 3
  require 'elastic_searchable/server/railtie'
end
