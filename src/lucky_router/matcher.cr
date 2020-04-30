# Add routes and match routes
#
# 'T' is the type of the 'payload'. The 'payload' is what will be returned
# if the route matches.
#
# ## Example
#
# ```crystal
# # 'T' will be 'Symbol'
# router = LuckyRouter::Matcher(Symbol).new
#
# # Tell the router what payload to return if matched
# router.add("get", "/users", :index)
#
# # This will return :index
# router.match("get", "/users").payload # :index
# ```
class LuckyRouter::Matcher(T)
  getter routes, glob_routes
  alias RoutePartsSize = Int32
  alias HttpMethod = String

  # The matcher stores routes based on the HTTP method and the number of
  # "parts" in the path
  #
  # Each section in between the path is a "part". We use the method and part size
  # to both speed up the route lookup and makes it more reliable because the router
  # always tries to find routes that are the right size.
  #
  # Each route key is a `Fragment(T)`. Where `T` is the type of the payload. See
  # `Fragment` for details on how it works
  #
  # ## Example
  #
  # ```
  # router = LuckyRouter::Matcher(Symbol).new
  # router.add("get", "/users/:user_id", :index)
  #
  # # Will make @routes look like:

  # {
  #   "get" => {
  #     2 => Fragment(T) # The fragment for this route
  #   }
  # }
  # ```
  #
  # So if trying to match "/users/1/foo" it will not even try because the parts
  # size does not match any of the known routes.
  @routes = Hash(HttpMethod, Hash(RoutePartsSize, Fragment(T))).new
  @glob_routes = Hash(HttpMethod, Hash(RoutePartsSize, Fragment(T))).new

  def add(method : String, path : String, payload : T)
    all_path_parts = path.split("/").reject(&.blank?)
    last_part = all_path_parts.last?
    if last_part && last_part.starts_with?("*")
      process_and_add_path(method, all_path_parts[0..-2].join("/"), payload)
      process_and_add_path(method, all_path_parts[0..-2].join("/"), payload, to: @glob_routes)
    end

    all_path_parts = path.split("/").reject(&.starts_with?("*"))
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

  private def process_and_add_path(method : String, path : String, payload : T, to route_hash = @routes)
    parts = extract_parts(path)
    if method.downcase == "get"
      add_route("head", parts, payload, route_hash)
    end

    add_route(method, parts, payload, route_hash)
  end

  private def add_route(method : String, parts : Array(String), payload : T, route_hash = @routes)
    route_hash[method] ||= Hash(RoutePartsSize, Fragment(T)).new
    route_hash[method][parts.size] ||= Fragment(T).new
    route_hash[method][parts.size].process_parts(parts, payload)
  end

  def match(method : String, path_to_match : String) : Match(T)?
    parts_to_match = extract_parts(path_to_match)
    match_against(routes, method, parts_to_match) || match_against_globs(method, parts_to_match)
  end

  private def match_against_globs(method, parts_to_match) : Match(T)?
    parts_to_match = parts_to_match.reject(&.empty?)
    parts_size = parts_to_match.size
    parts_size.times do |i|
      i += 1
      parts = parts_to_match[0..(parts_size - i - 1)]
      glob_value = parts_to_match.skip(parts_size - i).join("/")
      possible_match = match_against(glob_routes, method, parts)
      if possible_match.is_a?(Match)
        possible_match.params["glob"] = glob_value
        break possible_match
      else
        nil
      end
    end
  end

  private def match_against(route_hash, method, parts_to_match)
    return if route_hash[method]?.try(&.[parts_to_match.size]?).nil?
    match = route_hash[method][parts_to_match.size].find(parts_to_match)

    if match.is_a?(Match)
      match
    end
  end

  def match!(method : String, path_to_match : String) : Match(T)
    match(method, path_to_match) || raise "No matching route found for: #{method.upcase} #{path_to_match}"
  end

  private def extract_parts(path)
    parts = path.split("/")
    parts.pop if parts.last.blank?
    parts
  end
end
