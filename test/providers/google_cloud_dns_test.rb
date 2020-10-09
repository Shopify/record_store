require 'test_helper'

class GoogleCloudDNSTest < Minitest::Test
  def setup
    super
    @zone_name = 'dns-test.shopify.io'
  end

  def test_supports_alias_by_default
    refute_predicate(Provider::GoogleCloudDNS, :supports_alias?)
  end

  def test_build_a_from_api
    record = Provider::GoogleCloudDNS.send(
      :build_from_api,
      Google::Cloud::Dns::Record.new(
        'a.dns-test.shopify.io.',
        'A',
        600,
        '10.11.12.13'
      )
    )

    assert_kind_of(Record::A, record)
    assert_equal('a.dns-test.shopify.io.', record.fqdn)
    assert_equal('10.11.12.13', record.address)
    assert_equal(600, record.ttl)
  end

  def test_build_aaaa_from_api
    record = Provider::GoogleCloudDNS.send(
      :build_from_api,
      Google::Cloud::Dns::Record.new(
        'aaaa.dns-test.shopify.io.',
        'AAAA',
        600,
        '2001:0db8:85a3:0000:0000:EA75:1337:BEEF'
      )
    )

    assert_kind_of(Record::AAAA, record)
    assert_equal('aaaa.dns-test.shopify.io.', record.fqdn)
    assert_equal('2001:0db8:85a3:0000:0000:EA75:1337:BEEF', record.address)
    assert_equal(600, record.ttl)
  end

  def test_build_caa_from_api
    record = Provider::GoogleCloudDNS.send(
      :build_from_api,
      Google::Cloud::Dns::Record.new(
        'cname.dns-test.shopify.io.',
        'CAA',
        1800,
        ['0 issue "digicert.com"']
      )
    )

    assert_kind_of(Record::CAA, record)
    assert_equal('cname.dns-test.shopify.io.', record.fqdn)
    assert_equal(0, record.flags)
    assert_equal('issue', record.tag)
    assert_equal('digicert.com', record.value)
    assert_equal(1800, record.ttl)
  end

  def test_build_cname_from_api
    record = Provider::GoogleCloudDNS.send(
      :build_from_api,
      Google::Cloud::Dns::Record.new(
        'cname.dns-test.shopify.io.',
        'CNAME',
        600,
        'dns-test.shopify.io.'
      )
    )

    assert_kind_of(Record::CNAME, record)
    assert_equal('cname.dns-test.shopify.io.', record.fqdn)
    assert_equal('dns-test.shopify.io.', record.cname)
    assert_equal(600, record.ttl)
  end

  def test_build_mx_from_api
    record = Provider::GoogleCloudDNS.send(
      :build_from_api,
      Google::Cloud::Dns::Record.new(
        'mx.dns-test.shopify.io.',
        'MX',
        60,
        ['10 mail-server.example.com.'],
      )
    )

    assert_kind_of(Record::MX, record)
    assert_equal('mx.dns-test.shopify.io.', record.fqdn)
    assert_equal('mail-server.example.com.', record.exchange)
    assert_equal(10, record.preference)
    assert_equal(60, record.ttl)
  end

  def test_build_multiple_ns_from_api
    record = Provider::GoogleCloudDNS.send(
      :build_from_api,
      Google::Cloud::Dns::Record.new(
        'dns-test.shopify.io.',
        'NS',
        3600,
        ['ns-cloud-d4.googledomains.com.'],
      )
    )

    assert_kind_of(Record::NS, record)
    assert_equal('dns-test.shopify.io.', record.fqdn)
    assert_equal('ns-cloud-d4.googledomains.com.', record.nsdname)
    assert_equal(3600, record.ttl)
  end

  def test_build_srv_from_api
    record = Provider::GoogleCloudDNS.send(
      :build_from_api,
      Google::Cloud::Dns::Record.new(
        '_service._TCP.srv.dns-test.shopify.io.',
        'SRV',
        60,
        ['10 47 80 target-srv.dns-test.shopify.io.']
      )
    )

    assert_kind_of(Record::SRV, record)
    assert_equal('_service._tcp.srv.dns-test.shopify.io.', record.fqdn)
    assert_equal(10, record.priority)
    assert_equal(47, record.weight)
    assert_equal(80, record.port)
    assert_equal('target-srv.dns-test.shopify.io.', record.target)
    assert_equal(60, record.ttl)
  end

  def test_build_txt_from_api
    record = Provider::GoogleCloudDNS.send(
      :build_from_api,
      Google::Cloud::Dns::Record.new(
        'txt.dns-test.shopify.io.',
        'TXT',
        60,
        ['"Hello, world!"']
      )
    )

    assert_kind_of(Record::TXT, record)
    assert_equal('txt.dns-test.shopify.io.', record.fqdn)
    assert_equal('Hello, world!', record.txtdata)
    assert_equal(60, record.ttl)
  end

  def test_build_long_txt_from_api
    record = Provider::GoogleCloudDNS.send(
      :build_from_api,
      Google::Cloud::Dns::Record.new(
        'txt.dns-test.shopify.io.',
        'TXT',
        60,
        ['"' + "a" * 255 + '" "' + "a" * 45 + '"']
      )
    )

    assert_kind_of(Record::TXT, record)
    assert_equal('txt.dns-test.shopify.io.', record.fqdn)
    assert_equal('a' * 300, record.txtdata)
    assert_equal(60, record.ttl)
  end

  def test_build_soa_from_api
    record = Provider::GoogleCloudDNS.send(
      :build_from_api,
      Google::Cloud::Dns::Record.new(
        'dns-test.shopify.io.',
        'SOA',
        60,
        'ns-cloud-d1.googledomains.com. cloud-dns-hostmaster.google.com. 3 21600 3600 259200 300'
      )
    )

    assert_nil(record)
  end

  def test_apply_changeset_sets_state_to_match_changeset
    a_record = Record::A.new(fqdn: 'test-record.dns-test.shopify.io.', ttl: 86400, address: '10.10.10.42')

    VCR.use_cassette('gcloud_dns_apply_changeset') do
      Provider::GoogleCloudDNS.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [a_record],
        provider: RecordStore::Provider::GoogleCloudDNS,
        zone: @zone_name
      ))
    end
  end

  def test_retrieve_current_records_returns_array_of_records
    records_arr = [
      Record::NS.new(
        zone: 'dns-scratch.me',
        ttl: 21600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns-cloud-d1.googledomains.com.',
      ),
      Record::NS.new(
        zone: 'dns-scratch.me',
        ttl: 21600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns-cloud-d2.googledomains.com.',
      ),
      Record::NS.new(
        zone: 'dns-scratch.me',
        ttl: 21600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns-cloud-d3.googledomains.com.',
      ),
      Record::NS.new(
        zone: 'dns-scratch.me',
        ttl: 21600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns-cloud-d4.googledomains.com.',
      ),
      Record::MX.new(
        zone: 'dns-scratch.me',
        ttl: 300,
        fqdn: 'dns-scratch.me',
        exchange: 'mail-server.example.com.',
        preference: 10,
      ),
      Record::MX.new(
        zone: 'dns-scratch.me',
        ttl: 300,
        fqdn: 'dns-scratch.me',
        exchange: 'mail.example.com.',
        preference: 123
      ),
      Record::AAAA.new(
        zone: 'dns-scratch.me',
        ttl: 300,
        fqdn: 'aaaa.dns-scratch.me',
        address: '2001:db8:85a3::ea75:1337:beef'
      ),
      Record::CAA.new(
        zone: 'dns-scratch.me',
        ttl: 1800,
        fqdn: 'cname.dns-scratch.me',
        flags: 0,
        tag: 'issue',
        value: 'digicert.com',
      ),
      Record::CNAME.new(
        zone: 'dns-scratch.me',
        ttl: 300,
        fqdn: 'cname.dns-scratch.me',
        cname: 'example.com'
      ),
      Record::CNAME.new(
        zone: 'dns-scratch.me',
        ttl: 300,
        fqdn: 'cname-api.dns-scratch.me',
        cname: 'example.com'
      ),
      Record::A.new(
        zone: 'dns-scratch.me',
        ttl: 300,
        fqdn: 'test.dns-scratch.me',
        address: '127.0.0.1',
      ),
      Record::TXT.new(
        fqdn: 'txt.dns-scratch.me',
        zone: 'dns-scratch.me',
        ttl: 300,
        txtdata: 'test'
      ),
      Record::TXT.new(
        fqdn: 'txt.dns-scratch.me',
        zone: 'dns-scratch.me',
        ttl: 300,
        txtdata: 'asdf'
      ),
      Record::A.new(
        zone: 'dns-scratch.me',
        ttl: 86400,
        fqdn: 'www.dns-scratch.me',
        address: '1.2.3.4',
      ),
    ].sort_by(&:to_s)

    VCR.use_cassette('gcloud_dns_retrieve_current_records') do
      records = Provider::GoogleCloudDNS.retrieve_current_records(zone: 'dns-scratch.me').sort_by(&:to_s)
      assert_equal(records_arr, records)
    end
  end

  def test_zones_returns_list_of_zones_managed_by_provider
    VCR.use_cassette('gcloud_dns_zones') do
      assert_equal(Provider::GoogleCloudDNS.zones, ['dns-scratch.me.'])
    end
  end

  def test_gcloud_dns_is_thawable
    refute_predicate(Provider::GoogleCloudDNS, :thawable?)
  end

  def test_gcloud_dns_is_freezable
    refute_predicate(Provider::GoogleCloudDNS, :freezable?)
  end
end
