class LuckyRouter::Fragment(T)
  alias Name = String
  property stored_payload : T?
  property dynamic_part : {name: String, fragment: Fragment(T)}?
  getter static_parts = Hash(Name, Fragment(T)).new

  def process_parts(parts : Array(String), payload : T)
    PartProcessor(T).new(self, parts: parts, payload: payload).run
    self
  end

  def find(parts : Array(String), params = {} of String => String) : Match(T) | NoMatch
    part = parts.first
    params = add_to_params(params, value: part) unless dynamic_part.nil?

    if last_fragment?(parts) && has_match?(part)
      Match(T).new(has_match?(part).not_nil!.stored_payload.not_nil!, params)
    elsif next_fragment = find_static_fragment(part)
      next_fragment.find(parts.skip(1), params)
    elsif next_fragment = find_dynamic_fragment
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
