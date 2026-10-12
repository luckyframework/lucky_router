require "char/reader"
require "uri"

# A PathReader parses a URI path into segments.
#
# It can be used to read a String representing a full path into the individual
# segments it contains.
#
# ```
# path = "/foo/bar/baz"
# PathReader.new(path).to_a => ["", "foo", "bar", "baz"]
# ```
#
# Percent-encoded characters are automatically decoded following segmentation
#
# ```
# path = "/user/foo%40example.com/details"
# PathReader.new(path).to_a => ["", "user", "foo@example.com", "details"]
# ```
struct LuckerRouter::PathReader
  include Enumerable(String)

  def initialize(@path : String)
  end

  def each(&)
    each_segment do |offset, length, decode|
      yield decode ? self.class.decode_range(@path, offset, length) : @path.byte_slice(offset, length)
    end
  end

  # Decode directly from the source bytes into one bounded string allocation.
  # Like URI.decode, invalid escapes and literal '+' characters are preserved.
  def self.decode_range(path : String, offset : Int32, length : Int32) : String
    return "" if length.zero?

    bytes = path.to_slice
    limit = offset + length
    String.new(length) do |buffer|
      written = 0
      index = offset
      while index < limit
        byte = bytes[index]
        if byte == '%'.ord && index + 2 < limit
          high = hex_value(bytes[index + 1])
          low = hex_value(bytes[index + 2])
          if high >= 0 && low >= 0
            buffer[written] = (high * 16 + low).to_u8
            written += 1
            index += 3
            next
          end
        end
        # Output never exceeds the input length, including malformed escapes.
        buffer[written] = byte
        written += 1
        index += 1
      end
      {written, 0}
    end
  end

  private def self.hex_value(byte : UInt8) : Int32
    case byte
    when 48..57  then byte.to_i - 48
    when 65..70  then byte.to_i - 55
    when 97..102 then byte.to_i - 87
    else              -1
    end
  end

  private def each_segment(&)
    index = 0
    offset = 0
    decode = false
    slice = @path.to_slice

    while index < slice.size
      byte = slice[index]
      case byte
      when '/'
        length = index - offset
        yield offset, length, decode
        decode = false
        index += 1
        offset = index
      when '%'
        decode = true
        index += 3
      else
        index += 1
      end
    end

    length = @path.bytesize - offset
    return if length.zero?
    yield offset, length, decode
  end
end
