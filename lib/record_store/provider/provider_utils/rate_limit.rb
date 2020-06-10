class RateLimit
  def initialize(provider)
    @provider = provider
  end

  def sleep_for(sleep_time)
    while sleep_time > 0
      wait = [10, sleep_time].min
      puts "Waiting on #{@provider} rate-limit" if wait > 1
      sleep(wait)
      sleep_time -= wait
    end
  end
end
