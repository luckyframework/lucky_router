class LuckyRouter::Matcher(T)
  getter paths, routes
  alias RoutePartsSize = Int32
  alias HttpMethod = String
  @routes = Hash(HttpMethod, Hash(RoutePartsSize, Fragment(T))).new

  def add(method : String, path : String, payload : T)
    parts = path.gsub(/^\//, "").split("/")

    routes[method] ||= Hash(RoutePartsSize, Fragment(T)).new
    routes[method][parts.size] ||= Fragment(T).new
    routes[method][parts.size].process_parts(parts, payload)
  end

  def match(method : String, path_to_match : String) : Match(T)?
    parts_to_match = path_to_match.gsub(/^\//, "").split("/")
    return if routes[method]?.try(&.[parts_to_match.size]?).nil?
    match = routes[method][parts_to_match.size].find(parts_to_match)

    if match.is_a?(Match)
      match
    end
  end

  def match!(method : String, path_to_match : String) : Match(T)
    match(method, path_to_match) || raise "No matching route found for: #{path_to_match}"
  end
end
