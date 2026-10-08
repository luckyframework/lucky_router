# A borrowed byte view. Keeping the source String alive makes the view safe
# throughout traversal, including dynamic backtracking.
struct LuckyRouter::PathSegment
  getter path : String
  getter offset : Int32
  getter length : Int32

  def initialize(@path, @offset, @length)
  end

  @[AlwaysInline]
  def self.read(path : String, offset : Int32) : Tuple(PathSegment, Int32, Bool)
    bytes = path.to_slice
    index = offset
    encoded = false
    while index < bytes.size
      case bytes[index]
      when '/'.ord
        break
      when '%'.ord
        # Keep PathReader's segmentation even for malformed escapes.
        encoded = true
        index += 3
      else
        index += 1
      end
    end
    length = Math.min(index, bytes.size) - offset
    {new(path, offset, length), index + 1, encoded}
  end

  def to_slice : Bytes
    path.to_slice[offset, length]
  end

  def value : String
    path.byte_slice(offset, length)
  end

  @[AlwaysInline]
  def ==(other : String) : Bool
    length == other.bytesize && to_slice == other.to_slice
  end

  def hash(hasher)
    hasher.bytes(to_slice)
  end

  def self.glob_value(path : String, offset : Int32) : String
    bytes = path.to_slice
    suffix_length = bytes.size - offset
    if bytes[offset, suffix_length].includes?('%'.ord.to_u8)
      # A malformed escape can skip a slash in PathReader's scanner. Only
      # discard a final slash when the scanner actually sees that delimiter.
      index = offset
      while index < bytes.size
        if bytes[index] == '%'.ord
          index += 3
        else
          suffix_length -= 1 if index == bytes.size - 1 && bytes[index] == '/'.ord
          index += 1
        end
      end
      LuckerRouter::PathReader.decode_range(path, offset, suffix_length)
    else
      suffix_length -= 1 if path.ends_with?('/')
      path.byte_slice(offset, suffix_length)
    end
  end
end

class String
  # Hash(String, ...) compares its stored key to the borrowed lookup key.
  @[AlwaysInline]
  def ==(other : LuckyRouter::PathSegment) : Bool
    other == self
  end
end
