class LuckyRouter::Fragment(T)
  alias Name = String
  property stored_payload : T?
  property dynamic_part : {name: String, fragment: Fragment(T)}?
  getter static_parts = Hash(Name, Fragment(T)).new

  def process_parts(parts : Array(String), payload : T)
    unless parts.empty?
      add_part(parts.first, parts.skip(1), payload)
    end

    self
  end

  private def add_part(part, next_parts, payload : T)
    if part.starts_with?(":")
      add_dynamic_part(part, next_parts, payload)
    else
      add_static_part(part, next_parts, payload)
    end
  end

  private def add_dynamic_part(part, next_parts, payload)
    self.dynamic_part ||= {name: part.gsub(":", ""), fragment: Fragment(T).new}
    self.dynamic_part.not_nil![:fragment].process_parts(next_parts, payload)

    if next_parts.empty?
      add_payload_to_dynamic_part(payload)
    end
  end

  private def add_static_part(part, next_parts, payload)
    static_parts[part] ||= Fragment(T).new
    static_parts[part].process_parts(next_parts, payload)

    if next_parts.empty?
      static_parts[part].stored_payload = payload
    end
  end

  private def add_payload_to_dynamic_part(payload)
    self.dynamic_part.not_nil![:fragment].stored_payload = payload
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
