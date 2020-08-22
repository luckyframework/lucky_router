require "./spec_helper"

describe LuckyRouter::Fragment do
  it "adds parts successfully" do
    fragment = build_fragment

    fragment.process_parts(build_path_parts("users", ":id"), "get", :show)

    users_fragment = fragment.static_parts[LuckyRouter::PathPart.new("users")]
    users_fragment.dynamic_part.should_not be_nil
  end

  it "static parts after dynamic parts do not overwrite each other" do
    fragment = build_fragment

    fragment.process_parts(build_path_parts("users", ":id", "edit"), "get", :edit)
    fragment.process_parts(build_path_parts("users", ":id", "new"), "get", :new)

    users_fragment = fragment.static_parts[LuckyRouter::PathPart.new("users")]
    id_fragment = users_fragment.dynamic_part.not_nil!
    id_fragment.static_parts[LuckyRouter::PathPart.new("edit")].should_not be_nil
    id_fragment.static_parts[LuckyRouter::PathPart.new("new")].should_not be_nil
  end
end

private def build_path_parts(*path_parts) : Array(LuckyRouter::PathPart)
  path_parts.map { |part| LuckyRouter::PathPart.new(part) }.to_a
end

private def build_fragment
  LuckyRouter::Fragment(Symbol).new(path_part: LuckyRouter::PathPart.new(""))
end
