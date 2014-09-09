class User < ActiveRecord::Base
  elastic_searchable :index_options => {
    'number_of_replicas' => 0,
    'number_of_shards' => 1,
    "analysis.analyzer.default.tokenizer" => 'standard',
    "analysis.analyzer.default.filter" => ["standard", "lowercase", 'porterStem']},
  :mapping => {:properties => {:name => {:type => 'string', :index => 'not_analyzed'}}}
end
