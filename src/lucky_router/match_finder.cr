class LuckyRouter::MatchFinder(T)
  private getter parts, params
  private property fragment

  @fragment : Fragment(T)
  # The parts are the raw strings from each section of the path.
  #
  # For example if matching "/users/1/edit", the parts would be ["users", "1",
  # "edit"]
  #
  # The parts aer slow condensed down as the program recursively finds matchs.
  # So if a match is found in the first fragment it will have all 3 parts, but
  # it'll then create a new MatchFinder and pass ["1", "edit"], until the last
  # fragment which will have just ["edit"] as the `parts`
  @parts : Array(String)
  @params : Hash(String, String)

  def initialize(@fragment, @parts, @params = {} of String => String)
  end

  # This uses the magic/pain of recursion to continue matching fragments
  # until there is a match in the final fragment, otherwise it returns `NoMatch`
  def run : Match(T) | NoMatch
    until parts.empty?
      match = matched_fragment
      return NoMatch.new if match.nil?

      add_to_params if has_param?
      if last_part? && has_match?
        return Match(T).new(matched_fragment.not_nil!.payload.not_nil!, params)
      end
      self.fragment = match
      parts.shift
    end

    NoMatch.new
  end

  private def has_param?
    dynamic_fragment && static_fragment.nil?
  end

  private def has_match?
    static_fragment || dynamic_fragment
  end

  private def matched_fragment
    static_fragment || dynamic_fragment
  end

  private def last_part?
    parts.size == 1
  end

  private def current_part
    parts.first
  end

  private def next_parts
    parts.skip(1)
  end

  private def add_to_params
    key = fragment.dynamic_part.not_nil!.name
    params[key] = current_part
  end

  private def static_fragment
    fragment.static_parts[current_part]?
  end

  private def dynamic_fragment
    fragment.dynamic_part.try(&.fragment)
  end
end
