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
      MatchedRoute.new(route, parts_to_match)
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

  class MatchedRoute(T)
    private getter route, parts_to_match

    def initialize(@route : Route(T), @parts_to_match : Array(String))
    end

    def payload
      route.payload
    end

    def params : Hash(String, String)
      params_hash = {} of String => String
      route.named_parts_with_indices.each do |index, part_name|
        params_hash[part_name] = parts_to_match[index]
      end
      params_hash
    end
  end

  struct Route(T)
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
end
