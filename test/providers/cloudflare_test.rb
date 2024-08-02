require 'test_helper'

class CloudflareTest < Minitest::Test
  def setup
    super
    # TODO: Remove this skip line
    skip("Implementation pending")
    @zone_name = 'example.com'
    @cloudflare = Provider::Cloudflare
  end

  def test_build_aaaa_from_api
    api_record = {
      "id" => "123457",
      "type" => "AAAA",
      "name" => "aaaa",
      "content" => "2606:2800:220:1:248:1893:25c8:1946",
      "ttl" => 3600,
      "proxied" => false
    }

    record = @cloudflare.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::AAAA, record)
    assert_equal('aaaa.example.com.', record.fqdn)
    assert_equal('2606:2800:220:1:248:1893:25c8:1946', record.address)
    assert_equal(3600, record.ttl)
  end

  def test_build_caa_from_api
    api_record = {
      "id" => "123458",
      "type" => "CAA",
      "name" => "secure",
      "content" => "0 issue \"letsencrypt.org\"",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::CAA, record)
    assert_equal('secure.example.com.', record.fqdn)
    assert_equal(0, record.flags)
    assert_equal('issue', record.tag)
    assert_equal('letsencrypt.org', record.value)
    assert_equal(3600, record.ttl)
  end

  def test_build_cname_from_api
    api_record = {
      "id" => "123459",
      "type" => "CNAME",
      "name" => "www",
      "content" => "example.com",
      "ttl" => 3600,
      "proxied" => true
    }

    record = @cloudflare.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::CNAME, record)
    assert_equal('www.example.com.', record.fqdn)
    assert_equal('example.com.', record.cname)
    assert_equal(3600, record.ttl)
  end

  def test_build_mx_from_api
    api_record = {
      "id" => "123460",
      "type" => "MX",
      "name" => "mail",
      "content" => "mail.example.com",
      "ttl" => 3600,
      "priority" => 10
    }

    record = @cloudflare.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::MX, record)
    assert_equal('mail.example.com.', record.exchange)
    assert_equal(10, record.preference)
    assert_equal(3600, record.ttl)
  end

  def test_build_ns_from_api
    api_record = {
      "id" => "123461",
      "type" => "NS",
      "name" => "",
      "content" => "ns1.cloudflare.com",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::NS, record)
    assert_equal('example.com.', record.fqdn)
    assert_equal('ns1.cloudflare.com.', record.nsdname)
    assert_equal(3600, record.ttl)
  end

  def test_build_ptr_from_api
    api_record = {
      "id" => "123462",
      "type" => "PTR",
      "name" => "4.3.2.1.in-addr.arpa",
      "content" => "host.example.com",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::PTR, record)
    assert_equal('host.example.com.', record.ptrdname)
    assert_equal(3600, record.ttl)
  end

  def test_build_sshfp_from_api
    api_record = {
      "id" => "123463",
      "type" => "SSHFP",
      "name" => "_sshfp1",
      "content" => "1 1 123456789abcdef67890123456789abcdef67890",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::SSHFP, record)
    assert_equal(Record::SSHFP::Algorithms::RSA, record.algorithm)
    assert_equal(Record::SSHFP::FingerprintTypes::SHA_1, record.fptype)
    assert_equal('123456789abcdef67890123456789abcdef67890', record.fingerprint)
    assert_equal(3600, record.ttl)
  end

  def test_build_spf_from_api
    api_record = {
      "id" => "123464",
      "type" => "SPF",
      "name" => "spf",
      "content" => "\"v=spf1 include:example.com ~all\"",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::SPF, record)
    assert_equal('spf.example.com.', record.fqdn)
    assert_equal("\"v=spf1 include:example.com ~all\"", record.txtdata)
    assert_equal(3600, record.ttl)
  end

  def test_build_txt_from_api
    api_record = {
      "id" => "123465",
      "type" => "TXT",
      "name" => "txt",
      "content" => "\"Hello, world!\"",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::TXT, record)
    assert_equal('txt.example.com.', record.fqdn)
    assert_equal("\"Hello, world!\"", record.txtdata)
    assert_equal(3600, record.ttl)
  end

  def test_build_srv_from_api
    api_record = {
      "id" => "123466",
      "type" => "SRV",
      "name" => "_sip._tcp",
      "content" => "10 50 5060 sipserver.example.com",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::SRV, record)
    assert_equal('_sip._tcp.example.com.', record.fqdn)
    assert_equal(10, record.priority)
    assert_equal(50, record.weight)
    assert_equal(5060, record.port)
    assert_equal('sipserver.example.com.', record.target)
    assert_equal(3600, record.ttl)
  end

  # Tests for applying changesets and retrieving records
  def test_apply_changeset
    record = Record::A.new(fqdn: 'apply.example.com', ttl: 600, address: '192.0.2.1')
    changeset = Changeset.new(current_records: [], desired_records: [record], provider: @cloudflare, zone: @zone_name)

    @cloudflare.apply_changeset(changeset)
    assert_includes(@cloudflare.retrieve_current_records(zone: @zone_name), record)
  end

  def test_retrieve_current_records_returns_array_of_records
    records = @cloudflare.retrieve_current_records(zone: @zone_name)
    assert_kind_of(Array, records)
    records.each do |record|
      assert_kind_of(Record, record)
    end
  end

  def test_zones
    zones = @cloudflare.zones
    assert_includes(zones, @zone_name)
  end

  def test_add_changeset
    record = Record::A.new(fqdn: 'add.example.com', ttl: 600, address: '192.0.2.1')
    changeset = Changeset.new(current_records: [], desired_records: [record], provider: @cloudflare, zone: @zone_name)

    @cloudflare.apply_changeset(changeset)
    assert_includes(@cloudflare.retrieve_current_records(zone: @zone_name), record)
  end

  def test_add_multiple_changesets
    records = [
      Record::A.new(fqdn: 'multi1.example.com', ttl: 600, address: '192.0.2.1'),
      Record::A.new(fqdn: 'multi2.example.com', ttl: 600, address: '192.0.2.2')
    ]
    changeset = Changeset.new(current_records: [], desired_records: records, provider: @cloudflare, zone: @zone_name)

    @cloudflare.apply_changeset(changeset)
    retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
    records.each do |record|
      assert_includes(retrieved_records, record)
    end
  end

  def test_remove_changeset
    record = Record::A.new(fqdn: 'remove.example.com', ttl: 600, address: '192.0.2.1')
    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    ))
    @cloudflare.apply_changeset(Changeset.new(
      current_records: [record],
      desired_records: [],
      provider: @cloudflare,
      zone: @zone_name,
    ))

    retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
    refute_includes(retrieved_records, record)
  end

  def test_update_changeset
    record = Record::A.new(fqdn: 'update.example.com', ttl: 600, address: '192.0.2.1')
    updated_record = record.dup
    updated_record.address = '192.0.2.2'

    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    ))
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

  def test_update_changeset_where_domain_doesnt_exist
    record = Record::A.new(fqdn: 'nonexistent.example.com', ttl: 600, address: '192.0.2.1')
    updated_record = record.dup
    updated_record.address = '192.0.2.2'

    assert_raises(RecordStore::Provider::Cloudflare::Error) do
      @cloudflare.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [updated_record],
        provider: @cloudflare,
        zone: @zone_name,
      ))
    end
  end

  def test_apply_changeset_where_response_is_unparseable
    record = Record::A.new(fqdn: 'unparseable.example.com', ttl: 600, address: '192.0.2.1')
    @cloudflare.stub(:parse_response, nil) do
      assert_raises(RecordStore::Provider::UnparseableBodyError) do
        @cloudflare.apply_changeset(Changeset.new(
          current_records: [],
          desired_records: [record],
          provider: @cloudflare,
          zone: @zone_name,
        ))
      end
    end
  end

  def test_update_changeset_for_fqdn_with_multiple_answers
    records = [
      Record::A.new(fqdn: 'multi.example.com', ttl: 600, address: '192.0.2.1'),
      Record::A.new(fqdn: 'multi.example.com', ttl: 600, address: '192.0.2.2')
    ]
    updated_records = records.map(&:dup)
    updated_records[0].address = '192.0.2.3'

    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: records,
      provider: @cloudflare,
      zone: @zone_name,
    ))
    @cloudflare.apply_changeset(Changeset.new(
      current_records: records,
      desired_records: updated_records,
      provider: @cloudflare,
      zone: @zone_name,
    ))

    retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
    assert_includes(retrieved_records, updated_records[0])
    assert_includes(retrieved_records, updated_records[1])
  end

  def test_add_changeset_with_nil_zone
    record = Record::A.new(fqdn: 'nilzone.example.com', ttl: 600, address: '192.0.2.1')
    assert_raises(ArgumentError) do
      @cloudflare.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @cloudflare,
        zone: nil,
      ))
    end
  end

  def test_add_changeset_missing_zone
    record = Record::A.new(fqdn: 'missingzone.example.com', ttl: 600, address: '192.0.2.1')
    assert_raises(RecordStore::Provider::Cloudflare::ZoneNotFound) do
      @cloudflare.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @cloudflare,
        zone: 'missingzone.example.com',
      ))
    end
  end

  def test_record_retrieved_after_adding_record_changeset
    record = Record::A.new(fqdn: 'addedrecord.example.com', ttl: 600, address: '192.0.2.1')
    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    ))
    retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
    assert_includes(retrieved_records, record)
  end

  def test_updating_record_ttl
    record = Record::A.new(fqdn: 'ttlupdate.example.com', ttl: 600, address: '192.0.2.1')
    updated_record = record.dup
    updated_record.ttl = 3600

    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    ))
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

  def test_alias_record_retrieved_after_adding_record_changeset
    record = Record::ALIAS.new(fqdn: 'alias.example.com', ttl: 600, alias: 'target.example.com')
    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    ))
    retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
    assert_includes(retrieved_records, record)
  end

  def test_caa_record_retrieved_after_adding_record_changeset
    record = Record::CAA.new(fqdn: 'caa.example.com', ttl: 600, flags: 0, tag: 'issue', value: 'letsencrypt.org')
    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    ))
    retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
    assert_includes(retrieved_records, record)
  end

  def test_cname_record_retrieved_after_adding_record_changeset
    record = Record::CNAME.new(fqdn: 'cname.example.com', ttl: 600, cname: 'real.example.com')
    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    ))
    retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
    assert_includes(retrieved_records, record)
  end

  def test_mx_record_retrieved_after_adding_record_changeset
    record = Record::MX.new(fqdn: 'mx.example.com', ttl: 600, preference: 10, exchange: 'mail.example.com')
    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    ))
    retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
    assert_includes(retrieved_records, record)
  end

  def test_ns_record_retrieved_after_adding_record_changeset
    record = Record::NS.new(fqdn: 'ns.example.com', ttl: 600, nsdname: 'ns1.example.com')
    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    ))
    retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
    assert_includes(retrieved_records, record)
  end

  def test_txt_record_retrieved_after_adding_record_changeset
    record = Record::TXT.new(fqdn: 'txt.example.com', ttl: 600, txtdata: 'Hello World!')
    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    ))
    retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
    assert_includes(retrieved_records, record)
  end

  def test_spf_record_retrieved_after_adding_record_changeset
    record = Record::SPF.new(fqdn: 'spf.example.com', ttl: 600, txtdata: 'v=spf1 include:example.com ~all')
    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    ))
    retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
    assert_includes(retrieved_records, record)
  end

  def test_srv_record_retrieved_after_adding_record_changeset
    record = Record::SRV.new(
      fqdn: '_sip._tcp.example.com',
      ttl: 600,
      priority: 10,
      weight: 50,
      port: 5060,
      target: 'sipserver.example.com',
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

  def test_remove_record_should_not_remove_all_records_for_fqdn
    record1 = Record::A.new(fqdn: 'multi.example.com', ttl: 600, address: '192.0.2.1')
    record2 = Record::A.new(fqdn: 'multi.example.com', ttl: 600, address: '192.0.2.2')
    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record1, record2],
      provider: @cloudflare,
      zone: @zone_name,
    ))
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

  def test_creates_ptr_records
    record = Record::PTR.new(fqdn: '4.3.2.1.in-addr.arpa', ttl: 600, ptrdname: 'host.example.com')
    @cloudflare.apply_changeset(Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: '4.3.2.1.in-addr.arpa',
    ))
    retrieved_records = @cloudflare.retrieve_current_records(zone: '4.3.2.1.in-addr.arpa')
    assert_includes(retrieved_records, record)
  end
end
