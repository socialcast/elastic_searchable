# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "elastic_searchable/version"

Gem::Specification.new do |s|
  s.name = %q{elastic_searchable}
  s.version     = ElasticSearchable::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ryan Sonnek"]
  s.email       = ["ryan@codecrate.com"]
  s.homepage    = %q{http://github.com/wireframe/elastic_searchable}
  s.summary     = %q{elastic search for activerecord}
  s.description = %q{integrate the elastic search engine with rails}

  s.rubyforge_project = "elastic_searchable"
  
  s.add_runtime_dependency(%q<activerecord>, ["~> 3.0.0"])
  s.add_runtime_dependency(%q<httparty>, ["~> 0.6.0"])
  s.add_runtime_dependency(%q<backgrounded>, ["~> 0.7.0"])
  s.add_runtime_dependency(%q<will_paginate>, [">= 2.3.15"])
  s.add_development_dependency(%q<shoulda>, [">= 0"])
  s.add_development_dependency(%q<mocha>, [">= 0"])
  s.add_development_dependency(%q<bundler>, [">= 0"])
  s.add_development_dependency(%q<rcov>, [">= 0"])
  s.add_development_dependency(%q<sqlite3-ruby>, ["~> 1.3.2"])
  s.add_development_dependency(%q<ruby-debug>, [">= 0"])


  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

