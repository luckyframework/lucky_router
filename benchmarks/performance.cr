require "../src/lucky_router"
require "json"

# Run with --release. Each sample measures individual requests, not a batch
# labelled as one request. Allocation counts include the returned params hash.
module RouterPerformance
  ITERATIONS = ENV.fetch("BENCH_ITERATIONS", "200000").to_i
  SAMPLES    = ENV.fetch("BENCH_SAMPLES", "7").to_i

  def self.measure(name : String, iterations = ITERATIONS, & : -> UInt64) : Nil
    checksum = 0_u64
    Math.min(iterations, 10_000).times { checksum &+= yield }
    timings = [] of Float64
    allocations = [] of Float64
    SAMPLES.times do
      GC.collect
      before = GC.stats.total_bytes
      start = Time.instant
      iterations.times { checksum &+= yield }
      timings << (Time.instant - start).total_nanoseconds / iterations
      allocations << (GC.stats.total_bytes - before).to_f / iterations
    end
    puts({name: name, ns: timings.sort[SAMPLES // 2], bytes: allocations.sort[SAMPLES // 2], checksum: checksum}.to_json)
  end

  def self.consume(result) : UInt64
    result ? (result.payload + result.params.size).to_u64 : 0_u64
  end
end

router = LuckyRouter::Matcher(Int32).new
{"/fixed", "/a/b/c/d/e", "/users/:id", "/accounts/:account_id/users/:id", "/files/*:rest", "/optional/?:id"}.each_with_index do |route, i|
  router.add("get", route, i + 1)
end
[15, 16, 100].each do |size|
  router.add("get", "/#{(1..size).map { |i| "s#{i}" }.join('/')}", size)
end
router.add("get", "/many/#{(1..20).map { |i| ":p#{i}" }.join('/')}", 20)

cases = {
  "static_one"      => "/fixed",
  "static_five"     => "/a/b/c/d/e",
  "one_capture"     => "/users/42",
  "two_captures"    => "/accounts/42/users/7",
  "optional"        => "/optional/7",
  "glob"            => "/files/a/b/c/d/e",
  "encoded_capture" => "/users/a%2Fb",
  "encoded_glob"    => "/files/a%2Fb/c%20d/e/",
  "early_miss"      => "/missing/path/with/several/segments",
  "late_miss"       => "/accounts/42/users/7/missing",
  "16_segments"     => "/#{(1..15).map { |i| "s#{i}" }.join('/')}",
  "17_segments"     => "/#{(1..16).map { |i| "s#{i}" }.join('/')}",
  "100_segments"    => "/#{(1..100).map { |i| "s#{i}" }.join('/')}",
  "20_captures"     => "/many/#{(1..20).map { |i| "v#{i}" }.join('/')}",
}
cases.each do |name, path|
  RouterPerformance.measure(name) { RouterPerformance.consume(router.match("get", path)) }
end
RouterPerformance.measure("wrong_method") { RouterPerformance.consume(router.match("delete", "/accounts/42/users/7")) }

mixed = cases.values
cursor = 0
RouterPerformance.measure("mixed") do
  path = mixed[cursor]
  cursor = (cursor + 1) % mixed.size
  RouterPerformance.consume(router.match("get", path))
end

# This conditional keeps the same harness compilable against older versions.
if router.responds_to?(:match_payload)
  cases.each do |name, path|
    RouterPerformance.measure("payload_#{name}") { (router.match_payload("get", path) || 0).to_u64 }
  end
end

registration = (1..100).map { |i| "/route#{i}/a/b/:id" }
optional = (1..20).map { |i| "/route#{i}/?:a/fixed/?:b/?:c" }
{"registration" => registration, "optional_registration" => optional}.each do |name, routes|
  RouterPerformance.measure(name, 100) do
    fresh = LuckyRouter::Matcher(Int32).new
    routes.each_with_index { |route, i| fresh.add("get", route, i) }
    fresh.normalized_paths.size.to_u64
  end
end
large = LuckyRouter::Matcher(Int32).new
registration.each_with_index { |route, i| large.add("get", route, i) }
RouterPerformance.measure("enumeration", 1_000) { large.list_routes.size.to_u64 }

# Distinct capture names deliberately produce siblings with insertion priority.
siblings = LuckyRouter::Matcher(Int32).new
100.times { |i| siblings.add("get", "/:capture#{i}/end#{i}", i + 1) }
RouterPerformance.measure("dynamic_backtracking") { RouterPerformance.consume(siblings.match("get", "/value/end99")) }
RouterPerformance.measure("dynamic_miss") { RouterPerformance.consume(siblings.match("get", "/value/missing")) }

if router.responds_to?(:compile)
  compiled = router.compile
  cases.each do |name, path|
    RouterPerformance.measure("compiled_#{name}") { RouterPerformance.consume(compiled.match("get", path)) }
  end
  cursor = 0
  RouterPerformance.measure("compiled_mixed") do
    path = mixed[cursor]
    cursor = (cursor + 1) % mixed.size
    RouterPerformance.consume(compiled.match("get", path))
  end
end

if siblings.responds_to?(:compile)
  compiled_siblings = siblings.compile
  RouterPerformance.measure("compiled_dynamic_backtracking") { RouterPerformance.consume(compiled_siblings.match("get", "/value/end99")) }
  RouterPerformance.measure("compiled_dynamic_miss") { RouterPerformance.consume(compiled_siblings.match("get", "/value/missing")) }
end

methods = LuckyRouter::Matcher(Int32).new
100.times { |i| methods.add("method#{i}", "/:capture#{i}/end#{i}", i + 1) }
RouterPerformance.measure("method_backtracking") { RouterPerformance.consume(methods.match("method99", "/value/end99")) }
RouterPerformance.measure("method_miss") { RouterPerformance.consume(methods.match("absent", "/value/end99")) }
if methods.responds_to?(:compile)
  compiled_methods = methods.compile
  RouterPerformance.measure("compiled_method_backtracking") { RouterPerformance.consume(compiled_methods.match("method99", "/value/end99")) }
  RouterPerformance.measure("compiled_method_miss") { RouterPerformance.consume(compiled_methods.match("absent", "/value/end99")) }
end
