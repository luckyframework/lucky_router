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

## Matching without parameters

When only the payload is needed, `match_payload` skips the parameter hash and
capture strings:

```crystal
router.match_payload("delete", "/users/1") # :delete
router.match_payload("get", "/missing")  # nil
```

The existing `match` and `match!` APIs still return a separate mutable parameter
hash for every successful request. Matching methods remain case-sensitive;
registering a GET route also registers the existing lowercase `head` alias.

## Compiling registered routes

Applications that finish registering routes before serving requests can opt into
a compiled snapshot:

```crystal
compiled = router.compile
compiled.match!("delete", "/users/1").params # {"id" => "1"}
compiled.match_payload("get", "/users")     # :index
```

Snapshots index exact static paths, compress literal prefixes, and exclude
dynamic siblings that cannot handle the requested method. They preserve route
precedence, capture names, optional arguments, globs, URI decoding, and trailing
slash behavior. Compilation takes extra time and memory; the original matcher
keeps its live route tree and has no static-index lookup overhead.

A snapshot retains the routes and payload references present when it was built.
Call `router.compile` again after adding routes or mutating the public fragment
containers. Updating a payload object's contents is visible through either
matcher because the payload object is shared.

See [performance measurements and tradeoffs](benchmarks/README.md) for the
benchmark commands and the alternatives evaluated.

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
