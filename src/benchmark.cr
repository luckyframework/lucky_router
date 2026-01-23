require "benchmark"
require "./lucky_router"

router = LuckyRouter::Matcher(Symbol).new

router.add("get", "/users", :index)
router.add("post", "/users", :create)
router.add("get", "/users/:id", :show)
router.add("delete", "/users/:id", :delete)
router.add("put", "/users/:id", :update)
router.add("get", "/users/:id/edit", :edit)
router.add("get", "/users/:id/new", :new)

router.add("get", "/posts/*", :index)
router.add("get", "/reports/*:filter", :index)
router.add("get", "/feed/?:year/?:month", :index)
router.add("get", "/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z", :show)
router.add("get", "/get/var/:b/:c/:d/:e/:f/:g/:h/:i/:j/:k/:l/:m/:n/:o/:p/:q/:r/:s/:t/:u/:v/:w/:x/:y/:z", :show)
router.add("get", "/test/supercalifragilisticexpialidociousfoobarbazqux/1", :show)

Benchmark.ips do |x|
  x.report("LuckyRouter match!") do
    router.match!("get", "/users")
    router.match!("post", "/users")
    router.match!("get", "/users/1")
    router.match!("delete", "/users/1")
    router.match!("put", "/users/1")
    router.match!("get", "/users/1/edit")
    router.match!("get", "/users/1/new")

    router.match!("get", "/posts/top")
    router.match!("get", "/reports/special/case")
    router.match!("get", "/feed/2021")
    router.match!("get", "/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z")
    router.match!("get", "/get/var/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z")
    router.match!("get", "/test/supercalifragilisticexpialidociousfoobarbazqux/1")
  end
end
