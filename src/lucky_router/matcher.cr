# Add routes and match routes
#
# 'T' is the type of the 'payload'. The 'payload' is what will be returned
# if the route matches.
#
# ## Example
#
# ```
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
  # starting point from which all fragments are located
  getter root = Fragment(T).new(path_part: PathPart.new(""))
  getter normalized_paths = Hash(String, String).new

  def add(method : String, path : String, payload : T)
    all_path_parts = PathPart.split_path(path)
    validate!(path, all_path_parts)
    optional_parts = all_path_parts.select(&.optional?)
    glob_part = nil
    if last_part = all_path_parts.last?
      glob_part = all_path_parts.pop if last_part.glob?
    end

    path_without_optional_params = all_path_parts.reject(&.optional?)

    process_and_add_path(method, path_without_optional_params, payload, path)
    optional_parts.each do |optional_part|
      path_without_optional_params << optional_part
      process_and_add_path(method, path_without_optional_params, payload, path)
    end
    if glob_part
      path_without_optional_params << glob_part
      process_and_add_path(method, path_without_optional_params, payload, path)
    end
  end

  private def process_and_add_path(method : String, parts : Array(PathPart), payload : T, path : String)
    if method.downcase == "get"
      root.process_parts(parts, "head", payload)
    end

    duplicate_check(method, parts, path)

    root.process_parts(parts, method, payload)
  end

  private def duplicate_check(method : String, parts : Array(PathPart), path : String)
    normalized_path = method.downcase + PathNormalizer.normalize(parts)
    if duplicated_path = normalized_paths[normalized_path]?
      raise DuplicateRouteError.new(
        method,
        new_path: path,
        duplicated_path: duplicated_path
      )
    end
    normalized_paths[normalized_path] = path
  end

  def match(method : String, path_to_match : String) : Match(T)?
    # To avoid allocating an array for the segment parts, we use a static
    # array with up to 16 segments.
    parts_static_array = StaticArray(String, 16).new("")

    # In the general case we still have to support more than 16 segments.
    # We'll fallback to using an Array for that case.
    parts_array = nil

    index = 0
    LuckerRouter::PathReader.new(path_to_match).each do |part|
      if index == parts_static_array.size
        # We don't have any more space in the static array:
        # more contents to the array.
        parts_array = Array(String).new(32)
        parts_array.concat(parts_static_array)
        parts_array << part
      elsif parts_array
        # We are using the fallback array, so push parts there.
        parts_array << part
      else
        # We are still using the static array
        parts_static_array[index] = part
      end
      index += 1
    end

    match =
      if parts_array
        root.find(parts_array, method)
      else
        root.find(parts_static_array.to_slice[0...index], method)
      end

    if match.is_a?(Match)
      match
    end
  end

  def match!(method : String, path_to_match : String) : Match(T)
    match(method, path_to_match) || raise "No matching route found for: #{path_to_match}"
  end

  private def validate!(path : String, parts : Array(PathPart))
    last_index = parts.size - 1
    parts.each_with_index do |part, idx|
      if part.glob? && idx != last_index
        raise InvalidPathError.new("`#{path}` must only contain a glob at the end")
      end
      part.validate!
    end
  end
end
