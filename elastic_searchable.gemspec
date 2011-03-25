Gem::Specification.new do |s|
  s.name = %q{elastic_searchable}
  s.version = "0.6.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ryan Sonnek"]
  s.email = %q{ryan@codecrate.com}
  s.date = %q{2011-03-08}
  s.description = %q{integrate the elastic search engine with rails}
  s.summary = %q{elastic search for activerecord}

  s.homepage = %q{http://github.com/wireframe/elastic_searchable}
  s.licenses = ["MIT"]

  s.add_development_dependency  "shoulda", ">= 0"
  s.add_runtime_dependency 'commander', '>= 4.0'
  s.add_runtime_dependency 'rest-client', '>= 1.4.0'
  s.add_runtime_dependency 'json', '>= 1.4.6'

  s.require_paths = ["lib"]
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }


  s.rubygems_version = %q{1.5.2}
  s.test_files = [
    "test/helper.rb",
    "test/test_elastic_searchable.rb"
  ]

  s.add_runtime_dependency(%q<activerecord>, ["~> 2.3.5"])
  s.add_runtime_dependency(%q<httparty>, ["~> 0.6.0"])
  s.add_runtime_dependency(%q<backgrounded>, ["~> 0.7.0"])
  s.add_runtime_dependency(%q<will_paginate>, ["~> 2.3.15"])
  s.add_runtime_dependency(%q<larsklevan-after_commit>, ["~> 1.0.5"])
  s.add_development_dependency(%q<shoulda>, [">= 0"])
  s.add_development_dependency(%q<mocha>, [">= 0"])
  s.add_development_dependency(%q<jeweler>, ["~> 1.5.2"])
  s.add_development_dependency(%q<rcov>, [">= 0"])
  s.add_development_dependency(%q<sqlite3-ruby>, ["~> 1.3.2"])
end

