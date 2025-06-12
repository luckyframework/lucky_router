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
      segment = String.new(@path.to_unsafe + offset, length)
      if decode
        yield URI.decode(segment)
      else
        yield segment
      end
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
