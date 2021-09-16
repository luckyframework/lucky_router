require "./spec_helper"

describe LuckyRouter do
  it "handles many routes" do
    router = LuckyRouter::Matcher(Symbol).new

    # Here to makes sure things run super fast even with lots of routes
    1000.times do
      router.add("put", "#{UUID.random}", :fake_show)
      router.add("get", "#{UUID.random}/edit", :fake_edit)
      router.add("get", "#{UUID.random}/new/edit", :fake_new_edit)
    end

    router.add("get", "/:organization", :organization)
    router.add("get", "/:organization/:repo", :repo)
    router.add("get", "/posts/:id", :post_index)
    router.add("get", "/users", :index)
    router.add("post", "/users", :create)
    router.add("get", "/users/:id", :show)
    router.add("delete", "/users/:id", :delete)
    router.add("put", "/users/:id", :update)
    router.add("get", "/users/:id/edit", :edit)
    router.add("get", "/users/:id/new", :new)
    router.add("get", "/users/:user_id/tasks/:id", :user_tasks)
    router.add("get", "/admin/users/:user_id/tasks/:id", :admin_user_tasks)
    router.add("get", "/complex_posts/:required/?:optional_1/?:optional_2", :posts_with_complex_params)

    1000.times do
      router.match!("get", "/luckyframework").payload.should eq :organization
      router.match!("get", "/luckyframework/lucky").payload.should eq :repo
      router.match!("get", "/posts/1").payload.should eq :post_index
      router.match!("get", "/users").payload.should eq :index
      router.match!("post", "/users").payload.should eq :create
      router.match!("get", "/users/1").payload.should eq :show
      router.match!("delete", "/users/1").payload.should eq :delete
      router.match!("put", "/users/1").payload.should eq :update
      router.match!("get", "/users/1/edit").payload.should eq :edit
      router.match!("get", "/users/1/new").payload.should eq :new
      router.match!("get", "/users/1/tasks/1").payload.should eq :user_tasks
      router.match!("get", "/admin/users/1/tasks/1").payload.should eq :admin_user_tasks
      router.match!("get", "/complex_posts/1/2/3").payload.should eq :posts_with_complex_params
      router.match!("get", "/complex_posts/1/2").payload.should eq :posts_with_complex_params
      router.match!("get", "/complex_posts/1").payload.should eq :posts_with_complex_params
    end
  end

  it "allows optional route params" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/posts/:required/?:optional_1/?:optional_2", :post_index)

    router.match!("get", "/posts/1").params.should eq({
      "required" => "1",
    })
    router.match!("get", "/posts/1/2").params.should eq({
      "required"   => "1",
      "optional_1" => "2",
    })
    router.match!("get", "/posts/1/2/3/").params.should eq({
      "required"   => "1",
      "optional_1" => "2",
      "optional_2" => "3",
    })
  end

  it "handles root routes" do
    router = LuckyRouter::Matcher(Symbol).new

    router.add("get", "/", :root)

    router.match!("get", "/").payload.should eq :root
  end

  it "allows head routes when a get route is defined" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/health", :health)
    router.match!("head", "/health").payload.should eq :health
  end

  it "does not allow head routes when something else is defined" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("put", "/update", :update)
    router.match("head", "/update").should be_nil
  end

  it "does not blow up when there are no routes" do
    router = LuckyRouter::Matcher(Symbol).new
    router.match("post", "/users")
  end

  it "returns nil if nothing matches" do
    router = LuckyRouter::Matcher(Symbol).new

    router.add("get", "/whatever", :index)
    router.match("get", "/something_else").should be_nil
  end

  it "gets params" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/users/:user_id/tasks/:id", :show)

    router.match!("get", "/users/user_param/tasks/task_param").params.should eq({
      "user_id" => "user_param",
      "id"      => "task_param",
    })
  end

  it "gets params when starting with dynamic paths" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/:organization/:repo", :unused)

    router.match!("get", "/luckyframework/lucky").params.should eq({
      "organization" => "luckyframework",
      "repo"         => "lucky",
    })
  end

  it "does not add params if there is a static match" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/users/foo/tasks/bar", :show)
    router.add("get", "/users/:user_id/tasks/:id", :show)

    params = router.match!("get", "/users/foo/tasks/bar").params

    params.should eq({} of String => String)
  end

  it "handles conflicting routes by matching static routes first" do
    router = LuckyRouter::Matcher(Symbol).new

    router.add("get", "/users", :index)
    router.add("get", "/:categories", :category_index)

    router.match!("get", "/users").payload.should eq :index
    router.match!("get", "/something").payload.should eq :category_index
  end

  it "handles multiple path variables at the same path level" do
    router = LuckyRouter::Matcher(Symbol).new

    router.add("get", "/users/:user_id/inventory", :index)
    router.add("get", "/users/:id", :show)

    index_match = router.match!("get", "/users/123/inventory")
    index_match.payload.should eq :index
    index_match.params.should eq({"user_id" => "123"})

    show_match = router.match!("get", "/users/123")
    show_match.payload.should eq :show
    show_match.params.should eq({"id" => "123"})
  end

  it "requires globs to be on the end of the path" do
    router = LuckyRouter::Matcher(Symbol).new
    expect_raises LuckyRouter::InvalidPathError do
      router.add("get", "/posts/*/invalid_path", :invalid_path)
    end
  end

  it "allows route globbing" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/posts/something/*", :post_index)

    router.match!("get", "/posts/something").params.should eq({} of String => String)

    router.match!("get", "/posts/something/1").params.should eq({
      "glob" => "1",
    })

    router.match!("get", "/posts/something/1/something/longer").params.should eq({
      "glob" => "1/something/longer",
    })
  end

  it "allows route globbing and optional parts" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/posts/something/?:optional_1/?:optional_2/*:glob_param", :post_index)

    router.match!("get", "/posts/something/1").params.should eq({
      "optional_1" => "1",
    })
    router.match!("get", "/posts/something/1/2").params.should eq({
      "optional_1" => "1",
      "optional_2" => "2",
    })
    router.match!("get", "/posts/something/1/2/3").params.should eq({
      "optional_1" => "1",
      "optional_2" => "2",
      "glob_param" => "3",
    })
    router.match!("get", "/posts/something/1/2/3/4").params.should eq({
      "optional_1" => "1",
      "optional_2" => "2",
      "glob_param" => "3/4",
    })
  end

  it "matches a route with more than 16 segments" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/:z", :match)

    match = router.match!("get", "/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z")
    match.payload.should eq(:match)
    match.params["z"].should eq("z")
  end

  describe "route with trailing slash" do
    context "is defined with a trailing slash" do
      it "should treat it as a index route when called without a trailing slash" do
        router = LuckyRouter::Matcher(Symbol).new
        router.add("get", "/users/", :index)
        router.match!("get", "/users").payload.should eq :index
      end

      it "should treat it as a index route when called with a trailing slash" do
        router = LuckyRouter::Matcher(Symbol).new
        router.add("get", "/users/", :index)
        router.match!("get", "/users/").payload.should eq :index
      end
    end

    context "is defined without a trailing slash" do
      it "should treat it as a index route when called without a trailing slash" do
        router = LuckyRouter::Matcher(Symbol).new
        router.add("get", "/users", :index)
        router.match!("get", "/users").payload.should eq :index
      end

      it "should treat it as a index route when called with a trailing slash" do
        router = LuckyRouter::Matcher(Symbol).new
        router.add("get", "/users", :index)
        router.match!("get", "/users/").payload.should eq :index
      end
    end
  end

  describe "duplicate route checking" do
    it "raises on normal duplicate" do
      router = LuckyRouter::Matcher(Symbol).new
      router.add("get", "/posts/something", :post_index)

      expect_raises LuckyRouter::DuplicateRouteError do
        router.add("get", "/posts/something", :other_post_index)
      end
    end

    it "does not raise on duplicate path with different methods" do
      router = LuckyRouter::Matcher(Symbol).new
      router.add("get", "/posts/something", :post_index)
      router.add("post", "/posts/something", :create_something)
    end

    it "raises even if path variable is different" do
      router = LuckyRouter::Matcher(Symbol).new
      router.add("get", "/posts/:id", :post_show)

      expect_raises LuckyRouter::DuplicateRouteError do
        router.add("get", "/posts/:post_id", :other_post_show)
      end
    end

    it "raises on optional paths when pre-existing path does not have optional part" do
      router = LuckyRouter::Matcher(Symbol).new
      router.add("get", "/posts", :post_index)

      expect_raises LuckyRouter::DuplicateRouteError do
        router.add("get", "/posts/?something", :post_something)
      end
    end

    it "raises on optional paths when pre-existing path has optional part" do
      router = LuckyRouter::Matcher(Symbol).new
      router.add("get", "/posts/something", :post_something)

      expect_raises LuckyRouter::DuplicateRouteError do
        router.add("get", "/posts/?something", :post_something_maybe)
      end
    end

    it "raises on glob routes if path without glob matches pre-existing" do
      router = LuckyRouter::Matcher(Symbol).new
      router.add("get", "/posts", :post_index)

      expect_raises LuckyRouter::DuplicateRouteError do
        router.add("get", "/posts/*", :post_glob)
      end
    end
  end

  it "URI decodes path parts" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get", "/users/:email/tasks", :show)

    router.match!("get", "/users/foo%40example.com/tasks").params.should eq({
      "email" => "foo@example.com",
    })
  end
end
