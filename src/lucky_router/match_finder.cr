class LuckyRouter::MatchFinder(T)
  private getter parts, method, params
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

  # It continues matching fragments
  # until there is a match in the final fragment,
  # otherwise it returns nil
  def run : Match(T)?
    until parts.empty?
      match = fragment.fragment_matching(current_part)
      return if match.nil?

      add_to_params if match.dynamic?
      if last_part?
        payload = match.method_to_payload[method]?
        # If we're on the last part and have a match, return the payload and params :D
        return Match(T).new(payload, params) if payload
      end

      self.fragment = match
      parts.shift
    end
  end

  private def last_part?
    parts.size == 1
  end

  private def current_part
    parts.first
  end

  private def add_to_params
    key = fragment.dynamic_part.not_nil!.name
    params[key] = current_part
  end
end
