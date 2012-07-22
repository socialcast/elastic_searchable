# ElasticSearchableServer

A bundled ElasticSearch server for Rails 3.

## Installation

Add this line to your application's Gemfile:

    gem 'elastic_searchable_server'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install elastic_searchable_server

## Usage

```
rake elastic_searchable:server:run         # Run the ElasticSearch instance in the foreground
rake elastic_searchable:server:start       # Start an ElasticSearch instance in the background
rake elastic_searchable:server:stop        # Stop the ElasticSearch instance
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
