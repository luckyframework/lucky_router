class LuckyRouter::Fragment(T)
  # Generate both walks so the payload-only API does no capture work. Route
  # precedence and the live, publicly mutable trie are shared by both APIs.
  {% for captures in [true, false] %}
    def {{ captures ? "find_path_match".id : "find_path_payload".id }}(path : String, offset : Int32, method : String, segment_data : Tuple(PathSegment, Int32, Bool)? = nil) : {{ captures ? "Match(T)?".id : "T?".id }}
      if offset >= path.bytesize
        {% if captures %}
          return match_for_method(method)
        {% else %}
          payload = payload_for_method(method)
          return payload ? payload : nil
        {% end %}
      end

      segment, next_offset, encoded = segment_data || PathSegment.read(path, offset)
      decoded = encoded && @static_parts.try { |parts| !parts.empty? } ? LuckerRouter::PathReader.decode_range(path, offset, segment.length) : nil
      static = if statics = @static_parts
                 decoded ? statics[decoded]? : statics[segment]?
               end
      if static
        if result = static.{{ captures ? "find_path_match".id : "find_path_payload".id }}(path, next_offset, method)
          return result
        end
      end

      if dynamics = @dynamic_parts
        # Siblings consume the same next segment. Parse it once when branching,
        # retaining borrowed bytes instead of allocating a segment cache.
        child_data = dynamics.size > 1 && next_offset < path.bytesize ? PathSegment.read(path, next_offset) : nil
        dynamics.each do |dynamic|
          if result = dynamic.{{ captures ? "find_path_match".id : "find_path_payload".id }}(path, next_offset, method, child_data)
            {% if captures %}
              result.params[dynamic.path_part.name] = decoded || (encoded ? LuckerRouter::PathReader.decode_range(path, offset, segment.length) : segment.value)
            {% end %}
            return result
          end
        end
      end

      if glob = glob_part
        {% if captures %}
          if result = glob.match_for_method(method)
            result.params[glob.path_part.name] = PathSegment.glob_value(path, offset)
            return result
          end
        {% else %}
          payload = glob.payload_for_method(method)
          return payload ? payload : nil
        {% end %}
      end
      nil
    end
  {% end %}
end
