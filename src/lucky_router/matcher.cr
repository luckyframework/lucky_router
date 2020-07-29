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
  # aliases to help clarify what the @routes has is made of
  alias RoutePartsSize = Int32
  alias HttpMethod = String
  getter root = Fragment(T).new

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
      root.process_parts(parts, "head", payload)
    end

    root.process_parts(parts, method, payload)
  end

  def match(method : String, path_to_match : String) : Match(T)?
    parts_to_match = extract_parts(path_to_match)
    match = root.find(parts_to_match, method)

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
