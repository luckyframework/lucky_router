class LuckyRouter::PathNormalizer
  DEFAULT_PATH_VARIABLE_NAME = ":path_variable"

  def self.normalize(path_parts : Array(PathPart)) : String
    path_parts.map { |path_part| normalize(path_part) }.join('/')
  end

  private def self.normalize(path_part : PathPart) : String
    path_part.path_variable? ? DEFAULT_PATH_VARIABLE_NAME : path_part.name
  end
end
