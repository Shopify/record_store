require 'test_helper'

class RateLimitWaiterTest < Minitest::Test
  def setup
    super
    @waiter = RateLimitWaiter.new('Test_Provider')
  end

  def test_wait_negative_time
    sleep_time = -1 * rand(10)
    @waiter.expects(:sleep).never
    @waiter.wait(sleep_time)
  end

  def test_wait_long_time
    # If wait is called with time gearter than 10
    sleep_time = rand(11..100)
    time_divided_by_ten = (sleep_time / 10)
    sleep_calls = (sleep_time % 10).zero? ? time_divided_by_ten : time_divided_by_ten + 1
    expect_sleep_called(sleep_time, sleep_calls)
  end

  def test_wait_short_time
    # If wait is called with time less 10
    sleep_time = rand(1..11)
    expect_sleep_called(sleep_time, 1)
  end

  def expect_sleep_called(sleep_time, sleep_calls)
    @waiter.stubs(:sleep)
    @waiter.expects(:sleep).times(sleep_calls)
    @waiter.wait(sleep_time)
  end
end

class BackoffWaiterTest < Minitest::Test
  def setup
    super

    @waiter = BackoffWaiter.new('Test backoff', initial_delay: 1, multiplier: 2, max_delay: 10)
  end

  def test_use_initial_delay_for_first_call
    @waiter.stubs(:sleep)

    @waiter.expects(:sleep).with(1).times(1)

    @waiter.wait
  end

  def test_increase_delay_for_each_subsequent_call
    @waiter.stubs(:sleep)

    @waiter.expects(:sleep).with(1).times(1)
    @waiter.expects(:sleep).with(2).times(1)
    @waiter.expects(:sleep).with(4).times(1)
    @waiter.expects(:sleep).with(8).times(1)

    4.times do
      @waiter.wait
    end
  end

  def test_increase_delay_for_each_subsequent_call_up_to_max
    @waiter.stubs(:sleep)

    @waiter.expects(:sleep).with(1).times(1)
    @waiter.expects(:sleep).with(2).times(1)
    @waiter.expects(:sleep).with(4).times(1)
    @waiter.expects(:sleep).with(8).times(1)
    @waiter.expects(:sleep).with(10).times(2)

    6.times do
      @waiter.wait
    end
  end

  def test_allows_to_reset_process
    @waiter.stubs(:sleep)

    @waiter.expects(:sleep).with(1).times(2)
    @waiter.expects(:sleep).with(2).times(1)

    2.times do
      @waiter.wait
    end
    @waiter.reset
    @waiter.wait
  end
end
