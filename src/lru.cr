require "log"

# A simple LRU Cache to store items of whatever type `T`
class LRUCache(T)
  VERSION = "1.0.0"
  Log     = ::Log.for(self)

  struct Item(T)
    getter value, expires_at

    def initialize(@value : T, @expires_at : Int64?)
    end
  end

  # Gets the max amount of items the LRU cache can hold.
  getter max_size : (Int64 | Int32)
  @clean_interval : Time::Span?
  @lru = {} of String => Item(T)
  @access = [] of String

  # Creates a new `LRUCache` with the given `max_size` and `clean_interval`
  def initialize(
    @max_size,
    @clean_interval = 1.seconds,
  )
    if i = @clean_interval
      Log.debug &.emit("clean interval set to '#{clean_interval}'")
      spawn(name: {{ @type.name.stringify }}) do
        loop do
          self.cleaner
          sleep i
        end
      end
    end
  end

  # :nodoc:
  private def cleaner
    Log.trace &.emit("cleaning old items")
    current_time = Time.utc.to_unix
    sample_size = (@lru.size * 0.25).ceil.to_i
    sample = @lru.sample(sample_size)

    sample.each do |key, item|
      if expires_at = item.expires_at
        if expires_at < current_time
          self.del(key)
          Log.trace &.emit("item '#{key}' expired")
        end
      end
    end
  end

  # Sets a item of the desired Type `T` into the LRU Cache.
  #
  # `expire_time` argument is in seconds.
  #
  # ```
  # cache = LRUCache(String).new(5)
  #
  # cache.set("key", "value", 5)
  #
  # pp cache.get("key") # => "value"
  # ```
  def set(key : String, value : T, expire_time : Int64? = nil) : Nil
    expire_time ? (expires_at = Time.utc.to_unix + expire_time) : (expires_at = nil)
    item = Item(T).new(value, expires_at)
    self[key] = item
    Log.debug &.emit("inserted item '#{key}'")
  end

  # Deletes a item from the LRU Cache.
  #
  # `expire_time` argument is in seconds.
  #
  # ```
  # cache = LRUCache(String).new(5)
  #
  # cache.set("key", "value", 5)
  # cache.del("key")
  #
  # pp cache.get("key") # => nil
  # ```
  def del(key : String) : Nil
    self.delete(key)
    Log.debug &.emit("deleted item '#{key}'")
  end

  # Gets the item associated with the `key`
  #
  # ```
  # cache = LRUCache(String).new(5)
  #
  # cache.set("key", "value", 5)
  #
  # pp cache.get("key") # => "value"
  # ```
  def get(key : String) : T?
    cached = self[key]
    if cached
      Log.debug &.emit("retrieved item '#{key}'")
      cached.value
    else
      nil
    end
  end

  # Gets the current amount of items the LRU cache is holding.
  #
  # ```
  # cache = LRUCache(String).new(5)
  #
  # cache.set("key", "value", 5)
  # cache.set("key2", "value2")
  #
  # pp cache.size # => 2
  # ```
  def size : Int64
    @lru.size.to_i64
  end

  # Gets all the items that the LRU cache is holding.
  #
  # ```
  # cache = LRUCache(String).new(5)
  #
  # cache.set("key", "value", 5)
  # cache.set("key2", "value2")
  #
  # pp cache.items # => {"key" => LRUCache::Item(String)(@expires_at=1771043818, @value="value"), "key2" => LRUCache::Item(String)(@expires_at=nil, @value="value2")}
  # ```
  def items : Hash(String, Item(T))
    @lru
  end

  private def [](key : String) : Item(T)?
    if @lru[key]?
      @access.delete(key)
      @access.push(key)
      @lru[key]
    else
      nil
    end
  end

  private def []=(key : String, item : Item(T)) : Nil
    if @lru.size >= @max_size
      lru_key = @access.shift
      @lru.delete(lru_key)
    end
    @lru[key] = item
    @access.push(key)
  end

  private def delete(key : String) : Nil
    if @lru[key]?
      @lru.delete(key)
      @access.delete(key)
    end
  end
end
