require "./spec_helper"

describe LuckyRouter::Matcher::Fragment do
  it "adds parts successfully" do
    fragment = build_fragment

    fragment.process_parts(["users", ":id"])

    users_fragment = fragment.static_parts["users"]
    users_fragment.dynamic_part.should_not be_nil
  end
end

private def build_fragment
  LuckyRouter::Matcher::Fragment(Symbol).new(:foo)
end
