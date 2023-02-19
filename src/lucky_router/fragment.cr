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
# # Fragment.new(PathPart(":id"))
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
  getter dynamic_parts = Array(Fragment(T)).new
  getter static_parts = Hash(String, Fragment(T)).new
  property glob_part : Fragment(T)?
  # Every path can have multiple request methods
  # and since each fragment represents a request path
  # the final step to finding the payload is to search for a matching request method
  getter method_to_payload = Hash(String, T).new
  getter path_part : PathPart

  def initialize(@path_part)
  end

  # This looks for a matching fragment for the given parts
  # and returns NoMatch if one is not found
  def find(parts : Array(String), method : String) : Match(T) | NoMatch
    find_match(parts, method) || NoMatch.new
  end

  # :ditto:
  def find(parts : Slice(String), method : String) : Match(T) | NoMatch
    find_match(parts, method) || NoMatch.new
  end

  def process_parts(parts : Array(PathPart), method : String, payload : T)
    leaf_fragment = parts.reduce(self) { |fragment, part| fragment.add_part(part) }
    leaf_fragment.method_to_payload[method] = payload
  end

  def add_part(path_part : PathPart) : Fragment(T)
    if path_part.glob?
      self.glob_part = Fragment(T).new(path_part: path_part)
    elsif path_part.path_variable?
      existing = self.dynamic_parts.find { |fragment| fragment.path_part == path_part }
      return existing if existing

      fragment = Fragment(T).new(path_part: path_part)
      self.dynamic_parts << fragment
      fragment
    else
      static_parts[path_part.part] ||= Fragment(T).new(path_part: path_part)
    end
  end

  def dynamic? : Bool
    path_part.path_variable?
  end

  def find_match(path_parts : Array(String), method : String) : Match(T)?
    find_match(path_parts, 0, method)
  end

  def find_match(path_parts : Slice(String), method : String) : Match(T)?
    find_match(path_parts, 0, method)
  end

  def match_for_method(method)
    payload = method_to_payload[method]?
    payload ? Match(T).new(payload, Hash(String, String).new) : nil
  end

  protected def find_match(path_parts, index, method : String) : Match(T)?
    return match_for_method(method) if index >= path_parts.size

    path_part = path_parts[index]
    index += 1

    find_match_with_static_parts(path_part, path_parts, index, method) ||
      find_match_with_dynamics(path_part, path_parts, index, method) ||
      find_match_with_glob(path_part, path_parts, index, method)
  end

  private def find_match_with_static_parts(path_part, path_parts, index, method)
    static_part = static_parts[path_part]?
    return unless static_part

    static_part.find_match(path_parts, index, method)
  end

  private def find_match_with_dynamics(path_part, path_parts, index, method)
    dynamic_parts.each do |dynamic_part|
      if match = dynamic_part.find_match(path_parts, index, method)
        match.params[dynamic_part.path_part.name] = path_part
        return match
      end
    end
  end

  private def find_match_with_glob(path_part, path_parts, index, method)
    glob = glob_part
    return unless glob

    if match = glob.match_for_method(method)
      match.params[glob.path_part.name] = String.build do |io|
        io << path_part
        index.upto(path_parts.size - 1) do |sub_index|
          io << '/'
          io << path_parts[sub_index]
        end
      end
      match
    end
  end
end
