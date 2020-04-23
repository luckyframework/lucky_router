class LuckyRouter::Matcher(T)
  getter paths, routes
  alias RoutePartsSize = Int32
  alias HttpMethod = String
  @routes = Hash(HttpMethod, Hash(RoutePartsSize, Fragment(T))).new

  def add(method : String, path : String, payload : T)
    all_path_parts = path.split("/")
    optional_parts = [] of String
    all_path_parts.each do |part|
      if part.starts_with?("?")
        optional_parts << part.gsub("?", "")
      end
    end

    path_without_optional_params = all_path_parts.reject(&.starts_with?("?")).join("/")

    process_and_add_path(method, path_without_optional_params, payload)
    optional_parts.each do |optional_part|
      path_without_optional_params += "/#{optional_part}"
      process_and_add_path(method, path_without_optional_params, payload)
    end
  end

  private def process_and_add_path(method : String, path : String, payload : T)
    parts = extract_parts(path)
    if method.downcase == "get"
      add_route("head", parts, payload)
    end

    add_route(method, parts, payload)
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

  private def add_route(method : String, parts : Array(String), payload : T)
    routes[method] ||= Hash(RoutePartsSize, Fragment(T)).new
    routes[method][parts.size] ||= Fragment(T).new
    routes[method][parts.size].process_parts(parts, payload)
  end
end
