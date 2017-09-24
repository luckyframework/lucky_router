class LuckyRouter::Matcher(T)
  getter paths, routes
  alias RoutePartsSize = Int32
  alias HttpMethod = String
  @routes = Hash(HttpMethod, Hash(RoutePartsSize, Fragment(T))).new

  class NoMatch
  end

  class Fragment(T)
    alias Name = String
    property stored_payload : T?
    property dynamic_part : {name: String, fragment: Fragment(T)}?
    # property dynamic_part : Fragment(T)?
    getter static_parts = Hash(Name, Fragment(T)).new

    def process_parts(parts : Array(String), payload : T)
      unless parts.empty?
        add_part(parts.first, parts.skip(1), payload)
      end

      self
    end

    private def add_part(part, next_parts, payload : T)
      if part.starts_with?(":")
        self.dynamic_part ||= {name: part.gsub(":", ""), fragment: Fragment(T).new}
        self.dynamic_part.not_nil![:fragment].process_parts(next_parts, payload)
        if next_parts.empty?
          self.dynamic_part.not_nil![:fragment].stored_payload = payload
        end
      else
        static_parts[part] ||= Fragment(T).new
        static_parts[part].process_parts(next_parts, payload)

        if next_parts.empty?
          static_parts[part].stored_payload = payload
        end
      end
    end

    def find(parts : Array(String), params = {} of String => String)
      part = parts.first

      if last_fragment?(parts) && has_match?(part)
        params = add_to_params(params, value: part) unless dynamic_part.nil?
        MatchedFragment(T).new(has_match?(part).not_nil!.stored_payload.not_nil!, params)
      elsif next_fragment = find_static_fragment(part)
        next_fragment.find(parts.skip(1), params)
      elsif next_fragment = find_dynamic_fragment
        params = add_to_params(params, value: part)
        next_fragment.find(parts.skip(1), params)
      else
        NoMatch.new
      end
    end

    private def add_to_params(params : Hash(String, String), value : String) : Hash(String, String)
      key = dynamic_part.not_nil![:name]
      params[key] = value
      params
    end

    private def has_match?(part)
      match = find_static_fragment(part) || find_dynamic_fragment

      if match.is_a?(Fragment(T))
        match
      elsif match.is_a?(Nil)
        nil
      else
        match[:fragment]
      end
    end

    private def find_static_fragment(part)
      static_parts[part]?
    end

    private def find_dynamic_fragment
      dynamic_part.try do |part|
        part[:fragment]
      end
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
    parts = path.split("/")
    routes[method] ||= Hash(RoutePartsSize, Fragment(T)).new
    routes[method][parts.size] ||= Fragment(T).new
    routes[method][parts.size].process_parts(parts, payload)
  end

  def match(method : String, path_to_match : String) : MatchedFragment(T)?
    parts_to_match = path_to_match.split("/")
    return if routes[method]?.try(&.[parts_to_match.size]?).nil?
    match = routes[method][parts_to_match.size].find(parts_to_match)

    if match.is_a?(MatchedFragment)
      match
    end
  end

  def match!(method : String, path_to_match : String) : MatchedFragment(T)
    match(method, path_to_match) || raise "No matching route found for: #{path_to_match}"
  end
end
