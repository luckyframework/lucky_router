class LuckyRouter::PartProcessor(T)
  private getter fragment, payload, parts

  @fragment : Fragment(T)
  @payload : T
  @parts : Array(String)

  def initialize(@fragment, @parts, @payload)
  end

  def run
    unless parts.empty?
      process_parts
    end
  end

  private def process_parts
    if dynamic_part?
      add_dynamic_part
    else
      add_static_part
    end
  end

  private def dynamic_part?
    current_part.starts_with?(":")
  end

  private def current_part
    parts.first
  end

  private def next_parts
    parts.skip(1)
  end

  private def add_dynamic_part
    fragment.dynamic_part ||= Fragment::DynamicFragment.new(
      name: current_part.gsub(":", ""),
      fragment: Fragment(T).new
    )
    fragment.dynamic_part.not_nil!.fragment.process_parts(next_parts, payload)

    if on_last_part?
      add_payload_to_dynamic_part
    end
  end

  def on_last_part?
    next_parts.empty?
  end

  private def add_static_part
    fragment.static_parts[current_part] ||= Fragment(T).new
    fragment.static_parts[current_part].process_parts(next_parts, payload)

    if next_parts.empty?
      fragment.static_parts[current_part].payload = payload
    end
  end

  private def add_payload_to_dynamic_part
    fragment.dynamic_part.not_nil!.fragment.payload = payload
  end
end
