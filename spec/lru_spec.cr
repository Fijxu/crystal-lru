require "./spec_helper"

describe LRUCache do
  describe "#initialize" do
    it "creates an empty LRU with given max size" do
      cache = LRUCache(String).new(100)
      cache.max_size.should eq(100)
    end
  end

  describe "#get" do
    it "returns nil for missing keys" do
      cache = LRUCache(String).new(10)
      cache.get("unknown_key").should be_nil
    end
  end

  describe "eviction" do
    it "evicts least recently used item when full" do
      cache = LRUCache(Bool).new(2)
      cache.set("1", true)
      cache.set("2", true)
      cache.set("3", true)
      cache.get("1").should be_nil
      cache.get("2").should eq(true)
      cache.get("3").should eq(true)
    end
  end
end

