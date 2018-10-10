class LuckyRouter::Matcher(T)
  getter paths, routes
  alias RoutePartsSize = Int32
  alias HttpMethod = String
  @routes = Hash(HttpMethod, Hash(RoutePartsSize, Fragment(T))).new

  def add(method : String, path : String, payload : T)
    parts = extract_parts(path)
    if method.downcase == "get"
      routes["head"] ||= Hash(RoutePartsSize, Fragment(T)).new
      routes["head"][parts.size] ||= Fragment(T).new
      routes["head"][parts.size].process_parts(parts, payload)
    end
    routes[method] ||= Hash(RoutePartsSize, Fragment(T)).new
    routes[method][parts.size] ||= Fragment(T).new
    routes[method][parts.size].process_parts(parts, payload)
  end

  def match(method : String, path_to_match : String) : Match(T)?
    parts_to_match = extract_parts(path_to_match)
    return if routes[method]?.try(&.[parts_to_match.size]?).nil?
    match = routes[method][parts_to_match.size].find(parts_to_match)

    if match.is_a?(Match)
      match
    end
  end

  def match!(method : String, path_to_match : String) : Match(T)
    match(method, path_to_match) || raise "No matching route found for: #{path_to_match}"
  end

  private def extract_parts(path)
    parts = path.split("/") 
    parts.pop if parts.last.blank?
    parts
  end
end
