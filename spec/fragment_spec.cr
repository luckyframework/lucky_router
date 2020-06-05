require "./spec_helper"

describe LuckyRouter::Fragment do
  it "adds parts successfully" do
    fragment = build_fragment

    fragment.process_parts(["users", ":id"], :show, "get")

    users_fragment = fragment.static_parts["users"]
    users_fragment.dynamic_part.should_not be_nil
  end

  it "static parts after dynamic parts do not overwrite each other" do
    fragment = build_fragment

    fragment.process_parts(["users", ":id", "edit"], :edit, "get")
    fragment.process_parts(["users", ":id", "new"], :new, "get")

    users_fragment = fragment.static_parts["users"]
    id_fragment = users_fragment.dynamic_part.not_nil!.fragment
    id_fragment.static_parts["edit"].should_not be_nil
    id_fragment.static_parts["new"].should_not be_nil
  end
end

private def build_fragment
  LuckyRouter::Fragment(Symbol).new
end
