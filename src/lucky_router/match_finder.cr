class LuckyRouter::MatchFinder(T)
  private getter parts, params, method
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
  @method : String
  @params : Hash(String, String)

  def initialize(@fragment, @parts, @method, @params = {} of String => String)
  end

  # This looks for a matching fragment for the given parts
  # and returns NoMatch if one is not found
  def run : Match(T) | NoMatch
    loop do
      static_fragment = fragment.static_parts[parts.first]?
      dynamic_fragment = fragment.dynamic_part.try(&.fragment)
      match = static_fragment || dynamic_fragment
      return NoMatch.new if match.nil?

      if dynamic_fragment && static_fragment.nil?
        key = fragment.dynamic_part.not_nil!.name
        params[key] = parts.first
      end

      if parts.size == 1
        payload = match.method_to_payload[method]?
        return payload.nil? ? NoMatch.new : Match(T).new(payload, params)
      end
      self.fragment = match
      parts.shift
      break if parts.empty?
    end

    NoMatch.new
  end
end
