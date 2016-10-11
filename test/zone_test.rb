require 'test_helper'

class ZoneTest < Minitest::Test
  def setup
    Zone.reset
  end

  def test_find_returns_zone_by_name
    zone = Zone.find('one-record.com')

    assert_instance_of Zone, zone
    assert_predicate zone, :valid?
  end

  def test_find_returns_zone_by_name_in_single_file
    zone = Zone.find('zone-file.com')

    assert_instance_of Zone, zone
    assert_predicate zone, :valid?
  end

  def test_find_can_load_multiple_records_for_a_single_type
    zone = Zone.find('two-records.com')
    assert_equal 2, zone.records.size
  end

  def test_find_merges_records_from_dir_files
    zone = Zone.find('merged-records.com')
    assert_equal 2, zone.records.size
  end

  def test_find_returns_nil_for_missing_zone
    assert_nil Zone.find('missing-zone.com')
  end

  def test_zone_has_configurable_ignore_pattern
    zone = Zone.find('one-record.com')
    assert_equal 1, zone.records.size

    zone.config = build_config(ignore_patterns: [{'fqdn' => 'a-record.one-record.com.'}])
    assert_equal 0, zone.records.size

    zone.config = build_config(ignore_patterns: [])
    assert_equal 1, zone.records.size
  end

  def test_zone_has_config_with_provider
    zone = Zone.find('empty.com')

    assert_respond_to zone, :config
    assert_instance_of Zone::Config, zone.config
  end

  def test_zone_is_invalid_if_provider_does_not_support_record_type
    supported_record_types = Provider::DynECT.record_types - ['ALIAS']
    Provider::DynECT.stubs(:record_types).returns(supported_record_types)

    zone = Zone.find('empty.com')
    assert_equal 'DynECT', zone.config.provider
    zone.records = [Record::ALIAS.new(fqdn: zone.name, ttl: 60, alias: "alias.#{zone.name}")]

    refute_predicate zone, :valid?
  end

  def test_zone_is_not_valid_unless_config_is
    zone = Zone.find('empty.com')
    zone.config = build_config(provider: 'BadProvider')

    refute_predicate zone, :valid?
  end

  def test_modifying_config_reloads_expected_zones
    original_config_path = RecordStore.config_path

    assert_equal RecordStore.expected_zones, ['empty.com', 'one-record.com']

    tmp_config = Tempfile.new(['config', '.yml'])
    tmp_config.write({'zones' => ['way-different-zone.com']}.to_yaml.gsub('---', ''))
    tmp_config.close
    RecordStore.config_path = tmp_config.path

    assert_equal RecordStore.expected_zones, ['way-different-zone.com']
  ensure
    RecordStore.config_path = original_config_path
  end

  # Records present in the Zone file, but not in DynECT are added
  def test_records_present_in_the_zone_but_not_in_dynect_are_added
    zone = Zone.find('one-record.com')
    zone.stubs(:provider).returns(mock_provider)

    changeset = zone.changeset

    assert_equal 1, changeset.additions.length
    assert changeset.removals.empty?
    assert changeset.unchanged.empty?
  end

  # Records in DynECT, but not in the Zone file are removed
  def test_records_present_in_dynect_but_not_in_the_zone_are_removed
    zone = Zone.find('empty.com')
    zone.stubs(:provider).returns(mock_provider([Record::A.new(fqdn: "a-record.#{zone.name}", ttl: 86400, address: '10.10.10.10')]))

    changeset = zone.changeset

    assert changeset.additions.empty?
    assert_equal 1, changeset.removals.length
    assert changeset.unchanged.empty?
  end

  # Records present in both DynECT and the Zone file remain unchanged
  def test_records_present_in_dynect_and_the_zone_remain_unchanged
    zone = Zone.find('one-record.com')
    zone.stubs(:provider).returns(mock_provider([Record::A.new(fqdn: "a-record.#{zone.name}", ttl: 86400, address: '10.10.10.10')]))

    changeset = zone.changeset

    assert changeset.additions.empty?
    assert changeset.removals.empty?
    assert_equal 1, changeset.unchanged.length
  end

  # Ignored records present in the Zone file, but not in DynECT
  def test_ignored_records_present_in_the_zone_but_not_in_dynect
    zone = Zone.find('one-record.com')
    zone.config = build_config(ignore_patterns: [{'fqdn' => 'a-record.one-record.com.'}])
    zone.stubs(:provider).returns(mock_provider)

    changeset = zone.changeset

    assert changeset.additions.empty?
    assert changeset.removals.empty?
    assert changeset.unchanged.empty?
  end

  # Ignored records present in the DynECT, but not in Zone
  def test_ignored_records_present_in_dynect_but_not_in_the_zone
    zone = Zone.find('empty.com')
    zone.config = build_config(ignore_patterns: [{'fqdn' => 'a-record.empty.com.'}])
    zone.stubs(:provider).returns(mock_provider([Record::A.new(fqdn: "a-record.#{zone.name}", ttl: 86400, address: '10.10.10.10')]))

    changeset = zone.changeset

    assert changeset.additions.empty?
    assert changeset.removals.empty?
    assert changeset.unchanged.empty?
  end

  # Ignored records present in DynECT and the Zone
  def test_ignored_records_present_in_dynect_and_the_zone
    zone = Zone.find('one-record.com')
    zone.config = build_config(ignore_patterns: [{'fqdn' => 'a-record.one-record.com.'}])
    zone.stubs(:provider).returns(mock_provider([Record::A.new(fqdn: "a-record.#{zone.name}", ttl: 86400, address: '10.10.10.10')]))

    changeset = zone.changeset

    assert changeset.additions.empty?
    assert changeset.removals.empty?
    assert changeset.unchanged.empty?
  end

  def test_zone_with_duplicate_records_is_invalid
    zone = valid_zone_from_records("example.com", records: [
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '10.10.10.1' },
    ])
    assert zone.valid?, zone.errors.full_messages.join("\n")

    zone = valid_zone_from_records("example.com", records: [
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '10.10.10.1' },
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '10.10.10.1' },
    ])
    refute_predicate zone, :valid?
    assert_equal "Duplicate record: [ARecord] www.example.com. 600 IN A 10.10.10.1", zone.errors[:records].first
  end

  def test_zone_with_a_records_using_different_ttls_for_same_fqdn_is_invalid
    zone = valid_zone_from_records("example.com", records: [
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '10.10.10.1' },
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '10.10.10.2' },
    ])

    assert zone.valid?, zone.errors.full_messages.join("\n")

    zone = valid_zone_from_records("example.com", records: [
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '10.10.10.1' },
      { type: 'A', fqdn: 'www.example.com.', ttl: 10, address: '10.10.10.2' },
    ])

    refute_predicate zone, :valid?
    assert_equal "All A records for www.example.com. should have the same TTL", zone.errors[:records].first
  end

  def test_zone_with_cname_records
    zone = valid_zone_from_records("example.com", records: [
      { type: 'CNAME', fqdn: 'www.example.com.', ttl: 600, cname: 'real.example.com.' },
    ])
    assert zone.valid?, zone.errors.full_messages.join("\n")

    zone = valid_zone_from_records("example.com", records: [
      { type: 'CNAME', fqdn: 'www.example.com.', ttl: 600, cname: 'real.example.com.' },
      { type: 'CNAME', fqdn: 'www.example.com.', ttl: 600, cname: 'alternative.example.com.' },
    ])
    refute_predicate zone, :valid?
    assert_equal 2, zone.errors[:records].length
    assert_equal "Multiple CNAME records are defined for www.example.com.: [CNAMERecord] www.example.com. 600 IN CNAME alternative.example.com.", zone.errors[:records][0]
    assert_equal "Multiple CNAME records are defined for www.example.com.: [CNAMERecord] www.example.com. 600 IN CNAME real.example.com.", zone.errors[:records][1]

    zone = valid_zone_from_records("example.com", records: [
      { type: 'CNAME', fqdn: 'www.example.com.', ttl: 600, cname: 'real.example.com.' },
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '1.2.3.4' },
    ])
    refute_predicate zone, :valid?
    assert_equal 1, zone.errors[:records].length
    assert_equal "A CNAME record is defined for www.example.com., so this record is not allowed: [ARecord] www.example.com. 600 IN A 1.2.3.4", zone.errors[:records].first

   zone = valid_zone_from_records("example.com", records: [
      { type: 'CNAME', fqdn: 'example.com.', ttl: 600, cname: 'www.example.com.' },
    ])
    refute_predicate zone, :valid?
    assert_equal 1, zone.errors[:records].length
    assert_equal 'A CNAME record cannot be defined on the root of the zone: [CNAMERecord] example.com. 600 IN CNAME www.example.com.', zone.errors[:records][0]
  end

  def test_filter_records
    records = [
      Record::CNAME.new(fqdn: 'www.example.com.', ttl: 600, cname: 'real.example.com.'),
      Record::A.new(fqdn: 'real.example.com.', ttl: 600, address: '1.2.3.4'),
    ]

    assert_equal 2, Zone.filter_records(records, []).length
    assert_equal 1, Zone.filter_records(records, [{type: 'CNAME'}]).length
    assert_equal 2, Zone.filter_records(records, [{type: 'TXT'}]).length
    assert_equal 1, Zone.filter_records(records, [{type: 'TXT'}, {type: 'CNAME'}]).length
    assert_equal 0, Zone.filter_records(records, [{type: 'TXT'}, {ttl: 600}]).length
    assert_equal 1, Zone.filter_records(records, [{cname: 'real.example.com.' }]).length
  end

  def test_download_downloads_zone_into_file
    with_zones_tmpdir do
      name = 'dns-test.shopify.io'
      VCR.use_cassette 'dynect_retrieve_current_records' do
        Zone.download(name, 'DynECT')
        assert File.exists?("#{RecordStore.zones_path}/#{name}.yml")

        zone = Zone.find(name)
        assert_equal [{type: 'NS', fqdn: "#{name}."}], zone.config.ignore_patterns
        assert_equal [
          Record::ALIAS.new({
            zone: 'dns-test.shopify.io',
            ttl: 60,
            fqdn: 'dns-test.shopify.io',
            alias: 'dns-test.herokuapp.com.',
            record_id: 164537809
          }),
          Record::A.new({
            zone: 'dns-test.shopify.io',
            ttl: 86400,
            fqdn: 'test-record.dns-test.shopify.io',
            address: '10.10.10.10',
            record_id: 189358987
          })
        ], zone.records
      end
    end
  end

  def test_download_creates_zone_with_alias_support_based_on_provider
    with_zones_tmpdir do
      name = 'dns-scratch.me'
      VCR.use_cassette 'dnsimple_retrieve_current_records_no_alias' do
        Zone.download(name, 'DNSimple')
      end
      assert File.exists?("#{RecordStore.zones_path}/#{name}.yml")
      zone = Zone.find(name)
      assert_predicate zone.config, :supports_alias?
    end
  end

  def test_download_creates_zone_without_alias_support_based_on_provider
    with_zones_tmpdir do
      name = 'dns-test.shopify.io'
      VCR.use_cassette 'dynect_retrieve_current_records_no_alias' do
        Zone.download(name, 'DynECT')
      end
      assert File.exists?("#{RecordStore.zones_path}/#{name}.yml")
      zone = Zone.find(name)
      refute_predicate zone.config, :supports_alias?
    end
  end

  def test_download_creates_zone_with_alias_support_based_on_records
    with_zones_tmpdir do
      name = 'dns-test.shopify.io'
      VCR.use_cassette 'dynect_retrieve_current_records' do
        Zone.download(name, 'DynECT')
      end
      zone = Zone.find(name)
      assert_predicate zone.config, :supports_alias?
    end
  end

  def test_zone_provider_returns_instantiated_zone_provider
    zone = Zone.find('one-record.com')
    assert_respond_to zone, :provider
    assert_instance_of Provider::DynECT, zone.provider
  end

  def test_zone_unchanged_describes_if_zone_matches_provider
    zone = Zone.find('one-record.com')
    zone.stubs(:provider).returns(mock_provider(zone.records))
    assert_predicate zone, :unchanged?

    zone.stubs(:provider).returns(mock_provider)
    refute_predicate zone, :unchanged?
  end

  def test_zone_write_format_file_removes_dir
    dir = "#{RecordStore.zones_path}/zone-file.com"
    Dir.mkdir(dir)
    assert Dir.exist?(dir)

    Zone.find('zone-file.com').write(format: :file)

    refute Dir.exist?(dir)
  ensure
    FileUtils.remove_entry(dir, true)
  end

  def test_zone_write_format_dir_removes_other_files_in_dir
    removed_record = "#{RecordStore.zones_path}/one-record.com/removed-record.one-record.com.yml"
    FileUtils.touch(removed_record)
    assert File.exist?(removed_record)

    Zone.find('one-record.com').write(format: :directory)

    refute File.exist?(removed_record)
  ensure
    FileUtils.remove_entry(removed_record, true)
  end

  def test_zone_write_format_dir_writes_wildcard
    with_zones_tmpdir do
      zone = Zone.new('wildcard.com', records: [{
        type: 'CNAME',
        fqdn: '*.wildcard.com',
        cname: 'wildcard.com',
        ttl: 60,
      }])

      zone.write(format: :directory)

      assert Dir.exist?("#{RecordStore.zones_path}/wildcard.com")
      assert File.exist?("#{RecordStore.zones_path}/wildcard.com/CNAME__*.yml")
    end
  end

  def test_zone_write_format_dir_writes_multiple_records
    with_zones_tmpdir do
      zone = Zone.new('two-records.com', records: [{
        type: 'A',
        fqdn: 'a-records.two-records.com',
        address: "10.10.10.10",
        ttl: 60,
      },
      {
        type: 'A',
        fqdn: 'a-records.two-records.com',
        address: "10.10.10.11",
        ttl: 60,
      }])

      zone.write(format: :directory)

      assert Dir.exist?("#{RecordStore.zones_path}/two-records.com")
      assert File.exist?("#{RecordStore.zones_path}/two-records.com/A__a-records.yml")
    end
  end

  def test_zone_validates_matching_ttls_for_records_with_same_type_and_fqdn
    valid_zone = Zone.new('matching-records.com', config: { provider: 'DynECT' }, records: [
      { type: 'TXT', fqdn: 'matching-records.com', txtdata: "unicorn", ttl: 60 },
      { type: 'TXT', fqdn: 'matching-records.com', txtdata: "walrus",  ttl: 60 },
    ])

    assert_predicate valid_zone, :valid?

    invalid_zone = Zone.new('matching-records.com', config: { provider: 'DynECT' }, records: [
      { type: 'TXT', fqdn: 'matching-records.com', txtdata: "unicorn", ttl: 60 },
      { type: 'TXT', fqdn: 'matching-records.com', txtdata: "walrus",  ttl: 3600 },
    ])

    refute_predicate invalid_zone, :valid?
    assert_equal "All TXT records for matching-records.com. should have the same TTL", invalid_zone.errors[:records].first
  end

  def test_zone_validates_support_for_alias_records
    valid_zone = Zone.new('matching-records.com', config: { provider: 'DynECT', supports_alias: true }, records: [
      { type: 'ALIAS', fqdn: 'matching-records.com', alias: 'matching-records.herokuapp.com', ttl: 60 },
    ])
    assert_predicate valid_zone, :valid?

    invalid_zone = Zone.new('matching-records.com', config: { provider: 'DynECT' }, records: [
      { type: 'ALIAS', fqdn: 'matching-records.com', alias: 'matching-records.herokuapp.com', ttl: 60 },
    ])
    refute_predicate invalid_zone, :valid?
    assert_equal 'DynECT does not support ALIAS records for matching-records.com zone', invalid_zone.errors[:records].first
  end

  def test_zone_validates_alias_points_to_root
    valid_zone = Zone.new('matching-records.com', config: { provider: 'DynECT', supports_alias: true }, records: [
      { type: 'ALIAS', fqdn: 'matching-records.com', alias: 'matching-records.herokuapp.com', ttl: 60 },
    ])
    assert_predicate valid_zone, :valid?

    invalid_zone = Zone.new('matching-records.com', config: { provider: 'DynECT', supports_alias: true }, records: [
      { type: 'ALIAS', fqdn: 'alias.matching-records.com', alias: 'matching-records.herokuapp.com', ttl: 60 },
    ])
    refute_predicate invalid_zone, :valid?
    assert_equal 'ALIAS record should be defined on the root of the zone: [ALIASRecord] alias.matching-records.com. 60 IN ALIAS matching-records.herokuapp.com.', invalid_zone.errors[:records].first
  end

  private

  def mock_provider(records = [])
    provider = mock()
    provider.stubs(:retrieve_current_records).returns(records)

    provider
  end

  def valid_zone_from_records(name, records:)
    Zone.new(name, records: records, config: {provider: 'DynECT'})
  end

  def build_config(args)
    default_args = {
      provider: 'DynECT',
      ignore_patterns: []
    }

    Zone::Config.new(default_args.merge(args))
  end

  def with_zones_tmpdir
    original_zones_path = RecordStore.zones_path
    Dir.mktmpdir do |dir|
      RecordStore.zones_path = dir
      yield
    end
  ensure
    RecordStore.zones_path = original_zones_path
  end
end
