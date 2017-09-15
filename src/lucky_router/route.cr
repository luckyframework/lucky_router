struct LuckyRouter::Route(T)
  getter path, payload
  @path_parts : Array(String)?
  @named_parts_with_indices : Hash(Int32, String)?

  def initialize(@path : String, @payload : T)
  end

  def match?(parts_to_match : Array(String))
    all_parts_match?(parts_to_match) && parts_to_match.size == path_parts.size
  end

  def path_parts
    @path_parts ||= path.split("/")
  end

  private def all_parts_match?(parts_to_match)
    parts_to_match.each_with_index.all? do |part, index|
      path_part = path_parts[index]?
      path_part == part || path_part.try(&.starts_with?(":"))
    end
  end

  def named_parts_with_indices
    @named_parts_with_indices ||= path_parts.each_with_index.reduce({} of Int32 => String) do |named_part_hash, (part, index)|
      named_part_hash[index] = part.gsub(":", "") if part.starts_with?(":")
      named_part_hash
    end
  end
end
