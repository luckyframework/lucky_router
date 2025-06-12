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

Benchmark.ips do |x|
  x.report("LuckyRouter match!") do
    router.match!("post", "/users")
    router.match!("get", "/users/1")
    router.match!("delete", "/users/1")
    router.match!("put", "/users/1")
    router.match!("get", "/users/1/edit")
    router.match!("get", "/users/1/new")
  end
end
