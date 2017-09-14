class LuckyRouter::Matcher(T)
  private getter paths
  @routes : Array(Route(T))?

  def initialize
    @paths = {} of String => T
  end

  def add(path : String, payload : T)
    paths[path] = payload
  end

  def match!(path_to_match : String)
    parts_to_match = path_to_match.split("/")
    if route = routes.find(&.match?(parts_to_match))
      route
    else
      raise "No matching route found for: #{path_to_match}"
    end
  end

  private def routes
    @routes ||= begin
      paths.map do |path, payload|
        Route(T).new(path, payload)
      end
    end
  end

  struct Route(T)
    getter path, payload
    @path_parts : Array(String)?

    def initialize(@path : String, @payload : T)
    end

    def match?(parts_to_match : Array(String))
      all_parts_match?(parts_to_match) && parts_to_match.size == path_parts.size
    end

    private def path_parts
      @path_parts ||= path.split("/")
    end

    private def all_parts_match?(parts_to_match)
      parts_to_match.each_with_index.all? do |part, index|
        path_part = path_parts[index]?
        path_part == part || path_part.try(&.starts_with?(":"))
      end
    end
  end
end
