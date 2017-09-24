class LuckyRouter::MatchFinder(T)
  private getter fragment, parts, params

  @fragment : Fragment(T)
  @parts : Array(String)
  @params : Hash(String, String)

  def initialize(@fragment, @parts, @params = {} of String => String)
  end

  def run : Match(T) | NoMatch
    add_to_params unless dynamic_fragment.nil?

    if last_fragment? && has_match?
      Match(T).new(matched_fragment.not_nil!.payload.not_nil!, params)
    elsif static_fragment
      MatchFinder(T).new(static_fragment.not_nil!, next_parts, params).run
    elsif dynamic_fragment
      MatchFinder(T).new(dynamic_fragment.not_nil!, next_parts, params).run
    else
      NoMatch.new
    end
  end

  private def has_match?
    static_fragment || dynamic_fragment
  end

  private def matched_fragment
    static_fragment || dynamic_fragment
  end

  private def last_fragment?
    parts.size == 1
  end

  private def current_part
    parts.first
  end

  private def next_parts
    parts.skip(1)
  end

  private def add_to_params
    key = fragment.dynamic_part.not_nil![:name]
    params[key] = current_part
  end

  private def static_fragment
    fragment.static_parts[current_part]?
  end

  private def dynamic_fragment
    fragment.dynamic_part.try(&.[:fragment])
  end
end
