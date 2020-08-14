require 'test_helper'

class NS1ConnectionErrorsTest < Minitest::Test
  def setup
    super
    @ns1 = Provider::NS1
  end

  def test_retrieve_current_records_retries_on_network_errors
    stub_request(:get, "https://api.nsone.net/v1/zones/zone")
      .to_timeout.times(5)
      .to_raise(Errno::ECONNRESET).times(5)
      .then.to_return(body: '{ "records": []}')

    @ns1.retrieve_current_records(zone: 'zone')
  end

  def test_retrieve_current_records_eventually_raises_after_too_many_timeouts
    stub_request(:get, "https://api.nsone.net/v1/zones/zone")
      .to_timeout.times(6)

    assert_raises(Net::OpenTimeout) do
      @ns1.retrieve_current_records(zone: 'zone')
    end
  end

  def test_retrieve_current_records_raises_after_too_many_conn_resets
    stub_request(:get, "https://api.nsone.net/v1/zones/zone")
      .to_raise(Errno::ECONNRESET).times(6)

    assert_raises(Errno::ECONNRESET) do
      @ns1.retrieve_current_records(zone: 'zone')
    end
  end

  def test_zones_retries_on_network_errors
    stub_request(:get, "https://api.nsone.net/v1/zones")
      .to_timeout.times(5)
      .to_raise(Errno::ECONNRESET).times(5)
      .then.to_return(body: '[]')

    @ns1.zones
  end

  def test_zones_raises_after_too_many_timeouts
    stub_request(:get, "https://api.nsone.net/v1/zones")
      .to_timeout.times(6)

    assert_raises(Net::OpenTimeout) do
      @ns1.zones
    end
  end

  def test_zones_raises_after_too_many_conn_resets
    stub_request(:get, "https://api.nsone.net/v1/zones")
      .to_raise(Errno::ECONNRESET).times(6)

    assert_raises(Errno::ECONNRESET) do
      @ns1.zones
    end
  end
end
