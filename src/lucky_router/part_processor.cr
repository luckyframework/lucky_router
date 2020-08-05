class LuckyRouter::PartProcessor(T)
  private getter fragment, payload, method, parts

  @fragment : Fragment(T)
  @payload : T
  @parts : Array(String)
  @method : String

  def initialize(@fragment, @parts, @method, @payload)
  end

  def run
    unless parts.empty?
      current_part = parts.first
      next_parts = parts.skip(1)

      if current_part.starts_with?(":")
        dynamic_part = fragment.dynamic_part ||= Fragment::DynamicFragment.new(
          name: current_part.gsub(":", ""),
          fragment: Fragment(T).new
        )
        dynamic_part.fragment.process_parts(next_parts, method, payload)

        if next_parts.empty?
          dynamic_part.fragment.method_to_payload[method] = payload
        end
      else
        new_fragment = fragment.static_parts[current_part] ||= Fragment(T).new
        new_fragment.process_parts(next_parts, method, payload)

        if next_parts.empty?
          new_fragment.method_to_payload[method] = payload
        end
      end
    end
  end
end
