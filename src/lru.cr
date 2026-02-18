require "log"

# A simple LRU Cache to store items of whatever type `T`
class LRUCache(T)
  VERSION = "1.0.4"
  Log     = ::Log.for(self)

  struct Item(T)
    getter value, expires_at

    def initialize(@value : T, @expires_at : Int64?)
    end
  end

  # Event types for the event listener
  enum EventType
    # A new key is set
    Set
    # A key is retrieved
    Get
    # A key is deleted
    Del
    # A key expired
    Exp
  end

  # Event struct containing the key related to it's `EventType`
  struct Event
    # The key of the item that was handled by the LRU cache.
    getter key : String
    # The event type that got fired.
    getter event_type : EventType

    def initialize(@key, @event_type)
    end
  end

  # Gets the max amount of items the LRU cache can hold.
  getter max_size : (Int64 | Int32)
  @clean_interval : Time::Span?
  @lru = {} of String => Item(T)
  @access = [] of String
  @events = Channel(Event).new
  @events_enabled = false

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
          self.send_event(key, EventType::Exp)
          Log.trace &.emit("item expired", key: key)
        end
      end
    end
  end

  # Define a callback for when a new event is received.
  #
  # ```
  # cache = LRUCache(String).new(5)
  #
  # cache.on_event do |e|
  #   puts e.key
  #   puts e.event_type
  # end
  # ```
  def on_event(&block : Event ->)
    @events_enabled = true
    spawn do
      loop do
        event = @events.receive
        block.call(event)
      end
    end
  end

  # Sends events to the event channel, it will only send events if `on_event`
  # was called.
  private def send_event(key : String, event_type : EventType)
    return if !@events_enabled
    Log.trace &.emit("event sent", key: key, event_type: event_type.to_s)
    event = Event.new(key, event_type)
    @events.send(event)
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
  def set(key : String, value : T, expire_time : Int? = nil) : Nil
    expire_time ? (expires_at = Time.utc.to_unix + expire_time) : (expires_at = nil)
    item = Item(T).new(value, expires_at)
    self[key] = item
    self.send_event(key, EventType::Set)
    Log.debug &.emit("inserted item", key: key)
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
    self.send_event(key, EventType::Del)
    Log.debug &.emit("deleted item", key: key)
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
    self.send_event(key, EventType::Get)
    if cached
      Log.debug &.emit("retrieved item", key: key)
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
