require 'test_helper'

class RateLimitTest < Minitest::Test
  def setup
    super
    @rate_limit = RateLimit.new('Test_Provider')
  end

  def test_sleep_for_negative_time
    sleep_time = -1 * rand(10)
    @rate_limit.expects(:sleep).never
    @rate_limit.sleep_for(sleep_time)
  end

  def test_sleep_for_long_time
    # If sleep_for is called with time gearter than 10
    sleep_time = rand(11..100)
    time_divided_by_ten = (sleep_time / 10)
    sleep_calls = (sleep_time % 10).zero? ? time_divided_by_ten : time_divided_by_ten + 1
    expect_sleep_called(sleep_time, sleep_calls)
  end

  def test_sleep_for_short_time
    # If sleep_for is called with time less 10
    sleep_time = rand(1..11)
    expect_sleep_called(sleep_time, 1)
  end

  def expect_sleep_called(sleep_time, sleep_calls)
    @rate_limit.stubs(:sleep)
    @rate_limit.expects(:sleep).times(sleep_calls)
    @rate_limit.sleep_for(sleep_time)
  end
end
