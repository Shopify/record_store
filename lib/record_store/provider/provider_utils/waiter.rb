class Waiter
  def initialize(message = nil)
    @message = message || 'Waiting'
  end

  attr_accessor :message

  def wait(sleep_time)
    while sleep_time > 0
      wait_time = [10, sleep_time].min
      puts "#{message} (#{sleep_time}s left)" if wait_time > 1
      sleep(wait_time)
      sleep_time -= wait_time
    end
  end
end

class RateLimitWaiter < Waiter
  def initialize(provider)
    super("Waiting on #{provider} rate-limit")
  end
end

class BackoffWaiter < Waiter
  def initialize(message, initial_delay:, multiplier:, max_delay: nil)
    super(message)

    @initial_delay = @current_delay = initial_delay
    @multiplier = multiplier
    @max_delay = max_delay
  end

  def reset
    @current_delay = @initial_delay
  end

  def wait
    super(@current_delay)
    @current_delay = [@current_delay * @multiplier, @max_delay].compact.min
  end
end
