class LuckyRouter::Fragment(T)
  # This is a simple wrapper around Fragment, that includes holds the
  # `name` of the dynamic fragment so it can be used to populate the params hash.
  struct DynamicFragment(T)
    # The name of the dynamic part
    # For example, if you have the path "/users/:id" the dynamic part
    # name would be "id"
    getter name
    getter fragment

    def initialize(@name : String, @fragment : Fragment(T))
    end
  end

  alias StaticPartName = String
  property payload : T?
  property dynamic_part : DynamicFragment(T)?
  getter static_parts = Hash(StaticPartName, Fragment(T)).new

  def process_parts(parts : Array(String), payload : T)
    PartProcessor(T).new(self, parts: parts, payload: payload).run
    self
  end

  def find(parts : Array(String)) : Match(T) | NoMatch
    MatchFinder(T).new(self, parts: parts).run
  end
end
