module LuckyRouter
  abstract class LuckyRouterError < Exception
  end

  class InvalidPathError < LuckyRouterError
  end
end
