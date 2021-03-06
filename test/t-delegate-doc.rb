require File.join(File.dirname(__FILE__),'test_helper')
require 'couchtiny/delegate_doc'
require 'json'

class TestDelegateDoc < Test::Unit::TestCase
  class Foo < CouchTiny::DelegateDoc
  end
  
  context "empty doc" do
    setup do
      @d = CouchTiny::DelegateDoc.new
    end

    should "delegate to hash" do
      assert @d.respond_to?(:has_key?)
      assert @d.respond_to?(:has_key?,true)   # include private methods
      assert @d.doc.empty?
    end
  end
  
  context "doc initialised from hash" do
    setup do
      @d = CouchTiny::DelegateDoc.new({"foo"=>"bar"})
    end
    
    should "initialise" do
      assert_equal({"foo"=>"bar"}, @d.to_hash)
    end
  
    should "compare to hash" do
      assert_equal({"foo"=>"bar"}, @d)
      assert_equal(@d, {"foo"=>"bar"})
    end

    should "delegate to hash" do
      assert @d.has_key?('foo')
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

    should "dup the underlying hash" do
      h1 = @d.to_hash
      d2 = @d.dup
      h2 = d2.to_hash
      assert_equal h1, h2
      assert h1.object_id != h2.object_id
    end
  end
  
  context "subclass of DelegateDoc" do
    setup do
      @foo = Foo.new
    end
    
    should "honour is_a?" do
      assert @foo.is_a?(Foo)
    end

    should "honour ===" do
      assert Foo === @foo
    end
  end
end
