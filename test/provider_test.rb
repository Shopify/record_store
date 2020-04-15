require 'test_helper'

class ProviderTest < Minitest::Test
  def test_provider_for_recognizes_dnsimple_soa_for_zone_name
    Provider.expects(:master_nameserver_for).with('dnsimple.com').returns('ns1.dnsimple.com')
    provider = Provider.provider_for('dnsimple.com')
    assert_equal('DNSimple', provider)
  end

  def test_provider_for_recognizes_dynect_soa_for_zone_name
    Provider.expects(:master_nameserver_for).with('dynect.net').returns('ns1.p19.dynect.net')
    provider = Provider.provider_for('dynect.net')
    assert_equal('DynECT', provider)
  end

  def test_provider_for_recognizes_google_cloud_dns_soa_for_zone_name
    Provider.expects(:master_nameserver_for).with('googledomains.com').returns('ns5.googledomains.com')
    provider = Provider.provider_for('googledomains.com')
    assert_equal('GoogleCloudDNS', provider)
  end

  def test_provider_for_recognizes_nsone_soa_for_zone_name
    Provider.expects(:master_nameserver_for).with('nsone.net').returns('dns1.p01.nsone.net')
    provider = Provider.provider_for('nsone.net')
    assert_equal('NS1', provider)
  end

  def test_provider_for_recognizes_oraclecloud_soa_for_zone_name
    Provider.expects(:master_nameserver_for).with('oraclecloud.net').returns('ns1.p68.dns.oraclecloud.net')
    provider = Provider.provider_for('oraclecloud.net')
    assert_equal('OracleCloudDNS', provider)
  end

  def test_provider_for_recognizes_dnsimple_ns_record
    ns = Record::NS.new(fqdn: 'dnsimple.com', ttl: 172_800, nsdname: 'ns1.dnsimple.com.')
    provider = Provider.provider_for(ns)
    assert_equal('DNSimple', provider)
  end

  def test_provider_for_recognizes_dynect_ns_record
    ns = Record::NS.new(fqdn: 'dynect.net', ttl: 172_800, nsdname: 'ns1.p19.dynect.net.')
    provider = Provider.provider_for(ns)
    assert_equal('DynECT', provider)
  end

  def test_provider_for_recognizes_google_cloud_dns_ns_record
    ns = Record::NS.new(fqdn: 'googledomains.com', ttl: 172_800, nsdname: 'ns5.googledomains.com.')
    provider = Provider.provider_for(ns)
    assert_equal('GoogleCloudDNS', provider)
  end

  def test_provider_for_recognizes_nsone_ns_record
    ns = Record::NS.new(fqdn: 'nsone.net', ttl: 172_800, nsdname: 'dns1.p01.nsone.net.')
    provider = Provider.provider_for(ns)
    assert_equal('NS1', provider)
  end

  def test_provider_for_recognizes_oraclecloud_ns_record
    ns = Record::NS.new(fqdn: 'oraclecloud.net', ttl: 172_800, nsdname: 'ns1.p68.dns.oraclecloud.net.')
    provider = Provider.provider_for(ns)
    assert_equal('OracleCloudDNS', provider)
  end

  def test_provider_for_recognizes_dnsimple_ns_record
    ns = Record::NS.new(fqdn: 'dnsimple.com', ttl: 172_800, nsdname: 'ns1.dnsimple.com.')
    provider = Provider.provider_for(ns)
    assert_equal('DNSimple', provider)
  end

  def test_provider_for_handles_unknown_provider
    Provider.expects(:master_nameserver_for).with('example.com').returns('ns.icann.org')
    provider = Provider.provider_for('example.com')
    assert_nil(provider)
  end

  def test_provider_for_handles_unknown_domain
    Provider.expects(:master_nameserver_for).with('unknown-domain.com').raises(Resolv::ResolvError)
    provider = Provider.provider_for('unknown-domain.com')
    assert_nil(provider)
  end
end
