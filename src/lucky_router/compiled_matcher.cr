# An opt-in snapshot for applications that finish registering routes before
# serving requests. Recompile after changing the original Matcher or its trie.
# Payload objects themselves are retained, rather than deep-copied.
class LuckyRouter::CompiledMatcher(T)
  @root : Node(T)
  @static_routes = Hash(Tuple(String, String), T).new

  def initialize(root : Fragment(T))
    @root = Node(T).new(root)
    root.each_route do |path_parts, method, payload|
      parts = path_parts[1..]
      next unless payload && parts.none?(&.path_variable?)
      next if parts.any?(&.part.includes?('/'))
      path = parts.map(&.part).join('/')
      # Encoded requests must still use decoded-after-split traversal.
      next if path.includes?('%')
      if parts.empty?
        @static_routes[{method, ""}] = payload
      elsif parts.last.part.empty?
        @static_routes[{method, path + "/"}] = payload
      else
        @static_routes[{method, path}] = payload
        @static_routes[{method, path + "/"}] = payload
      end
    end
  end

  def match(method : String, path : String) : Match(T)?
    if payload = @static_routes[{method, path}]?
      Match(T).new(payload, Hash(String, String).new)
    else
      @root.find_path_match(path, 0, method)
    end
  end

  def match!(method : String, path : String) : Match(T)
    match(method, path) || raise "No matching route found for: #{path}"
  end

  def match_payload(method : String, path : String) : T?
    @static_routes[{method, path}]? || @root.find_path_payload(path, 0, method)
  end

  private class Node(T)
    @prefix : Array(String)?
    @statics : Hash(String, Node(T))?
    @dynamics : Hash(String, Array(Tuple(String, Node(T))))?
    @glob : Tuple(String, Hash(String, T))?
    @payloads : Hash(String, T)
    getter methods : Array(String)

    def initialize(fragment : Fragment(T))
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
        node = Node(T).new(child)
        (@statics ||= Hash(String, Node(T)).new)[literal] = node
        @methods.concat(node.methods)
      end
      fragment.dynamic_parts.each do |child|
        node = Node(T).new(child)
        node.methods.each do |method|
          siblings = (@dynamics ||= Hash(String, Array(Tuple(String, Node(T)))).new)
          (siblings[method] ||= [] of Tuple(String, Node(T))) << {child.path_part.name, node}
        end
        @methods.concat(node.methods)
      end
      if glob = fragment.glob_part
        @glob = {glob.path_part.name, glob.method_to_payload.dup}
        @methods.concat(glob.method_to_payload.keys)
      end
      @methods.uniq!
    end

    {% for captures in [true, false] %}
      def {{ captures ? "find_path_match".id : "find_path_payload".id }}(path : String, offset : Int32, method : String) : {{ captures ? "Match(T)?".id : "T?".id }}
        if prefix = @prefix
          prefix.each do |literal|
            return nil if offset >= path.bytesize
            segment, next_offset, encoded = PathSegment.read(path, offset)
            equal = encoded ? LuckerRouter::PathReader.decode_range(path, offset, segment.length) == literal : segment == literal
            return nil unless equal
            offset = next_offset
          end
        end
        if offset >= path.bytesize
          payload = @payloads[method]?
          {% if captures %}
            return payload ? Match(T).new(payload, Hash(String, String).new) : nil
          {% else %}
            return payload ? payload : nil
          {% end %}
        end

        segment, next_offset, encoded = PathSegment.read(path, offset)
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
          dynamics.each do |name, dynamic|
            if result = dynamic.{{ captures ? "find_path_match".id : "find_path_payload".id }}(path, next_offset, method)
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
              params = Hash(String, String).new
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
