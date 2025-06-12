struct LuckyRouter::Match(T)
  getter payload : T
  getter params : Hash(String, String)

  def initialize(@payload, @params)
  end
end
