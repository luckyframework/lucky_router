require "./lucky_router"

router = LuckyRouter::Matcher(Symbol).new

router.add("get", "/users", :index)
router.add("post", "/users", :create)
router.add("get", "/users/:id", :show)
router.add("delete", "/users/:id", :delete)
router.add("put", "/users/:id", :update)
router.add("get", "/users/:id/edit", :edit)
router.add("get", "/users/:id/new", :new)

elapsed_times = [] of Time::Span
10.times do
  elapsed = Time.measure do
    100_000.times do
      router.match!("post", "/users")
      router.match!("get", "/users/1")
      router.match!("delete", "/users/1")
      router.match!("put", "/users/1")
      router.match!("get", "/users/1/edit")
      router.match!("get", "/users/1/new")
      router.match("get", "/no/match/found")
    end
  end
  elapsed_times << elapsed
end

sum = elapsed_times.sum
average = sum / elapsed_times.size
puts "Average time: " + elapsed_text(average)

private def elapsed_text(elapsed)
  minutes = elapsed.total_minutes
  return "#{minutes.round(2)}m" if minutes >= 1

  seconds = elapsed.total_seconds
  return "#{seconds.round(2)}s" if seconds >= 1

  millis = elapsed.total_milliseconds
  return "#{millis.round(2)}ms" if millis >= 1

  "#{(millis * 1000).round(2)}µs"
end
