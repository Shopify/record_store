require 'test_helper'

class NS1Test < Minitest::Test
  def setup
    super
    @zone_name = 'test.recordstore.io'
    @ns1 = Provider::NS1
  end

  def test_zones
    VCR.use_cassette('ns1_get_zones') do
      zones = @ns1.zones
      assert_includes(zones, @zone_name)
    end
  end

  def test_add_changeset
    record = Record::A.new(fqdn: 'test_add_changeset.test.recordstore.io', ttl: 600, address: '10.10.10.42')

    VCR.use_cassette('ns1_add_changeset') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))
    end
  end

  def test_add_multiple_changesets
    records = [
      Record::A.new(fqdn: 'test_add_multiple_changesets.test.recordstore.io', ttl: 600, address: '10.10.10.42'),
      Record::A.new(fqdn: 'test_add_multiple_changesets.test.recordstore.io', ttl: 600, address: '10.10.10.43'),
    ]

    VCR.use_cassette('ns1_add_multiple_changesets') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: records,
        provider: @ns1,
        zone: @zone_name,
      ))
    end
  end

  def test_remove_changeset
    record = Record::A.new(fqdn: 'test_remove_changeset.test.recordstore.io', ttl: 600, address: '10.10.10.42')

    VCR.use_cassette('ns1_remove_changesets') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))

      @ns1.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [],
        provider: @ns1,
        zone: @zone_name,
      ))
      current_records = @ns1.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.none? do |current_record|
        current_record.is_a?(Record::A) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.address == current_record.address
      end

      assert(contains_desired_record)
    end
  end

  def test_update_changeset
    VCR.use_cassette('ns1_update_changeset') do
      record_data = {
        address: '10.10.10.48',
        fqdn: 'test_update_changeset.test.recordstore.io',
        ttl: 600,
      }

      # Create a record
      record = Record::A.new(record_data)

      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))

      # Retrieve it
      record = @ns1.retrieve_current_records(zone: @zone_name).select { |r| r == record }.first
      assert(!record.nil?)

      updated_record = Record::A.new(record_data)
      updated_record.address = "10.10.10.49"

      # Try to update it
      @ns1.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [updated_record],
        provider: @ns1,
        zone: @zone_name,
      ))

      updated_record_exists = @ns1.retrieve_current_records(zone: @zone_name).any? { |r| r == updated_record }
      old_record_does_not_exist = @ns1.retrieve_current_records(zone: @zone_name).none? { |r| r == record }

      assert(updated_record_exists)
      assert(old_record_does_not_exist)
    end
  end

  def test_update_changeset_where_domain_doesnt_exist
    VCR.use_cassette('ns1_update_changeset_where_domain_doesnt_exist') do
      record_data = {
        address: '10.10.10.48',
        fqdn: 'test_update_changeset_where_domain_doesnt_exist.test.recordstore.io',
        ttl: 600,
      }

      # Create a record
      record = Record::A.new(record_data)

      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))

      # Retrieve it
      record = @ns1.retrieve_current_records(zone: @zone_name).select { |r| r == record }.first
      assert(!record.nil?)

      updated_record = Record::A.new(record_data)
      updated_record.address = "10.10.10.49"

      @ns1.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [],
        provider: @ns1,
        zone: @zone_name,
      ))

      assert_raises(RecordStore::Provider::NS1::Error) do
        # Try to update it
        @ns1.apply_changeset(Changeset.new(
          current_records: [record],
          desired_records: [updated_record],
          provider: @ns1,
          zone: @zone_name,
        ))
      end
    end
  end

  def test_apply_changeset_where_response_is_unparseable
    VCR.use_cassette('ns1_update_changeset_where_response_is_unparseable') do
      record_data = {
        address: '10.10.10.48',
        fqdn: 'test_apply_changeset_where_response_is_unparseable.test.recordstore.io',
        ttl: 600,
      }

      # Create a record
      record = Record::A.new(record_data)
      assert_raises(RecordStore::Provider::UnparseableBodyError) do
        @ns1.apply_changeset(Changeset.new(
          current_records: [],
          desired_records: [record],
          provider: @ns1,
          zone: @zone_name,
        ))
      end
    end
  end

  def test_update_changeset_for_fqdn_with_multiple_answers
    VCR.use_cassette('ns1_update_changeset_for_fqdn_with_multiple_answers') do
      base_record_data = {
        fqdn: 'test_update_changeset_multiples.test.recordstore.io',
        ttl: 600,
      }

      record_datas = [
        base_record_data.merge(address: '10.10.10.47'),
        base_record_data.merge(address: '10.10.10.48'),
        base_record_data.merge(address: '10.10.10.49'),
      ]

      # Create records
      original_records = record_datas.map do |record_data|
        Record::A.new(record_data)
      end

      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: original_records,
        provider: @ns1,
        zone: @zone_name,
      ))

      # Retrieve them
      records = @ns1.retrieve_current_records(zone: @zone_name)

      updated_record = Record::A.new(record_datas.first)
      updated_record.address = "10.10.10.50"

      # Modify the first record we added
      updated_records = records.map do |record|
        if record == original_records.first
          updated_record
        else
          record
        end
      end

      @ns1.apply_changeset(Changeset.new(
        current_records: records,
        desired_records: updated_records,
        provider: @ns1,
        zone: @zone_name,
      ))

      # Check
      updated_record_exists = @ns1.retrieve_current_records(zone: @zone_name).any? { |r| r == updated_record }
      first_record_does_not_exist = @ns1.retrieve_current_records(zone: @zone_name)
        .none? { |r| r == original_records[0] }
      second_record_exists = @ns1.retrieve_current_records(zone: @zone_name).any? { |r| r == original_records[1] }
      third_record_exists = @ns1.retrieve_current_records(zone: @zone_name).any? { |r| r == original_records[2] }

      assert(updated_record_exists)
      assert(first_record_does_not_exist)
      assert(second_record_exists)
      assert(third_record_exists)
    end
  end

  def test_add_changeset_with_nil_zone
    record = Record::A.new(
      fqdn: 'test_add_changeset_with_nil_zone.test.recordstore.io',
      ttl: 600,
      address: '10.10.10.42',
    )

    VCR.use_cassette('ns1_add_changeset_nil_zone') do
      assert_raises(NS1::MissingParameter) do
        @ns1.apply_changeset(Changeset.new(
          current_records: [],
          desired_records: [record],
          provider: @ns1,
          zone: nil,
        ))
      end
    end
  end

  def test_add_changset_missing_zone
    record = Record::A.new(fqdn: 'test_add_changset_missing_zone.test.recordstore.io', ttl: 600, address: '10.10.10.42')

    VCR.use_cassette('ns1_add_changeset_missing_zone') do
      assert_raises do
        @ns1.apply_changeset(Changeset.new(
          current_records: [],
          desired_records: [record],
          provider: @ns1,
          # Maintainers Note: Ensure that the `recordstore.io` zone does not exist
          zone: 'test_add_changset_missing_zone.recordstore.io',
        ))
      end
    end
  end

  def test_record_retrieved_after_adding_record_changeset
    record = Record::A.new(fqdn: 'test_add_a.test.recordstore.io', ttl: 600, address: '10.10.10.1')

    VCR.use_cassette('ns1_add_a_changeset') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))
      current_records = @ns1.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::A) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.address == current_record.address
      end

      assert(contains_desired_record)
    end
  end

  def test_updating_record_ttl
    VCR.use_cassette('ns1_updating_record_ttl') do
      record_data = { fqdn: 'test_updating_ttl.test.recordstore.io', ttl: 600, address: '10.10.10.1' }
      record = Record::A.new(record_data)

      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))

      record_with_updated_ttl = Record::A.new(record_data.merge(ttl: 10))
      record = @ns1.retrieve_current_records(zone: @zone_name).select { |r| r == record }.first

      @ns1.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [record_with_updated_ttl],
        provider: @ns1,
        zone: @zone_name,
      ))

      current_records = @ns1.retrieve_current_records(zone: @zone_name)

      contains_updated_record = current_records.any? { |r| r == record_with_updated_ttl }

      assert(contains_updated_record)
    end
  end

  def test_alias_record_retrieved_after_adding_record_changeset
    record = Record::ALIAS.new(fqdn: 'test_add_alias.test.recordstore.io', ttl: 600, alias: '10.10.10.1')

    VCR.use_cassette('ns1_add_alias_changeset') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))
      current_records = @ns1.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::ALIAS) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.alias == current_record.alias
      end

      assert(contains_desired_record)
    end
  end

  def test_carecord_retrieved_after_adding_record_changeset
    record = Record::CAA.new(
      fqdn: 'test_add_caa.test.recordstore.io',
      ttl: 600,
      flags: 0,
      tag: 'issue',
      value: 'shopify.com',
    )

    VCR.use_cassette('ns1_add_caa_changeset') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))
      current_records = @ns1.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::CAA) &&
          record.flags == current_record.flags &&
          record.tag == current_record.tag &&
          record.value == current_record.value
      end

      assert(contains_desired_record)
    end
  end

  def test_cname_record_retrieved_after_adding_record_changeset
    record = Record::CNAME.new(fqdn: 'test_add_alias.test.recordstore.io.', ttl: 600, cname: 'test.recordstore.io.')

    VCR.use_cassette('ns1_add_cname_changeset') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))
      current_records = @ns1.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::CNAME) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.cname == current_record.cname
      end

      assert(contains_desired_record)
    end
  end

  def test_mx_record_retrieved_after_adding_record_changeset
    record = Record::MX.new(
      fqdn: 'test_add_mx.test.recordstore.io',
      ttl: 600,
      preference: 10,
      exchange: 'mxa.mailgun.org',
    )

    VCR.use_cassette('ns1_add_mx_changeset') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))
      current_records = @ns1.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::MX) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.preference == current_record.preference &&
          record.exchange == current_record.exchange
      end

      assert(contains_desired_record)
    end
  end

  def test_ns_record_retrieved_after_adding_record_changeset
    record = Record::NS.new(fqdn: 'test_add_ns.test.recordstore.io.', ttl: 600, nsdname: 'test.recordstore.io.')

    VCR.use_cassette('ns1_add_ns_changeset') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))
      current_records = @ns1.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::NS) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.nsdname == current_record.nsdname
      end

      assert(contains_desired_record)
    end
  end

  def test_txt_record_retrieved_after_adding_record_changeset
    record = Record::TXT.new(fqdn: 'test_add_txt.test.recordstore.io.', ttl: 600, txtdata: 'Hello World!')

    VCR.use_cassette('ns1_add_txt_changeset') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))
      current_records = @ns1.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::TXT) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.txtdata == current_record.txtdata
      end
      assert(contains_desired_record)
    end
  end

  def test_spf_record_retrieved_after_adding_record_changeset
    record = Record::SPF.new(fqdn: 'test_add_spf.test.recordstore.io.', ttl: 600, txtdata: 'Hello World!')

    VCR.use_cassette('ns1_add_spf_changeset') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))
      current_records = @ns1.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::SPF) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.txtdata == current_record.txtdata
      end
      assert(contains_desired_record)
    end
  end

  def test_srv_record_retrieved_after_adding_record_changeset
    record = Record::SRV.new(
      fqdn: 'test_add_spf.test.recordstore.io.',
      ttl: 600,
      priority: 1,
      weight: 2,
      port: 3,
      target: 'spf.shopify.com.',
    )

    VCR.use_cassette('ns1_add_srv_changeset') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @ns1,
        zone: @zone_name,
      ))
      current_records = @ns1.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::SRV) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.priority == current_record.priority &&
          record.weight == current_record.weight &&
          record.port == current_record.port &&
          record.target == current_record.target
      end
      assert(contains_desired_record)
    end
  end

  def test_remove_record_should_not_remove_all_records_for_fqdn
    record_1 = Record::A.new(fqdn: 'one_of_these_should_remain.test.recordstore.io', ttl: 600, address: '10.10.10.42')
    record_2 = Record::A.new(fqdn: 'one_of_these_should_remain.test.recordstore.io', ttl: 600, address: '10.10.10.43')

    VCR.use_cassette('ns1_remove_record_should_not_remove_all_records_for_fqdn') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record_1, record_2],
        provider: @ns1,
        zone: @zone_name,
      ))
      @ns1.apply_changeset(Changeset.new(
        current_records: [record_1, record_2],
        desired_records: [record_1],
        provider: @ns1,
        zone: @zone_name,
      ))
      records = @ns1.retrieve_current_records(zone: @zone_name)

      record_2_missing = records.none? do |current_record|
        current_record.is_a?(Record::A) &&
          record_2.fqdn == current_record.fqdn &&
          record_2.ttl == current_record.ttl &&
          record_2.address == current_record.address
      end

      record_1_found = records.any? do |current_record|
        current_record.is_a?(Record::A) &&
          record_1.fqdn == current_record.fqdn &&
          record_1.ttl == current_record.ttl &&
          record_1.address == current_record.address
      end

      assert(record_2_missing, "expected deleted record to be absent in NS1")
      assert(record_1_found, "expected record that was not removed to be present in NS1")
    end
  end

  def test_escaped_colons_maintained_when_exported_from_ns1
    imported_txt_record = Record::TXT.new(
      fqdn: 'test_escaped_colons_maintained_when_exported.test.recordstore.io.',
      ttl: 60,
      txtdata: 'v=DKIM\; k=rsa\;',
    )

    VCR.use_cassette('ns1_escaped_colons_maintained_when_exported_from_ns1') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [imported_txt_record],
        provider: @ns1,
        zone: @zone_name,
      ))

      records = @ns1.retrieve_current_records(zone: @zone_name)

      matching_records = records.select do |record|
        record.fqdn == imported_txt_record.fqdn
      end

      assert_equal(1, matching_records.size, "could not find the record that was just imported")
      assert_equal(imported_txt_record.txtdata, matching_records.first.txtdata)
    end
  end

  def test_colons_always_escaped_when_exported_from_ns1
    imported_txt_record = Record::TXT.new(
      fqdn: 'test_colons_always_escaped_when_exported.test.recordstore.io.',
      ttl: 60,
      txtdata: 'v=DKIM; k=rsa;',
    )

    VCR.use_cassette('ns1_colons_always_escaped_when_exported_from_ns1') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [imported_txt_record],
        provider: @ns1,
        zone: @zone_name,
      ))

      records = @ns1.retrieve_current_records(zone: @zone_name)

      matching_records = records.select do |record|
        record.fqdn == imported_txt_record.fqdn
      end

      assert_equal(1, matching_records.size, 'could not find the record that was just imported')
      assert_equal(matching_records.first.txtdata, 'v=DKIM\; k=rsa\;')
    end
  end

  def test_very_long_txt_record_more_than_255_chars_ns1
    txtdata = '0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789' \
      '0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789' \
      '0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789'

    imported_txt_record = Record::TXT.new(
      fqdn: 'very_long_txt_record_more_than_255_chars.test.recordstore.io.',
      ttl: 60,
      txtdata: txtdata,
    )

    VCR.use_cassette('ns1_very_long_txt_record_more_than_255_chars') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [imported_txt_record],
        provider: @ns1,
        zone: @zone_name,
      ))

      records = @ns1.retrieve_current_records(zone: @zone_name)

      matching_records = records.select do |record|
        record.fqdn == imported_txt_record.fqdn
      end

      assert_equal(1, matching_records.size, 'could not find the record that was just imported')
      assert_equal(matching_records.first.txtdata, txtdata)
    end
  end

  def test_new_records_have_edns_client_subnet_disabled
    new_record = Record::TXT.new(
      fqdn: 'test_new_records_have_edns_client_subnet_disabled.test.recordstore.io',
      ttl: 3600,
      txtdata: 'Some answer',
    )

    json_request_body_matcher = lambda do |request_1, request_2|
      return true if request_1.headers['Content-Type'] != ['application/json'] &&
        request_2.headers['Content-Type'] != ['application/json']

      request_1.uri == request_2.uri &&
        request_1.method == request_2.method &&
        JSON.parse(request_1.body) == JSON.parse(request_2.body)
    end

    # Cassette request body will assert that `use_client_subnet` is set to false in the request
    VCR.use_cassette(
      'ns1_test_new_records_have_edns_client_subnet_disabled',
      match_requests_on: [json_request_body_matcher],
    ) do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [new_record],
        provider: @ns1,
        zone: @zone_name,
      ))
    end
  end

  def test_does_not_allow_addition_of_sshfp_records
    sshfp_record = Record::SSHFP.new(
      fqdn: "_sshfp1.#{@zone_name}.",
      ttl: 3600,
      algorithm: Record::SSHFP::Algorithms::ED25519,
      fptype: Record::SSHFP::FingerprintTypes::SHA_256,
      fingerprint: '4e0ebbeac8d2e4e73af888b20e2243e5a2a08bad6476c832c985e54b21eff4a3',
    )

    VCR.use_cassette('test_does_not_allow_addition_of_sshfp_records') do
      err = assert_raises(Provider::NS1::Error) do
        @ns1.apply_changeset(Changeset.new(
          current_records: [],
          desired_records: [sshfp_record],
          provider: @ns1,
          zone: @zone_name,
        ))
      end
      assert_match(/SSHFP/, err.message)
    end
  end

  def test_does_not_allow_updates_to_sshfp_records
    old_sshfp_record = Record::SSHFP.new(
      fqdn: "_sshfp1.#{@zone_name}.",
      ttl: 3600,
      algorithm: Record::SSHFP::Algorithms::ED25519,
      fptype: Record::SSHFP::FingerprintTypes::SHA_256,
      fingerprint: '4e0ebbeac8d2e4e73af888b20e2243e5a2a08bad6476c832c985e54b21eff4a3',
    )
    new_sshfp_record = Record::SSHFP.new(
      fqdn: "_sshfp1.#{@zone_name}.",
      ttl: 3600,
      algorithm: Record::SSHFP::Algorithms::ED25519,
      fptype: Record::SSHFP::FingerprintTypes::SHA_256,
      fingerprint: '0000000000000000000000000000000000000000000000000000000000000000',
    )

    VCR.use_cassette('test_does_not_allow_updates_to_sshfp_records') do
      err = assert_raises(Provider::NS1::Error) do
        @ns1.apply_changeset(Changeset.new(
          current_records: [old_sshfp_record],
          desired_records: [new_sshfp_record],
          provider: @ns1,
          zone: @zone_name,
        ))
      end
      assert_match(/SSHFP/, err.message)
    end
  end

  def test_creates_ptr_records
    ptr_record = Record::PTR.new(
      fqdn: '4.3.2.1.in-addr.arpa',
      ttl: 60,
      ptrdname: 'example.com.',
    )

    VCR.use_cassette('test_creates_ptr_records') do
      @ns1.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [ptr_record],
        provider: @ns1,
        zone: '4.3.2.1.in-addr.arpa',
      ))

      records = @ns1.retrieve_current_records(zone: '4.3.2.1.in-addr.arpa')

      matching_records = records.select do |record|
        record.is_a?(Record::PTR) &&
          record.fqdn == ptr_record.fqdn
      end

      assert_equal(1, matching_records.size, 'could not find the PTR record that was just created')
      assert_equal('example.com.', matching_records.first.ptrdname)
    end
  end
end
