require 'test_helper'

class DNSimpleTest < Minitest::Test
  def setup
    @zone_name = 'dns-scratch.me'
    @dnsimple = Provider::DNSimple.new(zone: @zone_name)
  end

  def test_build_a_from_api
    record = @dnsimple.send(:build_from_api, {
      "id" => 5199673,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "a",
      "content" => "8.8.8.8",
      "ttl" => 60,
      "prio" => nil,
      "record_type" => "A",
      "system_record" => false,
      "created_at" => "2015-12-11T16:30:17.380Z",
      "updated_at" => "2015-12-11T16:30:17.380Z"
    })

    assert_kind_of Record::A, record
    assert_equal 'a.dns-scratch.me.', record.fqdn
    assert_equal '8.8.8.8', record.address
    assert_equal 60, record.ttl
  end

  def test_build_aaaa_from_api
    record = @dnsimple.send(:build_from_api, {
      "id" => 5199674,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "aaaa",
      "content" => "2001:0db8:85a3:0000:0000:EA75:1337:BEEF",
      "ttl" => 60,
      "prio" => nil,
      "record_type" => "AAAA",
      "system_record" => false,
      "created_at" => "2015-12-11T16:30:29.630Z",
      "updated_at" => "2015-12-11T16:30:29.630Z"
    })

    assert_kind_of Record::AAAA, record
    assert_equal 'aaaa.dns-scratch.me.', record.fqdn
    assert_equal '2001:0db8:85a3:0000:0000:EA75:1337:BEEF', record.address
    assert_equal 60, record.ttl
  end

  def test_build_alias_from_api
    record = @dnsimple.send(:build_from_api, {
      "id" => 5196953,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "alias",
      "content" => "dns-scratch.me",
      "ttl" => 60,
      "prio" => nil,
      "record_type" => "ALIAS",
      "system_record" => false,
      "created_at" => "2015-12-10T19:56:21.366Z",
      "updated_at" => "2015-12-10T19:56:21.366Z"
    })

    assert_kind_of Record::ALIAS, record
    assert_equal 'alias.dns-scratch.me.', record.fqdn
    assert_equal 'dns-scratch.me.', record.cname
    assert_equal 60, record.ttl
  end

  def test_build_cname_from_api
    record = @dnsimple.send(:build_from_api, {
      "id" => 5199675,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "cname",
      "content" => "dns-scratch.me",
      "ttl" => 60,
      "prio" => nil,
      "record_type" => "CNAME",
      "system_record" => false,
      "created_at" => "2015-12-11T16:30:41.284Z",
      "updated_at" => "2015-12-11T16:30:41.284Z"
    })

    assert_kind_of Record::CNAME, record
    assert_equal 'cname.dns-scratch.me.', record.fqdn
    assert_equal 'dns-scratch.me.', record.cname
    assert_equal 60, record.ttl
  end

  def test_build_mx_from_api
    record = @dnsimple.send(:build_from_api, {
      "id" => 5196959,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "mx",
      "content" => "mail-server.example.com",
      "ttl" => 60,
      "prio" => 10,
      "record_type" => "MX",
      "system_record" => false,
      "created_at" => "2015-12-10T19:58:20.474Z",
      "updated_at" => "2015-12-11T16:31:06.956Z"
    })

    assert_kind_of Record::MX, record
    assert_equal 'mx.dns-scratch.me.', record.fqdn
    assert_equal 'mail-server.example.com.', record.exchange
    assert_equal 10, record.preference
    assert_equal 60, record.ttl
  end

  def test_build_ns_from_api
    record = @dnsimple.send(:build_from_api, {
      "id" => 5190382,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "",
      "content" => "ns1.dnsimple.com",
      "ttl" => 3600,
      "prio" => nil,
      "record_type" => "NS",
      "system_record" => true,
      "created_at" => "2015-12-09T01:55:04.792Z",
      "updated_at" => "2015-12-09T01:55:04.792Z"
    })

    assert_kind_of Record::NS, record
    assert_equal 'dns-scratch.me.', record.fqdn
    assert_equal 'ns1.dnsimple.com.', record.nsdname
    assert_equal 3600, record.ttl
  end

  def test_build_srv_from_api
    record = @dnsimple.send(:build_from_api, {
      "id" => 5199683,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "_service._TCP.srv",
      "content" => "47 80 target-srv.dns-scratch.me",
      "ttl" => 60,
      "prio" => 10,
      "record_type" => "SRV",
      "system_record" => false,
      "created_at" => "2015-12-11T16:33:10.947Z",
      "updated_at" => "2015-12-11T16:33:10.947Z"
    })

    assert_kind_of Record::SRV, record
    assert_equal '_service._TCP.srv.dns-scratch.me.', record.fqdn
    assert_equal 10, record.priority
    assert_equal '47', record.weight
    assert_equal '80', record.port
    assert_equal 'target-srv.dns-scratch.me.', record.target
    assert_equal 60, record.ttl
  end

  def test_build_soa_from_api
    record = @dnsimple.send(:build_from_api, {
      "id" => 644621,
      "zone_id" => 11851,
      "parent_id" => nil,
      "name" => "",
      "value" => "ns1.dnsimple.com admin.dnsimple.com 2013021901 86400 7200 604800 300",
      "ttl" => 3600,
      "prio" => nil,
      "record_type" => "SOA",
      "system_record" => true,
      "created_at" => "2013-02-19T22:58:25.148Z",
      "updated_at" => "2013-02-19T22:58:38.751Z"
    })

    assert_nil record
  end

  def test_build_txt_from_api
    record = @dnsimple.send(:build_from_api, {
      "id" => 5199689,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "txt",
      "content" => "Hello, world!",
      "ttl" => 60,
      "prio" => nil,
      "record_type" => "TXT",
      "system_record" => false,
      "created_at" => "2015-12-11T16:36:26.504Z",
      "updated_at" => "2015-12-11T16:36:26.504Z"
    })

    assert_kind_of Record::TXT, record
    assert_equal 'txt.dns-scratch.me.', record.fqdn
    assert_equal 'Hello, world!', record.txtdata
    assert_equal 60, record.ttl
  end

  def test_apply_changeset_sets_state_to_match_changeset
    a_record = Record::A.new(fqdn: 'test-record.dns-scratch.me.', ttl: 86400, address: '10.10.10.42')

    VCR.use_cassette 'dnsimple_apply_changeset' do
      @dnsimple.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [a_record]
      ))
    end
  end

  def test_apply_changeset_with_alias_cleans_up_txt_record
    alias_record = Record::ALIAS.new(fqdn: 'dns-scratch.me.', ttl: 86400, cname: 'alias.dns-scratch.me.')

    VCR.use_cassette 'dnsimple_apply_changeset_with_alias' do
      @dnsimple.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [alias_record]
      ))

      records = @dnsimple.retrieve_current_records
      refute_includes records.map(&:type), 'TXT'
      assert_includes records.map(&:type), 'ALIAS'
    end
  end

  def test_retrieve_current_records_returns_array_of_records
    records_arr = [
      Record::A.new({
        zone: 'dns-scratch.me',
        ttl: 86400,
        fqdn: 'test-record.dns-scratch.me',
        address: '10.10.10.42',
        record_id: 5207716
      }),
      Record::NS.new({
        zone: 'dns-scratch.me',
        ttl: 3600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns4.dnsimple.com.',
        record_id: 5190385
      }),
      Record::NS.new({
        zone: 'dns-scratch.me',
        ttl: 3600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns3.dnsimple.com.',
        record_id: 5190384
      }),
      Record::NS.new({
        zone: 'dns-scratch.me',
        ttl: 3600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns2.dnsimple.com.',
        record_id: 5190383
      }),
      Record::NS.new({
        zone: 'dns-scratch.me',
        ttl: 3600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns1.dnsimple.com.',
        record_id: 5190382
      }),
    ]

    VCR.use_cassette 'dnsimple_retrieve_current_records' do
      records = @dnsimple.retrieve_current_records
      assert_equal records, records_arr
    end
  end

  def test_zones_returns_list_of_zones_managed_by_provider
    VCR.use_cassette 'dnsimple_zones' do
      assert_equal @dnsimple.zones, [@zone_name]
    end
  end

  def test_dnsimple_is_not_thawable
    refute_predicate @dnsimple, :thawable?
  end

  def test_dnsimple_is_not_freezable
    refute_predicate @dnsimple, :freezable?
  end
end
