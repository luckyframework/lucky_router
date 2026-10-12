require "./spec_helper"

describe "allocation-conscious matching" do
  it "preserves branch insertion priority across different capture names" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/:a/:tail/x", :first)
    router.add("get", "/:b/fixed/:tail", :second)
    result = router.match!("get", "/foo/fixed/x")
    result.payload.should eq(:first)
    result.params.should eq({"a" => "foo", "tail" => "fixed"})
    router.match_payload("get", "/foo/fixed/x").should eq(:first)
  end

  it "retains outermost captures when names repeat" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/:id/:id", :show)
    router.match!("get", "/outer/inner").params.should eq({"id" => "outer"})
  end

  it "observes mutations through all public route containers" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/fixed", :original)
    leaf = router.root.static_parts[""].static_parts["fixed"]
    leaf.method_to_payload["get"] = :changed
    router.match_payload("get", "/fixed").should eq(:changed)
    router.match!("get", "/fixed").payload.should eq(:changed)
    router.root.static_parts[""].static_parts.delete("fixed")
    router.match("get", "/fixed").should be_nil
    router.root.process_parts(LuckyRouter::PathPart.split_path("/:id"), "get", :dynamic)
    router.match!("get", "/new").params.should eq({"id" => "new"})
    router.root.static_parts[""].dynamic_parts.clear
    router.match_payload("get", "/new").should be_nil
  end

  it "keeps each match's mutable parameter hash independent" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/fixed", :show)
    first = router.match!("get", "/fixed")
    copy = first
    copy.params["extra"] = "value"
    first.params["extra"].should eq("value")
    router.match!("get", "/fixed").params.should be_empty
  end

  it "preserves decoded-after-split and malformed escape behavior" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/users/:id", :show)
    {"a%2Fb" => "a/b", "%FF" => String.new(Bytes[255]), "%00" => "\u0000", "%A%20" => "%A ", "a+b" => "a+b", "%/" => "%/", "%2" => "%2"}.each do |input, expected|
      router.match!("get", "/users/#{input}").params["id"].should eq(expected)
    end
    router.add("get", "/static/a%2Fb", :encoded)
    router.match_payload("get", "/static/a%2fb").should eq(:encoded)
  end

  it "copies glob suffixes with exactly the reader's trailing slash semantics" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/files/*:rest", :files)
    ["a//b/", "a//", "%/", "%A/", "%2F/", "%/a/", "%25/a+b/"].each do |suffix|
      expected = LuckerRouter::PathReader.new(suffix).to_a.join('/')
      router.match!("get", "/files/#{suffix}").params["rest"].should eq(expected)
    end
  end

  it "handles paths well beyond the old stack buffer" do
    router = LuckyRouter::Matcher(Symbol).new
    route = "/" + (1..100).map { |i| "s#{i}" }.join('/')
    router.add("get", route, :deep)
    router.match!("get", route).payload.should eq(:deep)
    router.match_payload("head", route + "/").should eq(:deep)
    router.match_payload("GET", route).should be_nil
  end

  it "keeps route collection order and independent retained path arrays" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/a/:id", :dynamic)
    router.add("post", "/a/fixed", :static)
    router.add("put", "/a/*", :glob)
    routes = router.root.collect_routes
    routes.map { |parts, method, payload| {"/" + parts.reject(&.part.empty?).map(&.part).join('/'), method, payload} }.should eq(router.list_routes)
    routes[0][0].clear
    routes[1][0].should_not be_empty
  end
end

describe LuckerRouter::PathReader do
  it "decodes all single-byte values like URI.decode" do
    256.times do |byte|
      encoded = "%#{byte.to_s(16).rjust(2, '0')}"
      LuckerRouter::PathReader.new(encoded).to_a.should eq([URI.decode(encoded)])
    end
  end
end

describe LuckyRouter::CompiledMatcher do
  it "retains a snapshot until explicitly recompiled" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/fixed", :original)
    compiled = router.compile
    router.root.static_parts[""].static_parts["fixed"].method_to_payload["get"] = :changed
    router.add("get", "/new/:id", :new)
    compiled.match!("get", "/fixed").payload.should eq(:original)
    compiled.match_payload("get", "/new/value").should be_nil
    router.compile.match_payload("get", "/new/value").should eq(:new)
  end

  it "preserves root, empty-segment, slash and encoded literal semantics" do
    ["", "/", "/a", "/a//", "///", "a/b", "/a%2Fb", "/%25ab"].each do |route|
      router = LuckyRouter::Matcher(Symbol).new
      router.add("get", route, :static)
      compiled = router.compile
      ["", "/", "/a", "/a/", "/a//", "/a///", "//", "///", "////", "a/b", "a/b/", "/a/b", "/a%2Fb", "/%25ab", "/%ab"].each do |path|
        expected = router.match("get", path)
        actual = compiled.match("get", path)
        {actual.try(&.payload), actual.try(&.params)}.should eq({expected.try(&.payload), expected.try(&.params)})
        compiled.match_payload("get", path).should eq(expected.try(&.payload))
      end
    end
  end

  it "preserves named sibling priority and method fallback through compressed prefixes" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/api/v1/:a/:tail/x", :first)
    router.add("get", "/api/v1/:b/fixed/:tail", :second)
    router.add("post", "/api/v1/:b/fixed/:tail", :post)
    router.add("get", "/api/v1/fixed/fixed/x", :static)
    router.add("put", "/api/v1/*:rest", :glob)
    compiled = router.compile
    ["get", "post", "put", "head", "GET"].each do |method|
      ["/api/v1/foo/fixed/x", "/api/v1/fixed/fixed/x", "/api/v1/a%2Fb/fixed/x", "/api/v1//fixed/x", "/api/v1/other/path/", "/api/v1"].each do |path|
        expected = router.match(method, path)
        actual = compiled.match(method, path)
        {actual.try(&.payload), actual.try(&.params)}.should eq({expected.try(&.payload), expected.try(&.params)})
      end
    end
  end

  it "allocates an independent params hash for each static match" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/fixed", :fixed)
    compiled = router.compile
    compiled.match!("get", "/fixed").params["extra"] = "value"
    compiled.match!("get", "/fixed").params.should be_empty
  end
end

describe "streaming and compiled traversal compatibility" do
  it "agrees with the segment-array Fragment API on generated paths" do
    random = Random.new(731)
    router = LuckyRouter::Matcher(Int32).new
    ["/", "/fixed", "/a/b/c", "/users/:id", "/users/:id/edit", "/files/*:rest", "/optional/?:id/?:tail", "/:a/:tail/x", "/:b/fixed/:tail", "/unicode/é", "/space/a b", "/repeat/:id/:id"].each_with_index do |route, i|
      router.add("get", route, i + 1)
    end
    compiled = router.compile
    segments = ["", "users", "files", "optional", "a", "b", "x", "fixed", "unicode", "é", "space", "a b", "%", "%2", "%2F", "%20", "%FF", "%00", "%zz", "%/", "%A/", "%25", "%A%20", "+", "repeat"]
    10_000.times do
      path = Array.new(random.rand(0..8)) { segments.sample(random) }.join('/')
      method = ["get", "head", "delete", "GET"].sample(random)
      expected = router.root.find_match(LuckerRouter::PathReader.new(path).to_a, method)
      [router.match(method, path), compiled.match(method, path)].each do |actual|
        {actual.try(&.payload), actual.try(&.params)}.should eq({expected.try(&.payload), expected.try(&.params)})
      end
      router.match_payload(method, path).should eq(expected.try(&.payload))
      compiled.match_payload(method, path).should eq(expected.try(&.payload))
    end
  end

  it "retains the existing false and nil payload behavior" do
    router = LuckyRouter::Matcher(Bool?).new
    router.add("get", "/false", false)
    router.add("get", "/nil", nil)
    router.add("get", "/true/:id", true)
    compiled = router.compile
    ["/false", "/nil"].each do |path|
      router.match("get", path).should be_nil
      router.match_payload("get", path).should be_nil
      compiled.match("get", path).should be_nil
      compiled.match_payload("get", path).should be_nil
    end
    compiled.match!("get", "/true/value").params.should eq({"id" => "value"})
    router.match_payload("get", "/true/value").should be_true
  end
end

describe "bounded percent decoding" do
  it "agrees with URI.decode for generated raw byte ranges" do
    random = Random.new(918)
    1_000.times do
      value = String.new(Bytes.new(random.rand(0..64)) { random.rand(0..255).to_u8 })
      path = "prefix" + value + "suffix"
      LuckerRouter::PathReader.decode_range(path, 6, value.bytesize).should eq(URI.decode(value))
    end
  end
end

describe "compiled capture capacity" do
  it "preserves bindings for many captures and repeated names" do
    router = LuckyRouter::Matcher(Symbol).new
    route = "/many/" + (1..80).map { |i| ":p#{i}" }.join('/')
    path = "/many/" + (1..80).map { |i| "v#{i}" }.join('/')
    router.add("get", route, :many)
    router.add("get", "/repeat/:id/:id/*:id", :repeated)
    compiled = router.compile
    compiled.match!("get", path).params.should eq(router.match!("get", path).params)
    compiled.match!("get", "/repeat/first/second/third/fourth").params.should eq({"id" => "first"})
  end
end

describe "snapshot indexing of manually constructed fragments" do
  it "uses static edge keys and branch kinds rather than PathPart metadata" do
    router = LuckyRouter::Matcher(Symbol).new
    static = LuckyRouter::Fragment(Symbol).new(LuckyRouter::PathPart.new("display"))
    static.method_to_payload["get"] = :static
    router.root.static_parts["actual"] = static
    glob = LuckyRouter::Fragment(Symbol).new(LuckyRouter::PathPart.new("wildcard"))
    glob.method_to_payload["get"] = :glob
    router.root.glob_part = glob
    compiled = router.compile
    ["actual", "actual/", "display", "display/", "wildcard", ""].each do |path|
      expected = router.match("get", path)
      actual = compiled.match("get", path)
      {actual.try(&.payload), actual.try(&.params)}.should eq({expected.try(&.payload), expected.try(&.params)})
    end
  end
end

describe "snapshots without the exact static index" do
  it "preserves routes, precedence, method filtering, captures and slash aliases" do
    router = LuckyRouter::Matcher(Symbol).new
    ["/", "/a//", "/fixed", "/encoded/a%2Fb", "/optional/?:id", "/files/*:rest", "/:a/:tail/x", "/:b/fixed/:tail"].each do |route|
      router.add("get", route, :get)
      router.add("post", route, :post)
    end
    indexed = router.compile
    trie = router.compile(static_index: false)
    random = Random.new(921)
    paths = ["", "/", "/a/", "/a//", "/a///", "/fixed", "/fixed/", "/fixed//", "/encoded/a%2Fb", "/optional", "/optional/7", "/files/a%2Fb/c/", "/foo/fixed/x"]
    tokens = ["", "fixed", "optional", "files", "x", "a%2Fb", "%/", "%FF"]
    1_000.times { paths << "/#{Array.new(random.rand(0..6)) { tokens.sample(random) }.join('/')}" }
    paths.each do |path|
      ["get", "post", "head", "HEAD", "delete"].each do |method|
        expected = indexed.match(method, path)
        actual = trie.match(method, path)
        {actual.try(&.payload), actual.try(&.params)}.should eq({expected.try(&.payload), expected.try(&.params)})
        trie.match_payload(method, path).should eq(indexed.match_payload(method, path))
      end
    end
  end
end
