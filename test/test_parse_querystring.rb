require File.join(File.dirname(__FILE__), 'helper')

class ElasticSearchTest < ActiveSupport::TestCase
  should "escape exclamation marks" do
    queryString = '!'
    result = ElasticSearchable.query_parser_escape(queryString)
    assert_equal '\!', result
  end

  should "escape two exclamation marks" do
    queryString = '!!'
    result = ElasticSearchable.query_parser_escape(queryString)
    assert_equal '\!\!', result
  end

  should "escape five exclamation marks" do
    queryString = '!!!!!'
    result = ElasticSearchable.query_parser_escape(queryString)
    assert_equal '\!\!\!\!\!', result
  end

  should "leave exlamation at the beginning of a word intact" do
    queryString = '!monkey'
    result = ElasticSearchable.query_parser_escape(queryString)
    assert_equal '!monkey', result
  end

  should "escape exclamation mark before whitespace" do
    queryString = '! '
    result = ElasticSearchable.query_parser_escape(queryString)
    assert_equal '\! ', result
  end

  should "escape exclamation mark before closing parens" do
    queryString = '!)'
    result = ElasticSearchable.query_parser_escape(queryString)
    assert_equal '\!\)', result
  end
end
