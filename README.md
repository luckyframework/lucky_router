# LuckyRouter

[![API Documentation Website](https://img.shields.io/website?down_color=red&down_message=Offline&label=API%20Documentation&up_message=Online&url=https%3A%2F%2Fluckyframework.github.io%2Flucky_router%2F)](https://luckyframework.github.io/lucky_router)

A library for routing HTTP request with Crystal

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  lucky_router:
    github: luckyframework/lucky_router
```

## Usage

```crystal
require "lucky_router"

router = LuckyRouter::Matcher(Symbol).new

router.add("get", "/users", :index)
router.add("delete", "/users/:id", :delete)

router.match("get", "/users").payload # :index
router.match("get", "/users").params # {} of String => String
router.match("delete", "/users/1").payload # :delete
router.match("delete", "/users/1").params # {"id" => "1"}
router.match("get", "/missing_route").payload # nil
```

## Contributing

1. Fork it ( https://github.com/luckyframework/lucky_router/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Make your changes
4. Run `./bin/test` to run the specs, build shards, and check formatting
5. Commit your changes (git commit -am 'Add some feature')
6. Push to the branch (git push origin my-new-feature)
7. Create a new Pull Request

## Contributors

- [paulcsmith](https://github.com/paulcsmith) Paul Smith - creator, maintainer
