# A borrowed byte view. Keeping the source String alive makes the view safe
# throughout traversal, including dynamic backtracking.
struct LuckyRouter::PathSegment
  SLASH   = '/'.ord.to_u8
  PERCENT = '%'.ord.to_u8

  getter path : String
  getter offset : Int32
  getter length : Int32

  def initialize(@path, @offset, @length)
  end

  # Scans with a raw pointer and wrapping arithmetic: the loop condition
  # already bounds `index`, so per-byte bounds and overflow checks only add
  # branches to the hottest loop in the router.
  @[AlwaysInline]
  def self.read(path : String, offset : Int32) : Tuple(PathSegment, Int32, Bool)
    bytes = path.to_unsafe
    size = path.bytesize
    index = offset
    encoded = false
    while index < size
      byte = bytes[index]
      if byte == SLASH
        break
      elsif byte == PERCENT
        # Keep PathReader's segmentation even for malformed escapes.
        encoded = true
        index &+= 3
      else
        index &+= 1
      end
    end
    length = Math.min(index, size) &- offset
    {new(path, offset, length), index &+ 1, encoded}
  end

  @[AlwaysInline]
  def to_unsafe : UInt8*
    path.to_unsafe + offset
  end

  def to_slice : Bytes
    Slice.new(to_unsafe, length, read_only: true)
  end

  def value : String
    String.new(to_unsafe, length)
  end

  @[AlwaysInline]
  def ==(other : String) : Bool
    length == other.bytesize && PathSegment.same_bytes?(to_unsafe, other.to_unsafe, length)
  end

  # Route literals are short, so a word-at-a-time compare beats a libc call.
  # Reads stay inside both buffers because `length` bytes remain in each.
  @[AlwaysInline]
  def self.same_bytes?(left : UInt8*, right : UInt8*, length : Int32) : Bool
    while length >= 8
      return false unless read_word(left) == read_word(right)
      left += 8
      right += 8
      length &-= 8
    end
    if length >= 4
      return false unless read_half(left) == read_half(right)
      left += 4
      right += 4
      length &-= 4
    end
    while length > 0
      return false unless left.value == right.value
      left += 1
      right += 1
      length &-= 1
    end
    true
  end

  @[AlwaysInline]
  private def self.read_word(pointer : UInt8*) : UInt64
    word = uninitialized UInt64
    pointerof(word).as(UInt8*).copy_from(pointer, 8)
    word
  end

  @[AlwaysInline]
  private def self.read_half(pointer : UInt8*) : UInt32
    half = uninitialized UInt32
    pointerof(half).as(UInt8*).copy_from(pointer, 4)
    half
  end

  def hash(hasher)
    hasher.bytes(to_slice)
  end

  def self.glob_value(path : String, offset : Int32) : String
    bytes = path.to_slice
    suffix_length = bytes.size - offset
    if bytes[offset, suffix_length].includes?(PERCENT)
      # A malformed escape can skip a slash in PathReader's scanner. Only
      # discard a final slash when the scanner actually sees that delimiter.
      index = offset
      while index < bytes.size
        if bytes[index] == PERCENT
          index += 3
        else
          suffix_length -= 1 if index == bytes.size - 1 && bytes[index] == SLASH
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
