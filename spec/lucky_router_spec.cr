require "./spec_helper"

describe LuckyRouter do
  it "handles many routes" do
    router = LuckyRouter::Matcher(Symbol).new

    router.add("get/users", :index)
    router.add("post/users", :create)
    router.add("get/users/:id", :show)
    router.add("delete/users/:id", :delete)
    router.add("put/users/:id", :update)
    router.add("get/users/:id/edit", :edit)
    router.add("get/users/:id/new", :new)

    router.match!("get/users").payload.should eq :index
    router.match!("post/users").payload.should eq :create
    router.match!("get/users/1").payload.should eq :show
    router.match!("delete/users/1").payload.should eq :delete
    router.match!("put/users/1").payload.should eq :update
    router.match!("get/users/1/edit").payload.should eq :edit
    router.match!("get/users/1/new").payload.should eq :new
  end

  it "gets params" do
    router = LuckyRouter::Matcher(Symbol).new
    router.add("get/users/:user_id/tasks/:id", :show)

    router.match!("get/users/user_param/tasks/task_param").params.should eq({
      "user_id" => "user_param",
      "id" => "task_param",
    })
  end

  pending "handles conflicting routes" do
    router = LuckyRouter::Matcher(Symbol).new

    # This fails right now
    # Maybe solution is to order the routes based on where the named parts are?
    router.add("get/users", :index)
    router.add("get/:categories", :category_index)

    router.add("post/users", :index)
    router.match!("get/users").payload.should eq :category_index
    router.match!("get/something").payload.should eq :category_index
  end
end
