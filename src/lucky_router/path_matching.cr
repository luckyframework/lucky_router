class LuckyRouter::Fragment(T)
  # Generate both walks so the payload-only API does no capture work. Route
  # precedence and the live, publicly mutable trie are shared by both APIs.
  {% for captures in [true, false] %}
    @[AlwaysInline]
    def {{ captures ? "find_path_match".id : "find_path_payload".id }}(path : String, offset : Int32, method : String) : {{ captures ? "Match(T)?".id : "T?".id }}
      if offset >= path.bytesize
        {% if captures %}
          return match_for_method(method)
        {% else %}
          payload = payload_for_method(method)
          return payload ? payload : nil
        {% end %}
      end

      segment, next_offset, encoded = PathSegment.read(path, offset)
      {{ captures ? "find_segment_match".id : "find_segment_payload".id }}(segment, next_offset, encoded, method)
    end

    protected def {{ captures ? "find_segment_match".id : "find_segment_payload".id }}(segment : PathSegment, next_offset : Int32, encoded : Bool, method : String) : {{ captures ? "Match(T)?".id : "T?".id }}
      path = segment.path
      offset = segment.offset
      decoded = encoded && @static_parts.try { |parts| !parts.empty? } ? LuckerRouter::PathReader.decode_range(path, offset, segment.length) : nil
      static = if statics = @static_parts
                 if statics.size == 1
                   literal = statics.first_key
                   equal = decoded ? decoded == literal : segment == literal
                   statics.first_value if equal
                 else
                   decoded ? statics[decoded]? : statics[segment]?
                 end
               end
      if static
        if result = static.{{ captures ? "find_path_match".id : "find_path_payload".id }}(path, next_offset, method)
          return result
        end
      end

      if dynamics = @dynamic_parts
        # Siblings consume the same next segment. Parse it once when branching,
        # retaining borrowed bytes instead of allocating a segment cache.
        child_data = next_offset < path.bytesize ? PathSegment.read(path, next_offset) : nil
        dynamics.each do |dynamic|
          result = if child_data
                     dynamic.{{ captures ? "find_segment_match".id : "find_segment_payload".id }}(child_data[0], child_data[1], child_data[2], method)
                   else
                     {% if captures %}
                       dynamic.match_for_method(method)
                     {% else %}
                       payload = dynamic.payload_for_method(method)
                       payload ? payload : nil
                     {% end %}
                   end
          if result
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
