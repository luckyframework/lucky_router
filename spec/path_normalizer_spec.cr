require "./spec_helper"

describe LuckyRouter::PathNormalizer do
  describe ".normalize" do
    it "turns regular path parts into slash delimitted string" do
      path_parts = LuckyRouter::PathPart.split_path("/api/v1/users")

      result = LuckyRouter::PathNormalizer.normalize(path_parts)

      result.should eq("/api/v1/users")
    end

    it "gives path variables a generic name" do
      path_parts = LuckyRouter::PathPart.split_path("/users/:id")

      result = LuckyRouter::PathNormalizer.normalize(path_parts)

      result.should eq("/users/:path_variable")
    end

    it "removes question mark from optional path" do
      path_parts = LuckyRouter::PathPart.split_path("/users/?name")

      result = LuckyRouter::PathNormalizer.normalize(path_parts)

      result.should eq("/users/name")
    end

    it "removes question mark and gives generic name to optional path variables" do
      path_parts = LuckyRouter::PathPart.split_path("/users/?:name")

      result = LuckyRouter::PathNormalizer.normalize(path_parts)

      result.should eq("/users/:path_variable")
    end
  end
end
