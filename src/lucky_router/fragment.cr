# A fragment represents possible combinations for a part of the path. The first/top
# fragment represents the first "part" of a path.
#
# The fragment contains the possible static parts or a single dynamic part
# Each static part or dynamic part has another fragment, that represents the
# next set of fragments that could match. This is a bit confusing so let's dive
# into an example:
#
#  * `/users/foo`
#  * `/users/:id`
#  * `/posts/foo`
#
# The Fragment would represent the possible combinations for the first part
#
# ```
# # 'nil' because there is no route with a dynamic part in the first slot
# fragment.dynamic_part # nil
#
# # This returns a Hash whose keys are the possible values, and a value for the
# *next* Fragment
# fragment.static_parts
#
# # Would return:
# {"users" => Fragment, "posts" => Fragment}
#
# # The Fragment in the 'users' key would have:
#
# # DynamicFragment.new(:id, Fragment)
# fragment.dynamic_part
#
# # Static parts
# fragment.static_parts
# {"foo" => Fragment}
# ```
#
# ## Gotcha
#
# The last fragment of a path is "empty". It does not have static parts or
# dynamic parts
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
  property dynamic_part : DynamicFragment(T)?
  getter static_parts = Hash(StaticPartName, Fragment(T)).new
  # Every path can have multiple request methods
  # and since each fragment represents a request path
  # the final step to finding the payload is to search for a matching request method
  getter method_to_payload = Hash(String, T).new

  def find(parts : Array(String), method : String) : Match(T) | NoMatch
    MatchFinder(T).new(self, parts: parts, method: method).run
  end

  def process_parts(parts : Array(String), method : String, payload : T)
    leaf_fragment = parts.reduce(self) { |fragment, part| fragment.add_part(part) }
    leaf_fragment.method_to_payload[method] = payload
  end

  def add_part(part : String) : Fragment(T)
    if part.starts_with?(":")
      dynamic_fragment = self.dynamic_part ||= DynamicFragment(T).new(
        name: part[1...],
        fragment: Fragment(T).new
      )
      return dynamic_fragment.fragment
    end

    static_parts[part] ||= Fragment(T).new
  end
end
