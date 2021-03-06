require File.join(File.dirname(__FILE__),'test_helper')
require 'couchtiny/hash_doc'
require 'json'

class TestHashDoc < Test::Unit::TestCase
  context "empty doc" do
    setup do
      @d = CouchTiny::HashDoc.new
    end

    should "delegate to hash" do
      assert @d.respond_to?(:empty?)
      assert @d.empty?
    end
  end
  
  context "doc initialised from hash" do
    setup do
      @d = CouchTiny::HashDoc.new({"foo"=>"bar"})
    end
    
    should "initialise" do
      assert_equal({"foo"=>"bar"}, @d.to_hash)
    end
  
    should "compare to hash" do
      assert_equal({"foo"=>"bar"}, @d)
      assert_equal(@d, {"foo"=>"bar"})
    end

    should "delegate to hash" do
      assert !@d.empty?
      assert_equal 'bar', @d['foo']
      @d['foo'] = 'baz'
      assert_equal 'baz', @d['foo']
    end
    
    should "delegate to different hash" do
      @d.doc = {"bar"=>"baz"}
      assert_equal({"bar"=>"baz"}, @d.to_hash)
    end
    
    should "merge! to the underlying hash" do
      @d.merge! "bar"=>"baz"
      assert_equal({"foo"=>"bar","bar"=>"baz"}, @d)
    end

    should "delegate to_json" do
      assert_equal '{"foo":"bar"}', @d.to_json
    end
  end
end
