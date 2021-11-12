require 'test_helper'

class DNSimpleTest < Minitest::Test
  def setup
    super
    @zone_name = 'dns-scratch.me'
    @dnsimple = Provider::DNSimple
  end

  def test_supports_alias_by_default
    assert_predicate(Provider::DNSimple, :supports_alias?)
  end

  def test_build_a_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 5199673,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "a",
      "content" => "8.8.8.8",
      "ttl" => 60,
      "priority" => nil,
      "type" => "A",
      "system_record" => false,
      "created_at" => "2015-12-11T16:30:17.380Z",
      "updated_at" => "2015-12-11T16:30:17.380Z"
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::A, record)
    assert_equal('a.dns-scratch.me.', record.fqdn)
    assert_equal('8.8.8.8', record.address)
    assert_equal(60, record.ttl)
  end

  def test_build_aaaa_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 5199674,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "aaaa",
      "content" => "2001:0db8:85a3:0000:0000:EA75:1337:BEEF",
      "ttl" => 60,
      "priority" => nil,
      "type" => "AAAA",
      "system_record" => false,
      "created_at" => "2015-12-11T16:30:29.630Z",
      "updated_at" => "2015-12-11T16:30:29.630Z"
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::AAAA, record)
    assert_equal('aaaa.dns-scratch.me.', record.fqdn)
    assert_equal('2001:0db8:85a3:0000:0000:EA75:1337:BEEF', record.address)
    assert_equal(60, record.ttl)
  end

  def test_build_alias_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 5196953,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "",
      "content" => "dns-scratch.herokuapp.com",
      "ttl" => 60,
      "priority" => nil,
      "type" => "ALIAS",
      "system_record" => false,
      "created_at" => "2015-12-10T19:56:21.366Z",
      "updated_at" => "2015-12-10T19:56:21.366Z"
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::ALIAS, record)
    assert_equal('dns-scratch.me.', record.fqdn)
    assert_equal('dns-scratch.herokuapp.com.', record.alias)
    assert_equal(60, record.ttl)
  end

  def test_build_caa_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 5199675,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "cname",
      "content": "0 issue \"digicert.com\"",
      "ttl" => 1800,
      "priority" => nil,
      "type": "CAA",
      "system_record" => false,
      "created_at" => "2015-12-11T16:30:41.284Z",
      "updated_at" => "2015-12-11T16:30:41.284Z"
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::CAA, record)
    assert_equal('cname.dns-scratch.me.', record.fqdn)
    assert_equal(0, record.flags)
    assert_equal('issue', record.tag)
    assert_equal('digicert.com', record.value)
    assert_equal(1800, record.ttl)
  end

  def test_build_cname_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 5199675,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "cname",
      "content" => "dns-scratch.me",
      "ttl" => 60,
      "priority" => nil,
      "type" => "CNAME",
      "system_record" => false,
      "created_at" => "2015-12-11T16:30:41.284Z",
      "updated_at" => "2015-12-11T16:30:41.284Z"
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::CNAME, record)
    assert_equal('cname.dns-scratch.me.', record.fqdn)
    assert_equal('dns-scratch.me.', record.cname)
    assert_equal(60, record.ttl)
  end

  def test_build_mx_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 5196959,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "mx",
      "content" => "mail-server.example.com",
      "ttl" => 60,
      "priority" => 10,
      "type" => "MX",
      "system_record" => false,
      "created_at" => "2015-12-10T19:58:20.474Z",
      "updated_at" => "2015-12-11T16:31:06.956Z"
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::MX, record)
    assert_equal('mx.dns-scratch.me.', record.fqdn)
    assert_equal('mail-server.example.com.', record.exchange)
    assert_equal(10, record.preference)
    assert_equal(60, record.ttl)
  end

  def test_build_ns_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 5190382,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "",
      "content" => "ns1.dnsimple.com",
      "ttl" => 3600,
      "priority" => nil,
      "type" => "NS",
      "system_record" => true,
      "created_at" => "2015-12-09T01:55:04.792Z",
      "updated_at" => "2015-12-09T01:55:04.792Z"
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::NS, record)
    assert_equal('dns-scratch.me.', record.fqdn)
    assert_equal('ns1.dnsimple.com.', record.nsdname)
    assert_equal(3600, record.ttl)
  end

  def test_build_srv_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 5199683,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "_service._TCP.srv",
      "content" => "47 80 target-srv.dns-scratch.me",
      "ttl" => 60,
      "priority" => 10,
      "type" => "SRV",
      "system_record" => false,
      "created_at" => "2015-12-11T16:33:10.947Z",
      "updated_at" => "2015-12-11T16:33:10.947Z"
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::SRV, record)
    assert_equal('_service._tcp.srv.dns-scratch.me.', record.fqdn)
    assert_equal(10, record.priority)
    assert_equal(47, record.weight)
    assert_equal(80, record.port)
    assert_equal('target-srv.dns-scratch.me.', record.target)
    assert_equal(60, record.ttl)
  end

  def test_build_soa_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 644621,
      "zone_id" => 11851,
      "parent_id" => nil,
      "name" => "",
      "value" => "ns1.dnsimple.com admin.dnsimple.com 2013021901 86400 7200 604800 300",
      "ttl" => 3600,
      "priority" => nil,
      "type" => "SOA",
      "system_record" => true,
      "created_at" => "2013-02-19T22:58:25.148Z",
      "updated_at" => "2013-02-19T22:58:38.751Z"
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_nil(record)
  end

  def test_build_txt_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 5199689,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "txt",
      "content" => "Hello, world!",
      "ttl" => 60,
      "priority" => nil,
      "type" => "TXT",
      "system_record" => false,
      "created_at" => "2015-12-11T16:36:26.504Z",
      "updated_at" => "2015-12-11T16:36:26.504Z"
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::TXT, record)
    assert_equal('txt.dns-scratch.me.', record.fqdn)
    assert_equal('Hello, world!', record.txtdata)
    assert_equal(60, record.ttl)
  end

  def test_build_long_txt_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 5199689,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "txt",
      "content" => "a" * 300,
      "ttl" => 60,
      "priority" => nil,
      "type" => "TXT",
      "system_record" => false,
      "created_at" => "2015-12-11T16:36:26.504Z",
      "updated_at" => "2015-12-11T16:36:26.504Z"
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::TXT, record)
    assert_equal('txt.dns-scratch.me.', record.fqdn)
    assert_equal("a" * 300, record.txtdata)
    assert_equal(60, record.ttl)
  end

  def test_build_txt_from_api_handles_mixed_case_fqdn
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 5199689,
      "domain_id" => 222002,
      "parent_id" => nil,
      "name" => "Txt",
      "content" => "Hello, world!",
      "ttl" => 60,
      "priority" => nil,
      "type" => "TXT",
      "system_record" => false,
      "created_at" => "2015-12-11T16:36:26.504Z",
      "updated_at" => "2015-12-11T16:36:26.504Z"
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::TXT, record)
    assert_equal('txt.dns-scratch.me.', record.fqdn)
    assert_equal('Hello, world!', record.txtdata)
    assert_equal(60, record.ttl)
  end

  def test_build_sshfp_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      "id" => 18003479,
      "parent_id" => nil,
      "name" => "_sshfp1",
      "content" => "1 1 0000000000000000000000000000000000000000000000000000000000000001",
      "ttl" => 3600,
      "priority" => nil,
      "type" => "SSHFP",
      "system_record" => false,
      "created_at" => "2020-03-31T20:11:35Z",
      "updated_at" => "2020-03-31T20:11:35Z",
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::SSHFP, record)
    assert_equal(Record::SSHFP::Algorithms::RSA, record.algorithm)
    assert_equal('0000000000000000000000000000000000000000000000000000000000000001', record.fingerprint)
    assert_equal(Record::SSHFP::FingerprintTypes::SHA_1, record.fptype)
  end

  def test_apply_sshfp_changeset
    sshfp_record = Record::SSHFP.new(
      fqdn: "_sshfp1.#{@zone_name}.",
      ttl: 3600,
      algorithm: Record::SSHFP::Algorithms::ED25519,
      fptype: Record::SSHFP::FingerprintTypes::SHA_256,
      fingerprint: '4e0ebbeac8d2e4e73af888b20e2243e5a2a08bad6476c832c985e54b21eff4a3',
    )

    VCR.use_cassette('dnsimple_apply_sshfp_changeset') do
      @dnsimple.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [sshfp_record],
        provider: RecordStore::Provider::DNSimple,
        zone: @zone_name
      ))

      records = @dnsimple.retrieve_current_records(zone: @zone_name)

      matching_records = records.select do |record|
        record.is_a?(Record::SSHFP) &&
          record.fqdn == sshfp_record.fqdn
      end

      assert_equal(1, matching_records.size, 'could not find the SSHFP record that was just created')
      assert_equal(Record::SSHFP::Algorithms::ED25519, matching_records.first.algorithm)
      assert_equal(Record::SSHFP::FingerprintTypes::SHA_256, matching_records.first.fptype)
      assert_equal(
        '4e0ebbeac8d2e4e73af888b20e2243e5a2a08bad6476c832c985e54b21eff4a3',
        matching_records.first.fingerprint
      )
    end
  end

  def test_apply_changeset_sets_state_to_match_changeset
    a_record = Record::A.new(fqdn: 'test-record.dns-scratch.me.', ttl: 86400, address: '10.10.10.42')

    VCR.use_cassette('dnsimple_apply_changeset') do
      @dnsimple.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [a_record],
        provider: RecordStore::Provider::DNSimple,
        zone: @zone_name
      ))
    end
  end

  def test_apply_changeset_with_alias_cleans_up_txt_record
    alias_record = Record::ALIAS.new(fqdn: 'dns-scratch.me.', ttl: 86400, alias: 'dns-scratch.herokuapp.com.')

    VCR.use_cassette('dnsimple_apply_changeset_with_alias') do
      @dnsimple.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [alias_record],
        provider: RecordStore::Provider::DNSimple,
        zone: @zone_name
      ))

      records = @dnsimple.retrieve_current_records(zone: @zone_name)
      refute_includes(records.map(&:type), 'TXT')
      assert_includes(records.map(&:type), 'ALIAS')
    end
  end

  def test_retrieve_current_records_returns_array_of_records
    records_arr = [
      Record::A.new(
        zone: 'dns-scratch.me',
        ttl: 86400,
        fqdn: 'test-record.dns-scratch.me',
        address: '10.10.10.42',
        record_id: 347572
      ),
      Record::NS.new(
        zone: 'dns-scratch.me',
        ttl: 3600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns4.dnsimple.com.',
        record_id: 347565
      ),
      Record::NS.new(
        zone: 'dns-scratch.me',
        ttl: 3600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns3.dnsimple.com.',
        record_id: 347566
      ),
      Record::NS.new(
        zone: 'dns-scratch.me',
        ttl: 3600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns2.dnsimple.com.',
        record_id: 347567
      ),
      Record::NS.new(
        zone: 'dns-scratch.me',
        ttl: 3600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns1.dnsimple.com.',
        record_id: 347568
      ),
      Record::ALIAS.new(
        zone: 'dns-scratch.me',
        ttl: 86400,
        fqdn: 'dns-scratch.me',
        alias: 'dns-scratch.herokuapp.com',
        record_id: 347573
      ),
    ]

    VCR.use_cassette('dnsimple_retrieve_current_records') do
      records = @dnsimple.retrieve_current_records(zone: @zone_name)
      assert_equal(records_arr.sort_by(&:to_s), records.sort_by(&:to_s))
    end
  end

  def test_build_ptr_from_api
    api_record = Dnsimple::Struct::ZoneRecord.new(
      'id' => 1714852,
      'zone_id' => '1.0.0.127.in-addr.arpa',
      'parent_id' => nil,
      'name' => '',
      'content' => 'example.com',
      'ttl' => 60,
      'priority' => nil,
      'type' => 'PTR',
      'regions' => ['global'],
      'system_record' => false,
      'created_at' => '2020-04-15T23:26:19Z',
      'updated_at' => '2020-04-15T23:26:19Z'
    )

    record = @dnsimple.send(:build_from_api, api_record, @zone_name)

    assert_kind_of(Record::PTR, record)
    assert_equal('example.com.', record.ptrdname)
  end

  def test_apply_ptr_changeset
    ptr_record = Record::PTR.new(
      fqdn: '1.0.0.127.in-addr.arpa',
      ttl: 60,
      ptrdname: 'example.com.'
    )

    VCR.use_cassette('dnsimple_apply_ptr_changeset') do
      @dnsimple.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [ptr_record],
        provider: RecordStore::Provider::DNSimple,
        zone: '1.0.0.127.in-addr.arpa'
      ))

      records = @dnsimple.retrieve_current_records(zone: '1.0.0.127.in-addr.arpa')

      matching_records = records.select do |record|
        record.is_a?(Record::PTR) &&
          record.fqdn == ptr_record.fqdn
      end

      assert_equal(1, matching_records.size, 'could not find the PTR record that was just created')
      assert_equal('example.com.', matching_records.first.ptrdname)
    end
  end

  def test_non_validation_errors_exclude_details
    VCR.use_cassette('dnsimple_test_non_validation_errors_exclude_details') do
      error = assert_raises(Dnsimple::NotFoundError) do
        @dnsimple.retrieve_current_records(zone: "does_not_exist")
      end

      assert_equal("Zone `does_not_exist` not found", error.message)
    end
  end

  def test_validation_errors_include_details
    fqdn = ['inconsistent-records', @zone_name].join('.') + '.'

    inconsistent_records = [
      Record::TXT.new(
        fqdn:fqdn,
        ttl:60,
        txtdata: 'a',
        zone: @zone_name,
      ),
      Record::CNAME.new(
        fqdn:fqdn,
        ttl:60,
        cname: 'shopify.com.',
        zone: @zone_name,
      )
    ]

    VCR.use_cassette('dnsimple_test_validation_errors_include_details') do
      existing_records = @dnsimple.retrieve_current_records(zone: @zone_name).select do |record|
        record.fqdn == fqdn
      end

      @dnsimple.apply_changeset(Changeset.new(
        current_records: existing_records,
        desired_records: [],
        provider: RecordStore::Provider::DNSimple,
        zone: @zone_name,
      ))

      error = assert_raises(Dnsimple::RequestError) do
          @dnsimple.apply_changeset(Changeset.new(
          current_records: [],
          desired_records: inconsistent_records,
          provider: RecordStore::Provider::DNSimple,
          zone: @zone_name,
        ))
      end

      assert_equal "Validation failed: A CNAME record exists for inconsistent-records.dns-scratch.me, cannot add another record", error.message
    end
  end

  def test_zones_returns_list_of_zones_managed_by_provider
    VCR.use_cassette('dnsimple_zones') do
      assert_equal(@dnsimple.zones, [@zone_name])
    end
  end

  def test_dnsimple_is_not_thawable
    refute_predicate(@dnsimple, :thawable?)
  end

  def test_dnsimple_is_not_freezable
    refute_predicate(@dnsimple, :freezable?)
  end

  def test_dnsimple_rate_limit_sleep_called_with_right_arguments
    # Expected values retrieved from record_store/test/fixtures/vcr_cassettes/dnsimple_zones.yaml
    rate_limit_reset = 1519155898
    rate_limit_remaining = 2336
    session = @dnsimple.send(:session)
    session.expects(:rate_limit_sleep).with(rate_limit_reset, rate_limit_remaining)

    VCR.use_cassette('dnsimple_zones') do
      assert_equal(@dnsimple.zones, [@zone_name])
    end
  end

  def test_dnsimple_rate_limit_sleep
    # Expected values retrieved from record_store/test/fixtures/vcr_cassettes/dnsimple_zones.yaml
    current_time_to_test = Time.at(1519126698)
    rate_limit_reset = 1519155898
    rate_limit_remaining = 2336
    expected_sleep_duration = 12.494651262302098
    helper_rate_limit_sleep_test(current_time_to_test, rate_limit_reset, rate_limit_remaining, expected_sleep_duration)
  end

  def test_dnsimple_rate_limit_sleep_with_old_reset_time
    # If reset time is older than current time, sleep should not be called
    current_time_to_test = Time.at(1529126698)
    rate_limit_reset = 1519155898
    rate_limit_remaining = 2336

    Time.stubs(:now).returns(current_time_to_test)
    session = @dnsimple.send(:session)
    RateLimitWaiter.any_instance.expects(:sleep).never
    session.send(:rate_limit_sleep, rate_limit_reset, rate_limit_remaining)
  end

  def test_dnsimple_rate_limit_sleep_with_no_requests_remaining
    # If there are no requests remainig, it is expected that rate_limit_sleep will sleep for the entire window
    current_time_to_test = Time.at(1519126698)
    rate_limit_reset = 1519155898
    rate_limit_window = rate_limit_reset - current_time_to_test.to_i
    rate_limit_remaining = 0
    helper_rate_limit_sleep_test(current_time_to_test, rate_limit_reset, rate_limit_remaining, rate_limit_window)
  end

  def helper_rate_limit_sleep_test(current_time, rate_limit_reset, rate_limit_remaining, expected_sleep_duration)
    session = @dnsimple.send(:session)
    Time.stubs(:now).returns(current_time)
    RateLimitWaiter.any_instance.stubs(:wait)
    RateLimitWaiter.any_instance.expects(:wait).with(expected_sleep_duration)
    session.send(:rate_limit_sleep, rate_limit_reset, rate_limit_remaining)
  end
end
