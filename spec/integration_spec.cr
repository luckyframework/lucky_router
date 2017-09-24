require "./spec_helper"

describe LuckyRouter do
  it "handles many routes" do
    router = LuckyRouter::Matcher(Symbol).new

    1000.times do
      router.add("put", "#{(rand * 100).to_i}", :fake_show)
      router.add("get", "#{(rand * 100).to_i}/edit", :fake_edit)
      router.add("get", "#{(rand * 100).to_i}/new/edit", :fake_new_edit)
    end

    router.add("get", "/posts/:id", :post_index)
    router.add("get", "/users", :index)
    router.add("post", "/users", :create)
    router.add("get", "/users/:id", :show)
    router.add("delete", "/users/:id", :delete)
    router.add("put", "/users/:id", :update)
    router.add("get", "/users/:id/edit", :edit)
    router.add("get", "/users/:id/new", :new)

    1000.times do
      router.match!("get", "/posts/1").payload.should eq :post_index
      router.match!("get", "/users").payload.should eq :index
      router.match!("post", "/users").payload.should eq :create
      router.match!("get", "/users/1").payload.should eq :show
      router.match!("delete", "/users/1").payload.should eq :delete
      router.match!("put", "/users/1").payload.should eq :update
      router.match!("get", "/users/1/edit").payload.should eq :edit
      router.match!("get", "/users/1/new").payload.should eq :new
    end
  end

  it "handles root routes" do
    router = LuckyRouter::Matcher(Symbol).new

    router.add("get", "/", :root)

    router.match!("get", "/").payload.should eq :root
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
      "id" => "task_param",
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
end
