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
# {PathPart("users") => Fragment, PathPart("posts") => Fragment}
#
# # The Fragment in the 'users' key would have:
#
# # Fragment.new(PathPart(":id"))
# fragment.dynamic_part
#
# # Static parts
# fragment.static_parts
# {PathPart("foo") => Fragment}
# ```
#
# ## Gotcha
#
# The last fragment of a path is "empty". It does not have static parts or
# dynamic parts
class LuckyRouter::Fragment(T)
  property dynamic_part : Fragment(T)?
  getter static_parts = Hash(PathPart, Fragment(T)).new
  # Every path can have multiple request methods
  # and since each fragment represents a request path
  # the final step to finding the payload is to search for a matching request method
  getter method_to_payload = Hash(String, T).new
  getter path_part : PathPart

  def initialize(@path_part)
  end

  # This looks for a matching fragment for the given parts
  # and returns NoMatch if one is not found
  def find(parts : Array(PathPart), method : String) : Match(T) | NoMatch
    # params are a key value pair of a path variable name matched to its value
    # so a path like /users/:id will have a path variable name of id and
    # a matching url of /users/456 will have a value of 456
    params = {} of String => String
    result = parts.reduce(self) do |fragment, part|
      match = fragment.static_parts[part]? || fragment.dynamic_part
      break if match.nil?

      if match.dynamic?
        params[match.path_part.name] = part.name
      end

      match
    end

    payload = result.try(&.method_to_payload[method]?)
    payload.nil? ? NoMatch.new : Match(T).new(payload, params)
  end

  def process_parts(parts : Array(PathPart), method : String, payload : T)
    leaf_fragment = parts.reduce(self) { |fragment, part| fragment.add_part(part) }
    leaf_fragment.method_to_payload[method] = payload
  end

  def add_part(part : PathPart) : Fragment(T)
    if part.path_variable?
      self.dynamic_part ||= Fragment(T).new(path_part: part)
    else
      static_parts[part] ||= Fragment(T).new(path_part: part)
    end
  end

  def dynamic?
    path_part.path_variable?
  end
end
