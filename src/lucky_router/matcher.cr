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
    glob_part = nil
    if last_part = all_path_parts.last?
      glob_part = all_path_parts.pop if last_part.glob?
    end

    # Optional parts stay where they are in the path and are added one after
    # another, so "/users/?:user_id/tasks" matches "/users/tasks" and
    # "/users/1/tasks"
    normalized_method = method.downcase
    optional_count = all_path_parts.count(&.optional?)
    if optional_count.zero?
      process_and_add_path(method, normalized_method, all_path_parts, payload, path)
    else
      (0..optional_count).each do |count|
        included = 0
        parts = Array(PathPart).new(all_path_parts.size)
        all_path_parts.each do |part|
          if part.optional?
            included += 1
            next if included > count
          end
          parts << part
        end
        process_and_add_path(method, normalized_method, parts, payload, path)
      end
    end
    if glob_part
      all_path_parts << glob_part
      process_and_add_path(method, normalized_method, all_path_parts, payload, path)
    end
  end

  # Array of the path, method, and payload
  def list_routes : Array(Tuple(String, String, T))
    routes = [] of Tuple(String, String, T)
    root.each_route do |parts, method, payload|
      path = String.build do |io|
        io << '/'
        first = true
        parts.each do |part|
          next if part.part.presence.nil?
          io << '/' unless first
          io << part.part
          first = false
        end
      end
      routes << {path, method, payload}
    end
    routes
  end

  private def process_and_add_path(method : String, normalized_method : String, parts : Array(PathPart), payload : T, path : String)
    if normalized_method == "get"
      root.process_parts(parts, "head", payload)
    end

    duplicate_check(method, normalized_method, parts, path)

    root.process_parts(parts, method, payload)
  end

  private def duplicate_check(method : String, normalized_method : String, parts : Array(PathPart), path : String)
    normalized_path = String.build do |io|
      io << normalized_method
      PathNormalizer.write(io, parts)
    end
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
    root.find_path_match(path_to_match, 0, method)
  end

  # Match without constructing a parameter hash or copying captured strings.
  def match_payload(method : String, path_to_match : String) : T?
    root.find_path_payload(path_to_match, 0, method)
  end

  # Freeze the current routing structure for optional static indexing and
  # compact traversal. Later mutations require creating another snapshot.
  def compile : CompiledMatcher(T)
    CompiledMatcher(T).new(root)
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
