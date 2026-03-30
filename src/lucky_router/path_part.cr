# A PathPart represents a single section of a path
#
# It can be a static path
#
# ```
# path_part = PathPart.new("users")
# path_part.path_variable? => false
# path_part.optional? => false
# path_part.name => "users"
# ```
#
# It can be a path variable
#
# ```
# path_part = PathPart.new(":id")
# path_part.path_variable? => true
# path_part.optional? => false
# path_part.name => "id"
# ```
#
# It can be optional
#
# ```
# path_part = PathPart.new("?users")
# path_part.path_variable? => false
# path_part.optional? => true
# path_part.name => "users"
# ```
struct LuckyRouter::PathPart
  def self.split_path(path : String) : Array(PathPart)
    parts = LuckerRouter::PathReader.new(path)
    parts.map { |part| new(part) }.to_a
  end

  getter part : String

  def initialize(@part)
  end

  def name : String
    name = part.lchop('?').lchop('*').lchop(':')
    unnamed_glob?(name) ? "glob" : name
  end

  def optional? : Bool
    part.starts_with?('?')
  end

  def path_variable? : Bool
    part.starts_with?(':') || part.starts_with?("?:") || glob?
  end

  def glob? : Bool
    part.starts_with?('*')
  end

  def path_variable_prefixed? : Bool
    return false if path_variable? || glob?

    bare = optional? ? part[1..] : part
    (index = bare.index(':')) ? index > 0 : false
  end

  def prefix : String
    bare = optional? ? part[1..] : part
    bare[0...bare.index!(':')]
  end

  def variable_name : String
    bare = optional? ? part[1..] : part
    bare[(bare.index!(':').succ)..]
  end

  def validate!
    raise InvalidGlobError.new(part) if invalid_glob?
  end

  private def unnamed_glob?(name)
    name.blank? && glob?
  end

  private def invalid_glob?
    return false unless glob?

    part.size != 1 && part != "*:#{name}"
  end
end
