require 'test_helper'
require 'json'

class DNSimpleConnectionErrorsTest < Minitest::Test
  MOCK_RESPONSE = {
    "pagination" => {
      "current_page": 1,
      "per_page": 1,
      "total_entries": 0,
      "total_pages": 1,
    },
    "data": [],
  }.to_json.freeze

  def setup
    super
    @dnsimple = Provider::DNSimple
  end

  def test_retrieve_current_records_retries_on_network_errors
    @dnsimple.expects(:backoff_sleep).times(5).returns(true)

    stub_request(:get, %r{https://api.sandbox.dnsimple.com/v2/.+?/zones/zone/records\?page=1&per_page=100})
      .to_timeout.times(5)
      .to_raise(Errno::ECONNRESET).times(5)
      .then.to_return(body: MOCK_RESPONSE)

    @dnsimple.retrieve_current_records(zone: 'zone')
  end

  def test_retrieve_current_records_eventually_raises_after_too_many_timeouts
    @dnsimple.expects(:backoff_sleep).never

    stub_request(:get, %r{https://api.sandbox.dnsimple.com/v2/.+?/zones/zone/records\?page=1&per_page=100})
      .to_timeout.times(6)

    assert_raises(Net::OpenTimeout) do
      @dnsimple.retrieve_current_records(zone: 'zone')
    end
  end

  def test_retrieve_current_records_raises_after_too_many_conn_resets
    @dnsimple.expects(:backoff_sleep).times(5).returns(true)

    stub_request(:get, %r{https://api.sandbox.dnsimple.com/v2/.+?/zones/zone/records\?page=1&per_page=100})
      .to_raise(Errno::ECONNRESET).times(6)

    assert_raises(Errno::ECONNRESET) do
      @dnsimple.retrieve_current_records(zone: 'zone')
    end
  end

  def test_zones_retries_on_network_errors
    @dnsimple.expects(:backoff_sleep).times(5).returns(true)

    stub_request(:get, %r{https://api.sandbox.dnsimple.com/v2/.+?/zones\?page=1&per_page=100})
      .to_timeout.times(5)
      .to_raise(Errno::ECONNRESET).times(5)
      .then.to_return(body: MOCK_RESPONSE)

    @dnsimple.zones
  end

  def test_zones_eventually_raises_after_too_many_timeouts
    @dnsimple.expects(:backoff_sleep).never

    stub_request(:get, %r{https://api.sandbox.dnsimple.com/v2/.+?/zones\?page=1&per_page=100})
      .to_timeout.times(6)

    assert_raises(Net::OpenTimeout) do
      @dnsimple.zones
    end
  end

  def test_zones_raises_after_too_many_conn_resets
    @dnsimple.expects(:backoff_sleep).times(5).returns(true)

    stub_request(:get, %r{https://api.sandbox.dnsimple.com/v2/.+?/zones\?page=1&per_page=100})
      .to_raise(Errno::ECONNRESET).times(6)

    assert_raises(Errno::ECONNRESET) do
      @dnsimple.zones
    end
  end
end
