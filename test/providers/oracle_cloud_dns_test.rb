require 'test_helper'

class OracleCloudDNSTest < Minitest::Test
  def setup
    @zone_name = 'test.recordstore.io'
    @oracle_cloud_dns = Provider::OracleCloudDNS
  end

  def test_zones
    VCR.use_cassette('oracle_get_zones') do
      zones = @oracle_cloud_dns.zones
      assert_includes(zones, @zone_name)
    end
  end

  def test_add_changeset
    record = Record::A.new(fqdn: 'test_add_changeset.test.recordstore.io', ttl: 600, address: '10.10.10.42')

    VCR.use_cassette('oracle_add_changeset') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
    end
  end

  def test_add_multiple_changesets
    records = [
      Record::A.new(fqdn: 'test_add_multiple_changesets.test.recordstore.io', ttl: 1200, address: '10.10.10.65'),
      Record::A.new(fqdn: 'test_add_multiple_changesets.test.recordstore.io', ttl: 1200, address: '10.10.10.70'),
    ]

    VCR.use_cassette('oracle_add_multiple_changesets') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: records,
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
    end
  end

  def test_add_same_two_txt_but_only_one_stores_changesets
    records = [
      Record::TXT.new(fqdn: 'test_add_same_two_txt_changesets.test.recordstore.io', ttl: 1200, txtdata: 'same text'),
      Record::TXT.new(fqdn: 'test_add_same_two_txt_changesets.test.recordstore.io', ttl: 1200, txtdata: 'same text'),
    ]

    VCR.use_cassette('oracle_add_same_two_txt_changesets') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: records,
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)
      contains_desired_record = [] << current_records.any? do |current_record|
        current_record.is_a?(Record::TXT) &&
          records[0].fqdn == current_record.fqdn &&
          records[0].ttl == current_record.ttl &&
          records[0].txtdata == current_record.txtdata
      end
      assert contains_desired_record.length == 1
    end
  end

  def test_add_changeset_with_nil_zone
    record = Record::A.new(
      fqdn: 'test_add_changeset_with_nil_zone.test.recordstore.io',
      ttl: 600,
      address: '10.10.10.42'
    )

    VCR.use_cassette('oracle_add_changeset_nil_zone') do
      assert_raises RuntimeError do
        @oracle_cloud_dns.apply_changeset(Changeset.new(
          current_records: [],
          desired_records: [record],
          provider: @oracle_cloud_dns,
          zone: nil
        ))
      end
    end
  end

  def test_add_changset_missing_zone
    record = Record::A.new(
      fqdn: 'test_add_changset_missing_zone.test.recordstore.io',
      ttl: 2400, address: '10.10.10.80'
    )

    VCR.use_cassette('oracle_add_changeset_missing_zone') do
      assert_raises do
        @oracle_cloud_dns.apply_changeset(Changeset.new(
          current_records: [],
          desired_records: [record],
          provider: @oracle_cloud_dns,
          # Maintainers Note: Ensure that the `recordstore.io` zone does not exist
          zone: 'test_add_changset_missing_zone.recordstore.io'
        ))
      end
    end
  end

  def test_remove_changeset
    record = Record::A.new(fqdn: 'test_remove_changeset.test.recordstore.io', ttl: 600, address: '10.10.10.42')

    VCR.use_cassette('oracle_remove_changesets') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))

      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.none? do |current_record|
        current_record.is_a?(Record::A) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.address == current_record.address
      end
      assert contains_desired_record
    end
  end

  def test_remove_does_not_exist_changeset
    record = Record::A.new(
      fqdn: 'test_remove_does_not_exist_changeset.test.recordstore.io',
      ttl: 600,
      address: '10.10.10.99'
    )

    VCR.use_cassette('oracle_remove_does_not_exist_changesets') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
    current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.none? do |current_record|
        current_record.is_a?(Record::A) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.address == current_record.address
      end
      assert contains_desired_record
    end
  end

  def test_remove_first_from_two_a_records_changeset
    records = [
      Record::A.new(
        fqdn: 'test_remove_first_from_two_a_records_changeset.test.recordstore.io',
        ttl: 600,
        address: '60.60.60.66'
      ),
      Record::A.new(
        fqdn: 'test_remove_first_from_two_a_records_changeset.test.recordstore.io',
        ttl: 600,
        address: '70.70.70.77'
      ),
    ]

    VCR.use_cassette('oracle_remove_first_from_two_a_records_changesets') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: records,
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))

      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: records,
        desired_records: [records[1]],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::A) &&
          records[1].fqdn == current_record.fqdn &&
          records[1].ttl == current_record.ttl &&
          records[1].address == current_record.address
      end
      assert contains_desired_record
    end
  end

  def test_remove_first_from_two_txt_records_changeset
    records = [
      Record::TXT.new(
        fqdn: 'test_remove_first_from_two_txt_records_changeset.test.recordstore.io',
        ttl: 600,
        txtdata: 'text 1'
      ),
      Record::TXT.new(
        fqdn: 'test_remove_first_from_two_txt_records_changeset.test.recordstore.io',
        ttl: 600,
        txtdata: 'text 2'
      ),
    ]

    VCR.use_cassette('oracle_remove_first_from_two_txt_records_changesets') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: records,
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))

      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: records,
        desired_records: [records[1]],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::TXT) &&
          records[1].fqdn == current_record.fqdn &&
          records[1].ttl == current_record.ttl &&
          records[1].txtdata == current_record.txtdata
      end
      assert contains_desired_record
    end
  end

  def test_remove_second_from_two_txt_records_changeset
    records = [
      Record::TXT.new(
        fqdn: 'test_remove_second_from_two_txt_records_changeset.test.recordstore.io',
        ttl: 1200,
        txtdata: 'text 1'
      ),
      Record::TXT.new(
        fqdn: 'test_remove_second_from_two_txt_records_changeset.test.recordstore.io',
        ttl: 1200,
        txtdata: 'text 2'
      ),
    ]

    VCR.use_cassette('oracle_remove_second_from_two_txt_records_changesets') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: records,
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))

      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: records,
        desired_records: [records[0]],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::TXT) &&
          records[0].fqdn == current_record.fqdn &&
          records[0].ttl == current_record.ttl &&
          records[0].txtdata == current_record.txtdata
      end
      assert contains_desired_record
    end
  end

  def test_record_retrieved_after_adding_record_changeset
    record = Record::A.new(fqdn: 'test_add_a.test.recordstore.io', ttl: 600, address: '10.10.10.1')

    VCR.use_cassette('oracle_add_a_changeset') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::A) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.address == current_record.address
      end

      assert contains_desired_record
    end
  end

  def test_alias_record_retrieved_after_adding_record_changeset
    record = Record::ALIAS.new(fqdn: 'test_add_alias.test.recordstore.io', ttl: 600, alias: 'recordstore.com')

    VCR.use_cassette('oracle_add_alias_changeset') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::ALIAS) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.alias == current_record.alias
      end

      assert contains_desired_record
    end
  end

  def test_caa_record_retrieved_after_adding_record_changeset
    record = Record::CAA.new(
      fqdn: 'test_add_caa.test.recordstore.io',
      ttl: 600,
      flags: 0,
      tag: 'issue',
      value: 'shopify.com'
    )

    VCR.use_cassette('oracle_add_caa_changeset') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::CAA) &&
          record.flags == current_record.flags &&
          record.tag == current_record.tag &&
          record.value == current_record.value
      end

      assert contains_desired_record
    end
  end

  def test_cname_record_retrieved_after_adding_record_changeset
    record = Record::CNAME.new(fqdn: 'test_add_cname.test.recordstore.io.', ttl: 600, cname: 'test.recordstore.io.')

    VCR.use_cassette('oracle_add_cname_changeset') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::CNAME) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.cname == current_record.cname
      end

      assert contains_desired_record
    end
  end

  def test_mx_record_retrieved_after_adding_record_changeset
    record = Record::MX.new(
      fqdn: 'test_add_mx.test.recordstore.io',
      ttl: 600,
      preference: 10,
      exchange: 'mxa.mailgun.org'
    )

    VCR.use_cassette('oracle_add_mx_changeset') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::MX) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.preference == current_record.preference &&
          record.exchange == current_record.exchange
      end

      assert contains_desired_record
    end
  end

  def test_ns_record_retrieved_after_adding_record_changeset
    record = Record::NS.new(
      fqdn: 'test_add_ns.test.recordstore.io.',
      ttl: 600,
      nsdname: 'ns_test.p68.dns.oraclecloud.net.'
    )
    VCR.use_cassette('oracle_add_ns_changeset') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::NS) &&
        record.fqdn == current_record.fqdn &&
        record.ttl == current_record.ttl &&
        record.nsdname == current_record.nsdname
      end

      assert contains_desired_record
    end
  end

  # If there's space in txtdata, it stores separately with double quotes
  def test_txt_record_retrieved_after_adding_record_changeset
    record = Record::TXT.new(fqdn: 'test_add_txt.test.recordstore.io.', ttl: 600, txtdata: 'Hello World!')

    VCR.use_cassette('oracle_add_txt_changeset') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::TXT) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.txtdata == current_record.txtdata
      end
      assert contains_desired_record
    end
  end

  def test_spf_record_retrieved_after_adding_record_changeset
    record = Record::SPF.new(fqdn: 'test_add_spf.test.recordstore.io.', ttl: 600, txtdata: 'Hello World!')

    VCR.use_cassette('oracle_add_spf_changeset') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::SPF) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.txtdata == current_record.txtdata
      end
      assert contains_desired_record
    end
  end

  def test_srv_record_retrieved_after_adding_record_changeset
    record = Record::SRV.new(
      fqdn: 'test_add_spf.test.recordstore.io.',
      ttl: 600,
      priority: 1,
      weight: 2,
      port: 3,
      target: 'spf.shopify.com.'
    )

    VCR.use_cassette('oracle_add_srv_changeset') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_desired_record = current_records.any? do |current_record|
        current_record.is_a?(Record::SRV) &&
          record.fqdn == current_record.fqdn &&
          record.ttl == current_record.ttl &&
          record.priority == current_record.priority &&
          record.weight == current_record.weight &&
          record.port == current_record.port &&
          record.target == current_record.target
      end
      assert contains_desired_record
    end
  end

  def test_update_changeset
    VCR.use_cassette('oracle_update_changeset') do
      record_data = {
        address: '10.10.10.48',
        fqdn: 'test_update_changeset.test.recordstore.io',
        ttl: 600,
      }

      # Create a record
      record = Record::A.new(record_data)

      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))

      # Retrieve it
      record = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name).select { |r| r == record }.first
      assert !record.nil?

      updated_record = Record::A.new(record_data)
      updated_record.address = "10.10.10.49"

      # Try to update it
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [updated_record],
        provider: @oracle_cloud_dns,
        zone: @zone_name,
      ))

      updated_record_exists = @oracle_cloud_dns.retrieve_current_records(
        zone: @zone_name
      ).any? { |r| r == updated_record }
      old_record_does_not_exist = @oracle_cloud_dns.retrieve_current_records(
        zone: @zone_name
      ).none? { |r| r == record }

      assert updated_record_exists
      assert old_record_does_not_exist
    end
  end

  def test_updating_record_ttl
    VCR.use_cassette('oracle_updating_record_ttl') do
      record_data = { fqdn: 'test_updating_ttl.test.recordstore.io', ttl: 600, address: '10.10.10.1' }
      record = Record::A.new(record_data)

      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))

      record_with_updated_ttl = Record::A.new(record_data.merge(ttl: 10))
      record = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name).select { |r| r == record }.first

      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [record_with_updated_ttl],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))

      current_records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

      contains_updated_record = current_records.any? { |r| r == record_with_updated_ttl }

      assert contains_updated_record
    end
  end

  def test_update_changeset_where_domain_doesnt_exist
    VCR.use_cassette('oracle_update_changeset_where_domain_doesnt_exist') do
      record_data = {
        address: '10.10.10.48',
        fqdn: 'test_update_changeset_where_domain_doesnt_exist.test.recordstore.io',
        ttl: 600,
      }

      # Create a record
      record = Record::A.new(record_data)

      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))

      # Retrieve it
      record = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name).select { |r| r == record }.first
      assert !record.nil?

      updated_record = Record::A.new(record_data)
      updated_record.address = "10.10.10.49"

      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))

      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [updated_record],
        provider: @oracle_cloud_dns,
        zone: @zone_name,
      ))
    end
  end

  def test_update_changeset_for_fqdn_with_multiple_answers
    VCR.use_cassette('oracle_update_changeset_for_fqdn_with_multiple_answers') do
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

      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: original_records,
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))

      # Retrieve them
      records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

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

      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: records,
        desired_records: updated_records,
        provider: @oracle_cloud_dns,
        zone: @zone_name,
      ))

      # Check
      updated_record_exists = @oracle_cloud_dns.retrieve_current_records(
        zone: @zone_name
      ).any? { |r| r == updated_record }
      first_record_does_not_exist = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)
        .none? { |r| r == original_records[0] }
      second_record_exists = @oracle_cloud_dns.retrieve_current_records(
        zone: @zone_name
      ).any? { |r| r == original_records[1] }
      third_record_exists = @oracle_cloud_dns.retrieve_current_records(
        zone: @zone_name
      ).any? { |r| r == original_records[2] }

      assert updated_record_exists
      assert first_record_does_not_exist
      assert second_record_exists
      assert third_record_exists
    end
  end

  def test_remove_record_should_not_remove_all_records_for_fqdn
    record_1 = Record::A.new(fqdn: 'one_of_these_should_remain.test.recordstore.io', ttl: 600, address: '20.20.20.20')
    record_2 = Record::A.new(fqdn: 'one_of_these_should_remain.test.recordstore.io', ttl: 600, address: '30.30.30.30')

    VCR.use_cassette('oracle_remove_record_should_not_remove_all_records_for_fqdn') do
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record_1, record_2],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      @oracle_cloud_dns.apply_changeset(Changeset.new(
        current_records: [record_1, record_2],
        desired_records: [record_1],
        provider: @oracle_cloud_dns,
        zone: @zone_name
      ))
      records = @oracle_cloud_dns.retrieve_current_records(zone: @zone_name)

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

      assert record_2_missing, "expected deleted record to be absent in Oracle"
      assert record_1_found, "expected record that was not removed to be present in Oracle"
    end
  end
end
