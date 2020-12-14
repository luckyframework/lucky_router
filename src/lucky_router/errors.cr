module LuckyRouter
  abstract class LuckyRouterError < Exception
  end

  class InvalidPathError < LuckyRouterError
  end

  class InvalidGlobError < LuckyRouterError
    def initialize(glob)
      super "Tried to define a glob as `#{glob}`, but it is invalid. Globs must be defined like `*` or given a name like `*:name`."
    end
  end

  class DuplicateRouteError < LuckyRouterError
    def initialize(method, path)
      super "Router already contains a route matching a #{method.upcase} request to `#{path}`."
    end
  end
end
