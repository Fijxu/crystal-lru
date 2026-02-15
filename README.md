# crystal-lru

Yet another Crystal LRU Cache library that I use for my Crystal projects.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     lru:
       github: fijxu/crystal-lru
   ```

2. Run `shards install`

## Usage

```crystal
require "lru"

Log.setup(:trace)

max_size = 100
# By default, clean_interval is set to 1.seconds, but it can also be nil!
clean_interval = 1.seconds

cache = LRUCache(String).new(max_size, clean_interval)

# Listen to cache events
cache.on_event do |event|
  puts event.key
  puts event.event_type
end

# Set item to the cache
cache.set("key", "value", 5)
cache.set("key2", "value2")

pp cache.get("key") # => "value"
pp cache.get("key2") # => "value2"
pp cache.get("unknown") # => nil

cache.del("key2")

pp cache.get("key2") # => nil
```

## Development

Clone the repository and modify it at your liking.

## Contributing

1. Fork it (https://github.com/fijxu/crystal-lru/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Fijxu](https://github.com/fijxu) - creator and maintainer
