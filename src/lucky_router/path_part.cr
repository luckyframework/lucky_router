# A PathPart represents a single section of a path
#
# It can be a static path
#
# ```crystal
# path_part = PathPart.new("users")
# path_part.path_variable? => false
# path_part.optional? => false
# path_part.name => "users"
# ```
#
# It can be a path variable
#
# ```crystal
# path_part = PathPart.new(":id")
# path_part.path_variable? => true
# path_part.optional? => false
# path_part.name => "id"
# ```
#
# It can be optional
#
# ```crystal
# path_part = PathPart.new("?users")
# path_part.path_variable? => false
# path_part.optional? => true
# path_part.name => "users"
# ```
struct LuckyRouter::PathPart
  def self.split_path(path : String) : Array(PathPart)
    parts = path.split('/')
    parts.pop if parts.last.blank?
    parts.map { |part| new(part) }
  end

  getter part : String

  def initialize(@part)
  end

  def name
    name = part.lchop('?').lchop('*').lchop(':')
    unnamed_glob?(name) ? "glob" : name
  end

  def optional?
    part.starts_with?('?')
  end

  def path_variable?
    part.starts_with?(':') || part.starts_with?("?:") || glob?
  end

  def glob?
    part.starts_with?('*')
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
