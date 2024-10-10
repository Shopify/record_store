require 'test_helper'

class CloudflareTest < Minitest::Test
  def setup
    super
    @zone_name = 'record-store-dns-tests.shopitest.com'
    @cloudflare = Provider::Cloudflare
  end

  def test_zones
    VCR.use_cassette('cloudflare_test_zones') do
      zones = @cloudflare.zones
      assert_includes(zones, @zone_name)
    end
  end

  def test_build_a_from_api
    api_record = {
      "id" => "e4b2b841a1126746d255275c2f1aa41",
      "zone_id" => "1a234bc567dea8a9b01251e19abcde8a",
      "zone_name" => "record-store-dns-tests.shopitest.com",
      "name" => "www.record-store-dns-tests.shopitest.com",
      "type" => "A",
      "content" => "192.0.2.1",
      "ttl" => 1,
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::A, record)
    assert_equal('www.record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal('192.0.2.1', record.address)
    assert_equal(1, record.ttl)
  end

  def test_build_caa_from_api
    api_record = {
      "id" => "123458",
      "type" => "CAA",
      "name" => "secure.record-store-dns-tests.shopitest.com",
      "content" => "0 issue \"letsencrypt.org\"",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::CAA, record)
    assert_equal('secure.record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal(0, record.flags)
    assert_equal('issue', record.tag)
    assert_equal('letsencrypt.org', record.value)
    assert_equal(3600, record.ttl)
  end

  def test_build_cname_from_api
    api_record = {
      "id" => "e4b2b841a1126746d255275c2f1aa41",
      "zone_id" => "1a234bc567dea8a9b01251e19abcde8a",
      "zone_name" => "record-store-dns-tests.shopitest.com",
      "name" => "shopify.record-store-dns-tests.shopitest.com",
      "type" => "CNAME",
      "content" => "shopify.com",
      "ttl" => 1,
      "settings" => { "flatten_cname" => false }
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::CNAME, record)
    assert_equal('shopify.record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal('shopify.com.', record.cname)
    assert_equal(1, record.ttl)
  end

  def test_build_mx_from_api
    api_record = {
      "id" => "123460",
      "type" => "MX",
      "name" => "mail",
      "content" => "mail.record-store-dns-tests.shopitest.com",
      "ttl" => 3600,
      "priority" => 10
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::MX, record)
    assert_equal('mail.record-store-dns-tests.shopitest.com.', record.exchange)
    assert_equal(10, record.preference)
    assert_equal(3600, record.ttl)
  end

  def test_build_ns_from_api
    api_record = {
      "id" => "123461",
      "type" => "NS",
      "name" => "ns.record-store-dns-tests.shopitest.com",
      "content" => "cory.ns.cloudflare.com",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::NS, record)
    assert_equal('ns.record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal('cory.ns.cloudflare.com.', record.nsdname)
    assert_equal(3600, record.ttl)
  end

  def test_build_ptr_from_api
    api_record = {
      "id" => "123462",
      "type" => "PTR",
      "name" => "4.3.2.1.in-addr.arpa",
      "content" => "host.record-store-dns-tests.shopitest.com",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::PTR, record)
    assert_equal('host.record-store-dns-tests.shopitest.com.', record.ptrdname)
    assert_equal(3600, record.ttl)
  end

  def test_build_txt_from_api
    api_record = {
      "id" => "123465",
      "type" => "TXT",
      "name" => "record-store-dns-tests.shopitest.com",
      "content" => "v=spf1 ip4:192.0.2.0; \"Hello, world!\"",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::TXT, record)
    assert_equal('record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal("v=spf1 ip4:192.0.2.0\\; \"Hello, world!\"", record.txtdata)
    assert_equal(3600, record.ttl)
  end

  def test_build_srv_from_api
    api_record = {
      "id" => "123466",
      "type" => "SRV",
      "name" => "_sip._tcp.record-store-dns-tests.shopitest.com",
      "content" => "50 5060 sipserver.record-store-dns-tests.shopitest.com",
      "priority" => "10",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::SRV, record)
    assert_equal('_sip._tcp.record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal(10, record.priority)
    assert_equal(50, record.weight)
    assert_equal(5060, record.port)
    assert_equal('sipserver.record-store-dns-tests.shopitest.com.', record.target)
    assert_equal(3600, record.ttl)
  end

  def test_build_alias_from_api
    api_record = {
      "id" => "123467",
      "type" => "CNAME",
      "name" => "alias.record-store-dns-tests.shopitest.com",
      "content" => "target.record-store-dns-tests.shopitest.com",
      "ttl" => 3600,
      "settings" => { "flatten_cname" => true }
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::ALIAS, record)
    assert_equal('alias.record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal('target.record-store-dns-tests.shopitest.com.', record.alias)
    assert_equal(3600, record.ttl)
  end

  def test_add_changeset
    VCR.use_cassette('cloudflare_test_add_changeset') do
      record = Record::A.new(fqdn: 'add.record-store-dns-tests.shopitest.com', ttl: 600, address: '192.0.2.1')
      changeset = Changeset.new(current_records: [], desired_records: [record], provider: @cloudflare, zone: @zone_name)

      @cloudflare.apply_changeset(changeset)
      assert_includes(@cloudflare.retrieve_current_records(zone: @zone_name), record)
    end
  end

  def test_add_multiple_changesets
    VCR.use_cassette('cloudflare_test_add__multiple_changesets') do
      records = [
        Record::A.new(fqdn: 'multi1.record-store-dns-tests.shopitest.com', ttl: 600, address: '192.0.2.1'),
        Record::A.new(fqdn: 'multi2.record-store-dns-tests.shopitest.com', ttl: 600, address: '192.0.2.2')
      ]
      changeset = Changeset.new(current_records: [], desired_records: records, provider: @cloudflare, zone: @zone_name)

      @cloudflare.apply_changeset(changeset)
      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      records.each do |record|
        assert_includes(retrieved_records, record)
      end
    end
  end

  def test_remove_changeset
    VCR.use_cassette('cloudflare_test_remove_changeset') do
      target_fqdn = 'remove.record-store-dns-tests.shopitest.com'
      record = Record::A.new(fqdn: target_fqdn, ttl: 600, address: '192.0.2.1')

      @cloudflare.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      matching_record = retrieved_records.find { |record| record.fqdn == "#{target_fqdn}." }
      record_with_id = Record::A.new(fqdn: target_fqdn, ttl: 600, address: '192.0.2.1', record_id: matching_record.id)

      @cloudflare.apply_changeset(Changeset.new(
        current_records: [record_with_id],
        desired_records: [],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      refute_includes(retrieved_records, record_with_id)
      refute_includes(retrieved_records, record)
    end
  end

  def test_update_changeset
    VCR.use_cassette('cloudflare_test_update_changeset') do
      target_fqdn = 'update.record-store-dns-tests.shopitest.com'
      record = Record::A.new(fqdn: target_fqdn, ttl: 600, address: '192.0.2.1')
      updated_record = record.dup
      updated_record.address = '192.0.2.2'

      @cloudflare.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      matching_record = retrieved_records.find { |record| record.fqdn == "#{target_fqdn}." }
      record.id = matching_record.id

      @cloudflare.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [updated_record],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      assert_includes(retrieved_records, updated_record)
      refute_includes(retrieved_records, record)
    end
  end

  def test_update_changeset_where_domain_doesnt_exist
    VCR.use_cassette('cloudflare_test_update_changeset_where_domain_doesnt_exist') do
      record = Record::A.new(fqdn: 'nonexistent.record-store-dns-tests.shopitest.com', ttl: 600, address: '192.0.2.1')
      updated_record = record.dup
      updated_record.address = '192.0.2.2'
      record.id = '12345'

      assert_raises(RecordStore::Provider::Cloudflare::Error) do
        @cloudflare.apply_changeset(Changeset.new(
          current_records: [record],
          desired_records: [updated_record],
          provider: @cloudflare,
          zone: @zone_name,
        ))
      end
    end
  end

  def test_updating_record_ttl
    VCR.use_cassette('cloudflare_test_updating_record_ttl') do
      target_fqdn = 'ttlupdate.record-store-dns-tests.shopitest.com'
      record = Record::A.new(fqdn: target_fqdn, ttl: 600, address: '192.0.2.1')
      updated_record = record.dup
      updated_record.ttl = 3600

      @cloudflare.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      matching_record = retrieved_records.find { |record| record.fqdn == "#{target_fqdn}." }
      record.id = matching_record.id

      @cloudflare.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [updated_record],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      updated_retrieved_record = retrieved_records.find { |r| r.fqdn == record.fqdn }
      assert_equal(3600, updated_retrieved_record.ttl)
    end
  end

  def test_alias_record_retrieved_after_adding_record_changeset
    VCR.use_cassette('cloudflare_test_alias_record_retrieved_after_adding_record_changeset') do
      record = Record::ALIAS.new(
        fqdn: 'alias.record-store-dns-tests.shopitest.com',
        ttl: 600,
        alias: 'target.record-store-dns-tests.shopitest.com',
      )
      @cloudflare.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @cloudflare,
        zone: @zone_name,
      ))
      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      assert_includes(retrieved_records, record)
    end
  end

  def test_remove_record_should_not_remove_all_records_for_fqdn
    VCR.use_cassette('cloudflaretest_remove_record_should_not_remove_all_records_for_fqdn') do
      target_fqdn = 'multi.record-store-dns-tests.shopitest.com'
      record1 = Record::A.new(fqdn: target_fqdn, ttl: 600, address: '192.0.2.1')
      record2 = Record::A.new(fqdn: target_fqdn, ttl: 600, address: '192.0.2.2')
      @cloudflare.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record1, record2],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)

      matching_record1 = retrieved_records.find do |record|
        record.fqdn == "#{target_fqdn}." && record.address == '192.0.2.1'
      end
      record1.id = matching_record1.id

      matching_record2 = retrieved_records.find do |record|
        record.fqdn == "#{target_fqdn}." && record.address == '192.0.2.2'
      end
      record2.id = matching_record2.id

      @cloudflare.apply_changeset(Changeset.new(
        current_records: [record1, record2],
        desired_records: [record1],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      assert_includes(retrieved_records, record1)
      refute_includes(retrieved_records, record2)
    end
  end
end
