class LuckyRouter::Matcher(T)
  getter paths, routes
  alias RoutePartsSize = Int32
  alias HttpMethod = String
  @routes = Hash(HttpMethod, Hash(RoutePartsSize, Fragment(T))).new

  class NoMatch
  end

  class Fragment(T)
    alias Name = String
    getter name : String
    getter payload : T
    getter dynamic_part : Fragment(T)?

    def initialize(@payload, @name)
    end

    def static_parts
       Hash(Name, Fragment(T)).new
    end

    def find(parts : Array(String), params = {} of String => String)
      part = parts.first

      if last_fragment?(parts) && has_match?(part)
        MatchedFragment(T).new(payload, params)
      elsif next_fragment = find_static_fragment(part)
        next_fragment.find(parts.skip(1), params)
      elsif next_fragment = find_dynamic_fragment(part)
        params = add_to_params(params, value: part)
        next_fragment.find(parts.skip(1), params)
      else
        NoMatch.new
      end
    end

    private def add_to_params(params : Hash(String, String), value : String) : Hash(String, String)
      params[dynamic_part.not_nil!.name] = value
      params
    end

    private def has_match?(part)
      find_static_fragment(part) || find_dynamic_fragment(part)
    end

    private def find_static_fragment(part)
      static_parts[part]?
    end

    private def find_dynamic_fragment(part)
      dynamic_part
    end

    private def last_fragment?(parts)
      parts.size == 1
    end
  end

  class MatchedFragment(T)
    getter payload : T
    getter params : Hash(String, String)

    def initialize(@payload, @params)
    end
  end

  def add(method : String, path : String, payload : T)
    # parts = path.split("/")
    # routes[method] ||= {parts.size => Fragment(T).new}
    # routes[method][parts.size].process_parts(parts, payload)
  end

  def match(method : String, path_to_match : String)
    parts_to_match = path_to_match.split("/")
    match = routes[method][parts_to_match.size].find(parts_to_match)

    if match.is_a?(MatchedFragment)
      match
    end
  end

  def match!(method : String, path_to_match : String) : MatchedFragment(T)
    match(method, path_to_match) || raise "No matching route found for: #{path_to_match}"
  end
end
