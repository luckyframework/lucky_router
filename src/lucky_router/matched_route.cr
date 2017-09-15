struct LuckyRouter::MatchedRoute(T)
  private getter route, parts_to_match

  def initialize(@route : Route(T), @parts_to_match : Array(String))
  end

  def payload
    route.payload
  end

  def params : Hash(String, String)
    params_hash = {} of String => String
    route.named_parts_with_indices.each do |index, part_name|
      params_hash[part_name] = parts_to_match[index]
    end
    params_hash
  end
end
