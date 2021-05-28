require "./spec_helper"

describe LuckyRouter::PathPart do
  describe ".split_path" do
    it "returns an array of path parts" do
      path_parts = LuckyRouter::PathPart.split_path("/users/:id")

      path_parts.size.should eq 3
      path_parts[0].part.should eq ""
      path_parts[1].part.should eq "users"
      path_parts[2].part.should eq ":id"
    end

    it "ignores trailing slashes" do
      path_parts = LuckyRouter::PathPart.split_path("/users/")

      path_parts.size.should eq 2
      path_parts[0].part.should eq ""
      path_parts[1].part.should eq "users"
    end

    it "decodes path parts" do
      path_parts = LuckyRouter::PathPart.split_path("/users/foo%40example.com")

      path_parts.size.should eq 3
      path_parts[0].part.should eq ""
      path_parts[1].part.should eq "users"
      path_parts[2].part.should eq "foo@example.com"
    end
  end

  describe "#path_variable?" do
    it "is true if it starts with colon" do
      path_part = LuckyRouter::PathPart.new(":id")

      path_part.path_variable?.should be_truthy
    end

    it "is false if it does not start with a colon" do
      path_part = LuckyRouter::PathPart.new("users")

      path_part.path_variable?.should be_falsey
    end

    it "is true if it is an optional path variable" do
      path_part = LuckyRouter::PathPart.new("?:id")

      path_part.path_variable?.should be_truthy
    end

    it "is true if it is a glob path variable" do
      path_part = LuckyRouter::PathPart.new("*:id")

      path_part.path_variable?.should be_truthy
    end

    it "is true if it is just a glob so that it will be assigned correctly" do
      path_part = LuckyRouter::PathPart.new("*")

      path_part.path_variable?.should be_truthy
    end
  end

  describe "#optional?" do
    it "is true if it starts with a question mark" do
      path_part = LuckyRouter::PathPart.new("?users")

      path_part.optional?.should be_truthy
    end

    it "is false if it does not start with question mark" do
      path_part = LuckyRouter::PathPart.new("users")

      path_part.optional?.should be_falsey
    end
  end

  describe "#glob?" do
    it "is true if starts with asterisk" do
      path_part = LuckyRouter::PathPart.new("*")

      path_part.glob?.should be_truthy
    end

    it "is false if does not start with asterisk" do
      path_part = LuckyRouter::PathPart.new("users")

      path_part.glob?.should be_falsey
    end
  end

  describe "#name" do
    it "returns part if part is not path variable" do
      path_part = LuckyRouter::PathPart.new("users")

      path_part.name.should eq "users"
    end

    it "returns path variable name if path variable" do
      path_part = LuckyRouter::PathPart.new(":id")

      path_part.name.should eq "id"
    end

    it "handles optional path parts" do
      path_part = LuckyRouter::PathPart.new("?users")

      path_part.name.should eq "users"
    end

    it "handles optional path variables" do
      path_part = LuckyRouter::PathPart.new("?:id")

      path_part.name.should eq "id"
    end

    it "handles glob path variables" do
      path_part = LuckyRouter::PathPart.new("*:id")

      path_part.name.should eq "id"
    end

    it "is glob if glob without path variable name" do
      path_part = LuckyRouter::PathPart.new("*")

      path_part.name.should eq "glob"
    end
  end

  describe "equality" do
    it "is equal to another path part if their part is the same" do
      part_a = LuckyRouter::PathPart.new("users")
      part_b = LuckyRouter::PathPart.new("users")

      part_a.should eq part_b
      part_a.hash.should eq part_b.hash
    end

    it "is not equal to another path part if their part is different" do
      part_a = LuckyRouter::PathPart.new("users")
      part_b = LuckyRouter::PathPart.new(":users")

      part_a.should_not eq part_b
      part_a.hash.should_not eq part_b.hash
    end
  end

  describe "#validate!" do
    it "does nothing if path part is valid" do
      part = LuckyRouter::PathPart.new("users")

      part.validate!
    end

    it "raises error if glob named incorrectly" do
      part = LuckyRouter::PathPart.new("*users")

      expect_raises(LuckyRouter::InvalidGlobError) do
        part.validate!
      end
    end
  end
end
