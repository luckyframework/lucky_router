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
    def initialize(method, new_path, duplicated_path)
      super <<-ERROR
      A route was attempted to be added that would overlap with an existing route.

        Route to be added: #{method.upcase} #{new_path}
        Existing route:    #{method.upcase} #{duplicated_path}

      One of the routes should be updated to avoid the overlap.

      ERROR
    end
  end
end
