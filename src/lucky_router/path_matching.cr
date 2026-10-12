class LuckyRouter::Fragment(T)
  # Looks up the static child for a borrowed segment. `decoded` is only
  # materialized when the path is percent-encoded and this level has statics.
  @[AlwaysInline]
  protected def self.static_child(statics : Hash(String, Fragment(T)), segment : PathSegment, decoded : String?) : Fragment(T)?
    if statics.size == 1
      literal = statics.first_key
      equal = decoded ? decoded == literal : segment == literal
      statics.first_value if equal
    else
      decoded ? statics[decoded]? : statics[segment]?
    end
  end

  # Generate both walks so the payload-only API does no capture work. Route
  # precedence and the live, publicly mutable trie are shared by both APIs.
  {% for captures in [true, false] %}
    {% find_path = captures ? "find_path_match".id : "find_path_payload".id %}
    {% find_segment = captures ? "find_segment_match".id : "find_segment_payload".id %}
    {% terminal = captures ? "match_for_method".id : "payload_match_for_method".id %}
    {% result = captures ? "Match(T)?".id : "T?".id %}

    # Follows static-only levels in a loop: when a level has no dynamic
    # siblings and no glob, a static mismatch is a miss, so no frame is
    # needed to backtrack. Levels that could backtrack use the recursive walk.
    def {{ find_path }}(path : String, offset : Int32, method : String) : {{ result }}
      fragment = self
      while true
        return fragment.{{ terminal }}(method) if offset >= path.bytesize

        segment, next_offset, encoded = PathSegment.read(path, offset)
        dynamics = fragment.dynamic_parts?
        if (dynamics && !dynamics.empty?) || fragment.glob_part
          return fragment.{{ find_segment }}(segment, next_offset, encoded, method)
        end

        statics = fragment.static_parts?
        return nil unless statics

        decoded = encoded ? LuckerRouter::PathReader.decode_range(path, offset, segment.length) : nil
        static = Fragment(T).static_child(statics, segment, decoded)
        return nil unless static

        fragment = static
        offset = next_offset
      end
    end

    protected def {{ find_segment }}(segment : PathSegment, next_offset : Int32, encoded : Bool, method : String) : {{ result }}
      path = segment.path
      offset = segment.offset
      decoded = nil
      if statics = @static_parts
        decoded = LuckerRouter::PathReader.decode_range(path, offset, segment.length) if encoded && !statics.empty?
        if static = Fragment(T).static_child(statics, segment, decoded)
          if result = static.{{ find_path }}(path, next_offset, method)
            return result
          end
        end
      end

      if dynamics = @dynamic_parts
        # Siblings consume the same next segment. Parse it once when branching,
        # retaining borrowed bytes instead of allocating a segment cache.
        child_data = next_offset < path.bytesize ? PathSegment.read(path, next_offset) : nil
        dynamics.each do |dynamic|
          result = if child_data
                     dynamic.{{ find_segment }}(child_data[0], child_data[1], child_data[2], method)
                   else
                     dynamic.{{ terminal }}(method)
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
          return glob.payload_match_for_method(method)
        {% end %}
      end
      nil
    end
  {% end %}
end
