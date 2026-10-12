# An opt-in snapshot for applications that finish registering routes before
# serving requests. Recompile after changing the original Matcher or its trie.
# Payload objects themselves are retained, rather than deep-copied.
class LuckyRouter::CompiledMatcher(T)
  @root : Node(T)
  @static_routes : Hash(Tuple(String, String), T)?

  def initialize(root : Fragment(T), *, static_index : Bool = true)
    @root = Node(T).new(root)
    if static_index
      routes = Hash(Tuple(String, String), T).new
      @static_routes = routes
      index_static(root, routes)
    end
  end

  private def index_static(fragment : Fragment(T), routes : Hash(Tuple(String, String), T), parts = [] of String) : Nil
    # Use actual static edges, not PathPart metadata: callers can insert
    # fragments under different keys through the public mutable containers.
    unless parts.any? { |part| part.includes?('%') || part.includes?('/') }
      path = parts.join('/')
      fragment.method_to_payload.each do |method, payload|
        next unless payload
        if parts.empty?
          routes[{method, ""}] = payload
        elsif parts.last.empty?
          routes[{method, path + "/"}] = payload
        else
          routes[{method, path}] = payload
          routes[{method, path + "/"}] = payload
        end
      end
    end
    fragment.static_parts.each do |literal, child|
      parts << literal
      index_static(child, routes, parts)
      parts.pop
    end
  end

  def match(method : String, path : String) : Match(T)?
    if routes = @static_routes
      if payload = routes[{method, path}]?
        return Match(T).new(payload, Hash(String, String).new)
      end
    end
    @root.find_path_match(path, 0, method)
  end

  def match!(method : String, path : String) : Match(T)
    match(method, path) || raise "No matching route found for: #{path}"
  end

  def match_payload(method : String, path : String) : T?
    if routes = @static_routes
      if payload = routes[{method, path}]?
        return payload
      end
    end
    @root.find_path_payload(path, 0, method)
  end

  private class Node(T)
    @prefix : Array(String)?
    @statics : Hash(String, Node(T))?
    @dynamics : Hash(String, Array(Tuple(String, Node(T))))?
    @glob : Tuple(String, Hash(String, T), Int32)?
    @payloads : Hash(String, T)
    @capture_capacity : Int32
    getter methods : Array(String)

    def initialize(fragment : Fragment(T), capture_names = [] of String)
      # Small Hashes grow from four entries; reserving the minimum eight
      # entries would waste memory for the common one/two-capture case.
      @capture_capacity = capture_names.size > 8 ? capture_names.size : 0
      # Collapse runs with no terminal, dynamic sibling, or glob. Such nodes
      # cannot affect precedence, and literal comparisons replace hash probes.
      while fragment.method_to_payload.empty? && fragment.dynamic_parts.empty? && fragment.glob_part.nil? && fragment.static_parts.size == 1
        prefix_literal, prefix_child = fragment.static_parts.first
        (@prefix ||= [] of String) << prefix_literal
        fragment = prefix_child
      end
      @payloads = fragment.method_to_payload.dup
      @methods = @payloads.keys
      fragment.static_parts.each do |literal, child|
        node = Node(T).new(child, capture_names)
        (@statics ||= Hash(String, Node(T)).new)[literal] = node
        @methods.concat(node.methods)
      end
      fragment.dynamic_parts.each do |child|
        name = child.path_part.name
        names = capture_names.includes?(name) ? capture_names : capture_names + [name]
        node = Node(T).new(child, names)
        node.methods.each do |method|
          siblings = (@dynamics ||= Hash(String, Array(Tuple(String, Node(T)))).new)
          (siblings[method] ||= [] of Tuple(String, Node(T))) << {child.path_part.name, node}
        end
        @methods.concat(node.methods)
      end
      if glob = fragment.glob_part
        name = glob.path_part.name
        capacity = capture_names.size + (capture_names.includes?(name) ? 0 : 1)
        capacity = 0 if capacity <= 8
        @glob = {name, glob.method_to_payload.dup, capacity}
        @methods.concat(glob.method_to_payload.keys)
      end
      @methods.uniq!
    end

    {% for captures in [true, false] %}
      def {{ captures ? "find_path_match".id : "find_path_payload".id }}(path : String, offset : Int32, method : String, segment_data : Tuple(PathSegment, Int32, Bool)? = nil) : {{ captures ? "Match(T)?".id : "T?".id }}
        if prefix = @prefix
          prefix.each do |literal|
            return nil if offset >= path.bytesize
            segment, next_offset, encoded = segment_data || PathSegment.read(path, offset)
            equal = encoded ? LuckerRouter::PathReader.decode_range(path, offset, segment.length) == literal : segment == literal
            return nil unless equal
            offset = next_offset
            segment_data = nil
          end
        end
        if offset >= path.bytesize
          payload = @payloads[method]?
          {% if captures %}
            return payload ? Match(T).new(payload, Hash(String, String).new(initial_capacity: @capture_capacity)) : nil
          {% else %}
            return payload ? payload : nil
          {% end %}
        end

        segment, next_offset, encoded = segment_data || PathSegment.read(path, offset)
        decoded = nil
        if statics = @statics
          decoded = LuckerRouter::PathReader.decode_range(path, offset, segment.length) if encoded
          static = decoded ? statics[decoded]? : statics[segment]?
          if static
            if result = static.{{ captures ? "find_path_match".id : "find_path_payload".id }}(path, next_offset, method)
              return result
            end
          end
        end
        if dynamics = @dynamics.try(&.[method]?)
          child_data = dynamics.size > 1 && next_offset < path.bytesize ? PathSegment.read(path, next_offset) : nil
          dynamics.each do |name, dynamic|
            if result = dynamic.{{ captures ? "find_path_match".id : "find_path_payload".id }}(path, next_offset, method, child_data)
              {% if captures %}
                result.params[name] = decoded || (encoded ? LuckerRouter::PathReader.decode_range(path, offset, segment.length) : segment.value)
              {% end %}
              return result
            end
          end
        end
        if glob = @glob
          payload = glob[1][method]?
          if payload
            {% if captures %}
              params = Hash(String, String).new(initial_capacity: glob[2])
              params[glob[0]] = PathSegment.glob_value(path, offset)
              return Match(T).new(payload, params)
            {% else %}
              return payload
            {% end %}
          end
        end
        nil
      end
    {% end %}
  end
end
