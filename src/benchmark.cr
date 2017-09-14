require "./lucky_router"

time = Time.now

router = LuckyRouter::Matcher(Symbol).new

router.add("post/users", :index)
router.add("get/users/:id", :show)
router.add("delete/users/:id", :delete)
router.add("put/users/:id", :update)
router.add("get/users/:id/edit", :edit)
router.add("get/users/:id/new", :new)

1000.times do
  router.match!("post/users")
  router.match!("get/users/1")
  router.match!("delete/users/1")
  router.match!("put/users/1")
  router.match!("get/users/1/edit")
  router.match!("get/users/1/new")
end

elapsed = Time.now - time
elapsed_text = elapsed_text(elapsed)

puts elapsed_text

private def elapsed_text(elapsed)
  minutes = elapsed.total_minutes
  return "#{minutes.round(2)}m" if minutes >= 1

  seconds = elapsed.total_seconds
  return "#{seconds.round(2)}s" if seconds >= 1

  millis = elapsed.total_milliseconds
  return "#{millis.round(2)}ms" if millis >= 1

  "#{(millis * 1000).round(2)}µs"
end
