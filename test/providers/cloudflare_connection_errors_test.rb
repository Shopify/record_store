require 'test_helper'

class CloudflareConnectionErrorsTest < Minitest::Test
  def setup
    super
    # TODO: Remove this skip line
    skip("Implementation pending")
    @cloudflare = Provider::Cloudflare
  end

  def test_retrieve_current_records_retries_on_network_errors
    BackoffWaiter.any_instance.stubs(:wait)
    BackoffWaiter.any_instance.expects(:wait).times(5).returns(nil)

    stub_request(:get, "https://api.cloudflare.com/client/v4/zones/zone/dns_records")
      .to_timeout.times(5)
      .to_raise(Errno::ECONNRESET).times(5)
      .then.to_return(body: '{ "result": []}')

    @cloudflare.retrieve_current_records(zone: 'zone')
  end

  def test_retrieve_current_records_eventually_raises_after_too_many_timeouts
    BackoffWaiter.any_instance.stubs(:wait)
    BackoffWaiter.any_instance.expects(:wait).never

    stub_request(:get, "https://api.cloudflare.com/client/v4/zones/zone/dns_records")
      .to_timeout.times(6)

    assert_raises(Net::OpenTimeout) do
      @cloudflare.retrieve_current_records(zone: 'zone')
    end
  end

  def test_retrieve_current_records_eventually_raises_after_too_many_low_level_timeouts
    BackoffWaiter.any_instance.stubs(:wait)
    BackoffWaiter.any_instance.expects(:wait).never

    stub_request(:get, "https://api.cloudflare.com/client/v4/zones/zone/dns_records")
      .to_raise(Errno::ETIMEDOUT).times(6)

    assert_raises(Errno::ETIMEDOUT) do
      @cloudflare.retrieve_current_records(zone: 'zone')
    end
  end

  def test_retrieve_current_records_raises_after_too_many_conn_resets
    BackoffWaiter.any_instance.stubs(:wait)
    BackoffWaiter.any_instance.expects(:wait).times(5).returns(nil)

    stub_request(:get, "https://api.cloudflare.com/client/v4/zones/zone/dns_records")
      .to_raise(Errno::ECONNRESET).times(6)

    assert_raises(Errno::ECONNRESET) do
      @cloudflare.retrieve_current_records(zone: 'zone')
    end
  end

  def test_zones_retries_on_network_errors
    BackoffWaiter.any_instance.stubs(:wait)
    BackoffWaiter.any_instance.expects(:wait).times(5).returns(nil)

    stub_request(:get, "https://api.cloudflare.com/client/v4/zones")
      .to_timeout.times(5)
      .to_raise(Errno::ECONNRESET).times(5)
      .then.to_return(body: '[]')

    @cloudflare.zones
  end

  def test_zones_retries_on_low_level_timeouts
    BackoffWaiter.any_instance.stubs(:wait)
    BackoffWaiter.any_instance.expects(:wait).never

    stub_request(:get, "https://api.cloudflare.com/client/v4/zones")
      .to_raise(Errno::ETIMEDOUT).times(5)
      .then.to_return(body: '[]')

    @cloudflare.zones
  end

  def test_zones_raises_after_too_many_timeouts
    BackoffWaiter.any_instance.stubs(:wait)
    BackoffWaiter.any_instance.expects(:wait).never

    stub_request(:get, "https://api.cloudflare.com/client/v4/zones")
      .to_timeout.times(6)

    assert_raises(Net::OpenTimeout) do
      @cloudflare.zones
    end
  end

  def test_zones_raises_after_too_many_conn_resets
    BackoffWaiter.any_instance.stubs(:wait)
    BackoffWaiter.any_instance.expects(:wait).times(5)

    stub_request(:get, "https://api.cloudflare.com/client/v4/zones")
      .to_raise(Errno::ECONNRESET).times(6)

    assert_raises(Errno::ECONNRESET) do
      @cloudflare.zones
    end
  end

  def test_zones_raises_after_too_many_unparseable_responses
    BackoffWaiter.any_instance.stubs(:wait)
    BackoffWaiter.any_instance.expects(:wait).times(5)

    stub_request(:get, "https://api.cloudflare.com/client/v4/zones")
      .to_return(
        body: '<!DOCTYPE html> <title>Temporarily unavailable | api.cloudflare.com | Cloudflare</title>',
        status: 503,
      )
      .times(5)

    assert_raises(RecordStore::Provider::UnparseableBodyError) do
      @cloudflare.zones
    end
  end
end
