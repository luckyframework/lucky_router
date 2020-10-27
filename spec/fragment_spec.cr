require "./spec_helper"

describe LuckyRouter::Fragment do
  it "adds parts successfully" do
    fragment = build_fragment

    fragment.process_parts(build_path_parts("users", ":id"), "get", :show)

    users_fragment = fragment.static_parts["users"]
    users_fragment.dynamic_parts.should_not be_empty
  end

  it "static parts after dynamic parts do not overwrite each other" do
    fragment = build_fragment

    fragment.process_parts(build_path_parts("users", ":id", "edit"), "get", :edit)
    fragment.process_parts(build_path_parts("users", ":id", "new"), "get", :new)

    users_fragment = fragment.static_parts["users"]
    id_fragment = users_fragment.dynamic_parts.first
    id_fragment.static_parts["edit"].should_not be_nil
    id_fragment.static_parts["new"].should_not be_nil
  end
end

private def build_path_parts(*path_parts) : Array(LuckyRouter::PathPart)
  path_parts.map { |part| LuckyRouter::PathPart.new(part) }.to_a
end

private def build_fragment
  LuckyRouter::Fragment(Symbol).new(path_part: LuckyRouter::PathPart.new(""))
end
