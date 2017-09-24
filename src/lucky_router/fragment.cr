class LuckyRouter::Fragment(T)
  alias Name = String
  property payload : T?
  property dynamic_part : {name: String, fragment: Fragment(T)}?
  getter static_parts = Hash(Name, Fragment(T)).new

  def process_parts(parts : Array(String), payload : T)
    PartProcessor(T).new(self, parts: parts, payload: payload).run
    self
  end

  def find(parts : Array(String)) : Match(T) | NoMatch
    MatchFinder(T).new(self, parts: parts).run
  end
end
