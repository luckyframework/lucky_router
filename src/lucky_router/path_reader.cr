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
class LuckerRouter::PathReader
  include Enumerable(String)

  def initialize(@path : String)
  end

  def each
    each_segment do |offset, length, decode|
      segment = String.new(@path.to_unsafe + offset, length)
      if decode
        yield URI.decode(segment)
      else
        yield segment
      end
    end
  end

  private def each_segment
    decode = false
    offset = 0

    reader = Char::Reader.new(@path)
    reader.each do |char|
      case char
      when '/'
        length = reader.pos - offset
        yield offset, length, decode
        decode = false
        offset = reader.pos + 1
      when '%'
        decode = true
        reader.pos += 2
      end
    end

    length = @path.bytesize - offset
    return if length.zero?
    yield offset, length, decode
  end
end
