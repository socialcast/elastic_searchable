# elastic_searchable

Integrate the elasticsearch library into Rails.

## Usage

```ruby
class Blog < ActiveRecord::Base
  elastic_searchable
end

results = Blog.search 'foo'
```

## Features

* fast. fast! FAST! 30% faster than rubberband on average.
* active record callbacks automatically keep search index up to date as your data changes
* out of the box background indexing of data using backgrounded.  Don't lock up a foreground process waiting on a background job!
* integrates with will_paginate library for easy pagination of search results

## Installation

```ruby
# Bundler Gemfile
gem 'elastic_searchable'
```

## Configuration

```ruby
# config/initializers/elastic_searchable.rb
# (optional) customize elasticsearch host
# default is localhost:9200
ElasticSearchable.base_uri 'server:9200'

# (optional) customize elasticsearch paginator
# default is ElasticSearchable::Pagination::WillPaginate
ElasticSearchable::Paginator.handler = ElasticSearchable::Pagination::Kaminari
```

## Contributing
 
* Fork the project
* Fix the issue
* Add unit tests
* Submit pull request on github

See CONTRIBUTORS.txt for list of project contributors

## Copyright

Copyright (c) 2011 Socialcast, Inc. 
See LICENSE.txt for further details.

