require 'test_helper'

class DynECTTest < Minitest::Test
  def setup
    super
    @zone_name = 'dns-test.shopify.io'
  end

  def test_supports_alias_by_default
    refute_predicate(Provider::DynECT, :supports_alias?)
  end

  def test_build_a_from_api
    record = Provider::DynECT.send(
      :build_from_api,
      'zone' => 'dns-test.shopify.io',
      'fqdn' => 'test.dns-test.shopify.io',
      'record_type' => 'A',
      'ttl' => 600,
      'rdata' => {
        'address' => '10.11.12.13',
      }
    )

    assert_kind_of(Record::A, record)
    assert_equal('test.dns-test.shopify.io.', record.fqdn)
    assert_equal('10.11.12.13', record.address)
    assert_equal(600, record.ttl)
  end

  def test_build_aaaa_from_api
    record = Provider::DynECT.send(
      :build_from_api,
      "zone" => "dns-test.shopify.io",
      "ttl" => 60,
      "fqdn" => "aaaa.dns-test.shopify.io",
      "record_type" => "AAAA",
      "rdata" => {
        "address" => "2001:0db8:85a3:0000:0000:EA75:1337:BEEF",
      }
    )

    assert_kind_of(Record::AAAA, record)
    assert_equal('aaaa.dns-test.shopify.io.', record.fqdn)
    assert_equal('2001:0db8:85a3:0000:0000:EA75:1337:BEEF', record.address)
    assert_equal(60, record.ttl)
  end

  def test_build_alias_from_api
    api_record = {
      'zone' => 'dns-test.shopify.io',
      'ttl' => 60,
      'fqdn' => 'dns-test.shopify.io',
      'record_type' => 'ALIAS',
      'rdata' => {
        'alias' => 'dns-test.herokuapp.com.',
      },
    }
    record = Provider::DynECT.send(:build_from_api, api_record)

    assert_kind_of(Record::ALIAS, record)
    assert_equal('dns-test.shopify.io.', record.fqdn)
    assert_equal('dns-test.herokuapp.com.', record.alias)
    assert_equal(60, record.ttl)
  end

  def test_build_caa_from_api
    record = Provider::DynECT.send(
      :build_from_api,
      "zone" => "dns-test.shopify.io",
      "ttl" => 1800,
      "fqdn" => "cname.dns-test.shopify.io",
      "record_type" => "CAA",
      "rdata" => {
        "tag": "issue",
        "flags": 0,
        "value": "digicert.com",
      }
    )

    assert_kind_of(Record::CAA, record)
    assert_equal('cname.dns-test.shopify.io.', record.fqdn)
    assert_equal(0, record.flags)
    assert_equal('issue', record.tag)
    assert_equal('digicert.com', record.value)
    assert_equal(1800, record.ttl)
  end

  def test_build_cname_from_api
    record = Provider::DynECT.send(
      :build_from_api,
      "zone" => "dns-test.shopify.io",
      "ttl" => 60,
      "fqdn" => "cname.dns-test.shopify.io",
      "record_type" => "CNAME",
      "rdata" => {
        "cname" => "dns-test.shopify.io.",
      }
    )

    assert_kind_of(Record::CNAME, record)
    assert_equal('cname.dns-test.shopify.io.', record.fqdn)
    assert_equal('dns-test.shopify.io.', record.cname)
    assert_equal(60, record.ttl)
  end

  def test_build_mx_from_api
    record = Provider::DynECT.send(
      :build_from_api,
      "zone" => "dns-test.shopify.io",
      "ttl" => 60,
      "fqdn" => "mx.dns-test.shopify.io",
      "record_type" => "MX",
      "rdata" => {
        "exchange" => "mail-server.example.com.",
        "preference" => 10,
      }
    )

    assert_kind_of(Record::MX, record)
    assert_equal('mx.dns-test.shopify.io.', record.fqdn)
    assert_equal('mail-server.example.com.', record.exchange)
    assert_equal(10, record.preference)
    assert_equal(60, record.ttl)
  end

  def test_build_ns_from_api
    record = Provider::DynECT.send(
      :build_from_api,
      "zone" => "dns-test.shopify.io",
      "ttl" => 3600,
      "fqdn" => "dns-test.shopify.io",
      "record_type" => "NS",
      "rdata" => {
        "nsdname" => "ns1.dynect.net",
      }
    )

    assert_kind_of(Record::NS, record)
    assert_equal('dns-test.shopify.io.', record.fqdn)
    assert_equal('ns1.dynect.net.', record.nsdname)
    assert_equal(3600, record.ttl)
  end

  def test_build_srv_from_api
    record = Provider::DynECT.send(
      :build_from_api,
      "zone" => "dns-test.shopify.io",
      "ttl" => 60,
      "fqdn" => "_service._TCP.srv.dns-test.shopify.io",
      "record_type" => "SRV",
      "rdata" => {
        "port" => 80,
        "priority" => 10,
        "target" => "target-srv.dns-test.shopify.io.",
        "weight" => 47,
      }
    )

    assert_kind_of(Record::SRV, record)
    assert_equal('_service._tcp.srv.dns-test.shopify.io.', record.fqdn)
    assert_equal(10, record.priority)
    assert_equal(47, record.weight)
    assert_equal(80, record.port)
    assert_equal('target-srv.dns-test.shopify.io.', record.target)
    assert_equal(60, record.ttl)
  end

  def test_build_soa_from_api
    record = Provider::DynECT.send(
      :build_from_api,
      "zone" => "dns-test.shopify.io",
      "ttl" => 3600,
      "fqdn" => "dns-test.shopify.io",
      "record_type" => "SOA",
      "serial_style" => "increment",
      "rdata" => {
        "rname" => "postmaster@dns-test.shopify.io.",
        "retry" => 600,
        "mname" => "ns1.dynect.net.",
        "minimum" => 1800,
        "refresh" => 3600,
        "expire" => 604800,
        "serial" => 1241,
      }
    )

    assert_nil(record)
  end

  def test_long_txt_api_rdata
    record = Record::TXT.new(fqdn: 'example.com.', ttl: 600, txtdata: "a" * 300)
    txt = Provider::DynECT.send(:api_rdata, record)
    assert_equal({ txtdata: '"' + "a" * 255 + '" "' + "a" * 45 + '"' }, txt)
  end

  def test_build_long_txt_from_api
    record = Provider::DynECT.send(
      :build_from_api,
      "zone" => "dns-test.shopify.io",
      "ttl" => 60,
      "fqdn" => "txt.dns-test.shopify.io",
      "record_type" => "TXT",
      "rdata" => {
        "txtdata" => '"' + "a" * 255 + '" "' + "a" * 45 + '"',
      },
    )

    assert_kind_of(Record::TXT, record)
    assert_equal('txt.dns-test.shopify.io.', record.fqdn)
    assert_equal("a" * 300, record.txtdata)
    assert_equal(60, record.ttl)
  end

  def test_build_txt_from_api
    record = Provider::DynECT.send(
      :build_from_api,
      "zone" => "dns-test.shopify.io",
      "ttl" => 60,
      "fqdn" => "txt.dns-test.shopify.io",
      "record_type" => "TXT",
      "rdata" => {
        "txtdata" => "Hello, world!",
      },
    )

    assert_kind_of(Record::TXT, record)
    assert_equal('txt.dns-test.shopify.io.', record.fqdn)
    assert_equal('Hello, world!', record.txtdata)
    assert_equal(60, record.ttl)
  end

  def test_build_txt_from_api_handles_mixed_case_fqdn
    record = Provider::DynECT.send(
      :build_from_api,
      "zone" => "dns-test.shopify.io",
      "ttl" => 60,
      "fqdn" => "Txt.dns-test.shopify.io",
      "record_type" => "TXT",
      "rdata" => {
        "txtdata" => "Hello, world!",
      },
    )

    assert_kind_of(Record::TXT, record)
    assert_equal('txt.dns-test.shopify.io.', record.fqdn)
    assert_equal('Hello, world!', record.txtdata)
    assert_equal(60, record.ttl)
  end

  def test_apply_changeset_sets_state_to_match_changeset
    a_record = Record::A.new(fqdn: 'test-record.dns-test.shopify.io.', ttl: 86400, address: '10.10.10.42')

    VCR.use_cassette('dynect_apply_changeset') do
      Provider::DynECT.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [a_record],
        provider: RecordStore::Provider::DynECT,
        zone: @zone_name
      ))
    end
  end

  def test_retrieve_current_records_returns_array_of_records
    records_arr = [
      Record::NS.new(
        zone: 'dns-test.shopify.io',
        ttl: 86400,
        fqdn: 'dns-test.shopify.io',
        nsdname: 'ns1.p19.dynect.net.',
        record_id: 164537804
      ),
      Record::NS.new(
        zone: 'dns-test.shopify.io',
        ttl: 86400,
        fqdn: 'dns-test.shopify.io',
        nsdname: 'ns2.p19.dynect.net.',
        record_id: 164537805
      ),
      Record::NS.new(
        zone: 'dns-test.shopify.io',
        ttl: 86400,
        fqdn: 'dns-test.shopify.io',
        nsdname: 'ns3.p19.dynect.net.',
        record_id: 164537806
      ),
      Record::NS.new(
        zone: 'dns-test.shopify.io',
        ttl: 86400,
        fqdn: 'dns-test.shopify.io',
        nsdname: 'ns4.p19.dynect.net.',
        record_id: 164537807
      ),
      Record::A.new(
        zone: 'dns-test.shopify.io',
        ttl: 86400,
        fqdn: 'test-record.dns-test.shopify.io',
        address: '10.10.10.10',
        record_id: 189358987
      ),
      Record::ALIAS.new(
        zone: 'dns-test.shopify.io',
        ttl: 60,
        fqdn: 'dns-test.shopify.io',
        alias: 'dns-test.herokuapp.com.',
        record_id: 164537809
      ),
    ]

    VCR.use_cassette('dynect_retrieve_current_records') do
      records = Provider::DynECT.retrieve_current_records(zone: @zone_name)
      assert_equal records_arr, records
    end
  end

  def test_apply_changeset_updates_specific_record
    txt_1 = Record::TXT.new(record_id: 12345678, fqdn: 'test-record.dns-test.shopify.io.', ttl: 3600, txtdata: "one")
    txt_2 = Record::TXT.new(record_id: 99999999, fqdn: 'test-record.dns-test.shopify.io.', ttl: 3600, txtdata: "two")
    txt_update = Record::TXT.new(fqdn: 'test-record.dns-test.shopify.io.', ttl: 3600, txtdata: "update")

    VCR.use_cassette('dynect_apply_changeset_update') do
      Provider::DynECT.apply_changeset(Changeset.new(
        current_records: [txt_1, txt_2],
        desired_records: [txt_update, txt_2],
        provider: RecordStore::Provider::DynECT,
        zone: @zone_name
      ))
    end
  end

  def test_zones_returns_list_of_zones_managed_by_provider
    VCR.use_cassette('dynect_zones') do
      assert_equal Provider::DynECT.zones, [@zone_name]
    end
  end

  def test_dynect_is_thawable
    assert_predicate(Provider::DynECT, :thawable?)
  end

  def test_dynect_is_freezable
    assert_predicate(Provider::DynECT, :freezable?)
  end
end
