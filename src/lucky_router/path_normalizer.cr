class LuckyRouter::PathNormalizer
  DEFAULT_PATH_VARIABLE_NAME = ":path_variable"

  def self.normalize(path_parts : Array(PathPart)) : String
    String.build do |io|
      write(io, path_parts)
    end
  end

  def self.write(io : IO, path_parts : Array(PathPart)) : Nil
    path_parts.each_with_index do |part, index|
      io << '/' unless index.zero?
      io << normalize(part)
    end
  end

  private def self.normalize(path_part : PathPart) : String
    path_part.path_variable? ? DEFAULT_PATH_VARIABLE_NAME : path_part.name
  end
end
