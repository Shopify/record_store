require 'test_helper'

class ZoneTest < Minitest::Test
  def setup
    super
    Zone.reset
  end

  def test_find_returns_zone_by_name
    zone = Zone.find('one-record.com')

    assert_instance_of(Zone, zone)
    assert_predicate(zone, :valid?)
  end

  def test_find_returns_zone_by_name_in_single_file
    zone = Zone.find('zone-file.com')

    assert_instance_of(Zone, zone)
    assert_predicate(zone, :valid?)
  end

  def test_find_can_load_multiple_records_for_a_single_type
    zone = Zone.find('two-records.com')
    assert_equal(2, zone.records.size)
  end

  def test_find_merges_records_from_dir_files
    zone = Zone.find('merged-records.com')
    assert_equal(2, zone.records.size)
  end

  def test_find_returns_nil_for_missing_zone
    assert_nil(Zone.find('missing-zone.com'))
  end

  def test_zone_all_includes_ignored_records
    zone = Zone.find('ignored-ns.com')
    assert_equal(1, zone.records.size)
    assert_equal(5, zone.all.size)
  end

  def test_zone_has_configurable_ignore_pattern
    zone = Zone.find('one-record.com')
    assert_equal(1, zone.records.size)

    zone.config = build_config(ignore_patterns: [{ 'fqdn' => 'a-record.one-record.com.' }])
    assert_equal(0, zone.records.size)

    zone.config = build_config(ignore_patterns: [{ 'match' => 'exact', 'fqdn' => 'a-record.one-record.com.' }])
    assert_equal(0, zone.records.size)

    zone.config = build_config(ignore_patterns: [])
    assert_equal(1, zone.records.size)
  end

  def test_zone_has_configurable_ignore_regexes
    zone = Zone.find('one-record.com')
    assert_equal(1, zone.records.size)

    zone.config = build_config(ignore_patterns: [{ 'match' => 'regex', 'fqdn' => 'a-r.cord.*' }])
    assert_equal(0, zone.records.size)

    zone.config = build_config(ignore_patterns: [{ 'match' => 'regex', 'fqdn' => 'filter-nothing' }])
    assert_equal(1, zone.records.size)

    zone.config = build_config(ignore_patterns: [])
    assert_equal(1, zone.records.size)
  end

  def test_zone_ignores_unknown_ignore_pattern_types
    zone = Zone.find('one-record.com')
    assert_equal(1, zone.records.size)

    zone.config = build_config(ignore_patterns: [{ 'match' => 'unknown', 'fqdn' => 'a-r.cord.*' }])
    assert_equal(1, zone.records.size)

    zone.config = build_config(ignore_patterns: [{ 'match' => 'unknown', 'fqdn' => 'a-record.one-record.com.' }])
    assert_equal(1, zone.records.size)
  end

  def test_zone_has_config_with_provider
    zone = Zone.find('empty.com')

    assert_respond_to(zone, :config)
    assert_instance_of(Zone::Config, zone.config)
  end

  def test_zone_is_invalid_if_provider_does_not_support_record_type
    supported_record_types = Provider::DynECT.record_types - ['ALIAS']
    Provider::DynECT.stubs(:record_types).returns(supported_record_types)

    zone = Zone.find('empty.com')
    assert_equal(['DynECT'], zone.config.providers)
    zone.records = [Record::ALIAS.new(fqdn: zone.name, ttl: 60, alias: "alias.#{zone.name}")]

    refute_predicate(zone, :valid?)
  end

  def test_zone_is_not_valid_unless_config_is
    zone = Zone.find('empty.com')
    zone.config = build_config(providers: ['BadProvider'])

    refute_predicate(zone, :valid?)
  end

  def test_modifying_config_reloads_expected_zones
    original_config_path = RecordStore.config_path

    assert_equal(RecordStore.expected_zones, ['empty.com', 'one-record.com', 'two-providers.com'])

    tmp_config = Tempfile.new(['config', '.yml'])
    tmp_config.write({ 'zones' => ['way-different-zone.com'] }.to_yaml.gsub('---', ''))
    tmp_config.close
    RecordStore.config_path = tmp_config.path

    assert_equal(RecordStore.expected_zones, ['way-different-zone.com'])
  ensure
    RecordStore.config_path = original_config_path
  end

  def test_zone_with_duplicate_records_is_invalid
    zone = valid_zone_from_records("example.com", records: [
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '10.10.10.1' },
    ])
    assert(zone.valid?, zone.errors.full_messages.join("\n"))

    zone = valid_zone_from_records("example.com", records: [
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '10.10.10.1' },
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '10.10.10.1' },
    ])
    refute_predicate(zone, :valid?)
    assert_equal("Duplicate record: [ARecord] www.example.com. 600 IN A 10.10.10.1", zone.errors[:records].first)
  end

  def test_zone_with_a_records_using_different_ttls_for_same_fqdn_is_invalid
    zone = valid_zone_from_records("example.com", records: [
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '10.10.10.1' },
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '10.10.10.2' },
    ])

    assert(zone.valid?, zone.errors.full_messages.join("\n"))

    zone = valid_zone_from_records("example.com", records: [
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '10.10.10.1' },
      { type: 'A', fqdn: 'www.example.com.', ttl: 10, address: '10.10.10.2' },
    ])

    refute_predicate(zone, :valid?)
    assert_equal("All A records for www.example.com. should have the same TTL", zone.errors[:records].first)
  end

  def test_zone_with_cname_records
    zone = valid_zone_from_records("example.com", records: [
      { type: 'CNAME', fqdn: 'www.example.com.', ttl: 600, cname: 'real.example.com.' },
    ])
    assert(zone.valid?, zone.errors.full_messages.join("\n"))

    zone = valid_zone_from_records("example.com", records: [
      { type: 'CNAME', fqdn: 'www.example.com.', ttl: 600, cname: 'real.example.com.' },
      { type: 'CNAME', fqdn: 'www.example.com.', ttl: 600, cname: 'alternative.example.com.' },
    ])
    refute_predicate(zone, :valid?)
    assert_equal(2, zone.errors[:records].length)
    assert_equal(
      "Multiple CNAME records are defined for www.example.com.: [CNAMERecord] www.example.com. " \
        "600 IN CNAME alternative.example.com.",
      zone.errors[:records][0],
    )
    assert_equal(
      "Multiple CNAME records are defined for www.example.com.: [CNAMERecord] www.example.com. " \
        "600 IN CNAME real.example.com.",
      zone.errors[:records][1],
    )

    zone = valid_zone_from_records("example.com", records: [
      { type: 'CNAME', fqdn: 'www.example.com.', ttl: 600, cname: 'real.example.com.' },
      { type: 'A', fqdn: 'www.example.com.', ttl: 600, address: '1.2.3.4' },
    ])
    refute_predicate(zone, :valid?)
    assert_equal(1, zone.errors[:records].length)
    assert_equal(
      "A CNAME record is defined for www.example.com., so this record is not allowed: " \
        "[ARecord] www.example.com. 600 IN A 1.2.3.4",
      zone.errors[:records].first,
    )

    zone = valid_zone_from_records("example.com", records: [
      { type: 'CNAME', fqdn: 'example.com.', ttl: 600, cname: 'www.example.com.' },
    ])
    refute_predicate(zone, :valid?)
    assert_equal(1, zone.errors[:records].length)
    assert_equal(
      'A CNAME record cannot be defined on the root of the zone: [CNAMERecord] example.com. ' \
        '600 IN CNAME www.example.com.',
      zone.errors[:records][0],
    )
  end

  def test_zone_with_alias_conflicts
    zone = Zone.new(
      name: 'example.com',
      config: { providers: ['DynECT'], supports_alias: true },
    )

    zone.records = [
      Record::ALIAS.new(fqdn: 'www.example.com.', ttl: 600, alias: 'other.example.com.'),
      Record::TXT.new(fqdn: 'www.example.com.', ttl: 600, txtdata: 'example'),
    ]

    assert_predicate(zone, :valid?)

    zone.records = [
      Record::ALIAS.new(fqdn: 'www.example.com.', ttl: 600, alias: 'other.example.com.'),
      Record::A.new(fqdn: 'www.example.com.', ttl: 600, address: '1.2.3.4'),
    ]

    refute_predicate(zone, :valid?)
    assert_match(/A record conflicts with ALIAS/, zone.errors[:records].first)

    zone.records = [
      Record::ALIAS.new(fqdn: 'www.example.com.', ttl: 600, alias: 'other.example.com.'),
      Record::AAAA.new(fqdn: 'www.example.com.', ttl: 600, address: '2001:db8:85a3::ea75:1337:beef'),
    ]

    refute_predicate(zone, :valid?)
    assert_match(/AAAA record conflicts with ALIAS/, zone.errors[:records].first)
  end

  def test_filter_records
    records = [
      Record::CNAME.new(fqdn: 'www.example.com.', ttl: 600, cname: 'real.example.com.'),
      Record::A.new(fqdn: 'real.example.com.', ttl: 600, address: '1.2.3.4'),
    ]

    assert_equal(2, Zone.filter_records(records, []).length)
    assert_equal(1, Zone.filter_records(records, [Zone::Config::IgnorePattern.new(type: 'CNAME')]).length)
    assert_equal(2, Zone.filter_records(records, [Zone::Config::IgnorePattern.new(type: 'TXT')]).length)
    assert_equal(1, Zone.filter_records(records, [
      Zone::Config::IgnorePattern.new(type: 'TXT'),
      Zone::Config::IgnorePattern.new(type: 'CNAME'),
    ]).length)
    assert_equal(0, Zone.filter_records(records, [
      Zone::Config::IgnorePattern.new(type: 'TXT'),
      Zone::Config::IgnorePattern.new(ttl: 600),
    ]).length)
    assert_equal(1, Zone.filter_records(records, [Zone::Config::IgnorePattern.new(cname: 'real.example.com.')]).length)
  end

  def test_download_downloads_zone_into_file
    with_zones_tmpdir do
      name = 'dns-test.shopify.io'
      VCR.use_cassette('dynect_retrieve_current_records') do
        Zone.download(name, 'DynECT')
        assert(File.exist?("#{RecordStore.zones_path}/#{name}.yml"))

        zone = Zone.find(name)
        assert_equal([{ type: 'NS', fqdn: "#{name}." }], zone.config.ignore_patterns.map(&:to_hash))
        assert_equal(
          [
            Record::ALIAS.new(
              zone: 'dns-test.shopify.io',
              ttl: 60,
              fqdn: 'dns-test.shopify.io',
              alias: 'dns-test.herokuapp.com.',
              record_id: 164537809,
            ),
            Record::A.new(
              zone: 'dns-test.shopify.io',
              ttl: 86400,
              fqdn: 'test-record.dns-test.shopify.io',
              address: '10.10.10.10',
              record_id: 189358987,
            ),
          ],
          zone.records,
        )
      end
    end
  end

  def test_download_creates_zone_with_alias_support_based_on_provider
    with_zones_tmpdir do
      name = 'dns-scratch.me'
      VCR.use_cassette('dnsimple_retrieve_current_records_no_alias') do
        Zone.download(name, 'DNSimple')
      end
      assert(File.exist?("#{RecordStore.zones_path}/#{name}.yml"))
      zone = Zone.find(name)
      assert_predicate(zone.config, :supports_alias?)
    end
  end

  def test_download_creates_zone_without_alias_support_based_on_provider
    with_zones_tmpdir do
      name = 'dns-test.shopify.io'
      VCR.use_cassette('dynect_retrieve_current_records_no_alias') do
        Zone.download(name, 'DynECT')
      end
      assert(File.exist?("#{RecordStore.zones_path}/#{name}.yml"))
      zone = Zone.find(name)
      refute_predicate(zone.config, :supports_alias?)
    end
  end

  def test_download_creates_zone_with_alias_support_based_on_records
    with_zones_tmpdir do
      name = 'dns-test.shopify.io'
      VCR.use_cassette('dynect_retrieve_current_records') do
        Zone.download(name, 'DynECT')
      end
      zone = Zone.find(name)
      assert_predicate(zone.config, :supports_alias?)
    end
  end

  def test_zone_providers_returns_provider_classes
    zone = Zone.find('two-providers.com')

    assert_respond_to(zone, :providers)
    assert_includes(zone.providers, Provider::DynECT)
    assert_includes(zone.providers, Provider::DNSimple)
  end

  def test_zone_unchanged_describes_if_zone_matches_provider
    zone = Zone.find('one-record.com')

    zone.stubs(:build_changesets).returns([empty_changeset])
    assert_predicate(zone, :unchanged?)
  end

  def test_zone_changed_if_provider_and_zone_dont_match
    zone = Zone.find('one-record.com')

    zone.stubs(:build_changesets).returns([populated_changeset])
    refute_predicate(zone, :unchanged?)
  end

  def test_detects_shadowed_records_present_in_zone
    shadowed_zone = Zone.find('shadowed-zone.com')
    refute_predicate(shadowed_zone, :valid?, "This record was shadowed, but testing showed it as valid")
    warning_msg = "Record b.a.shadowed-zone.com. CNAME in Zone shadowed-zone.com. " \
      "is shadowed by a.shadowed-zone.com and will be ignored"
    assert_equal(warning_msg, shadowed_zone.errors[:records].first)
  end

  def test_ensures_zone_is_valid_without_shadowed_records_but_contains_similar_subdomains
    unshadowed_zone = Zone.find('unshadowed-zone.com')
    assert_predicate(unshadowed_zone, :valid?, "This record was not shadowed")
  end

  def test_ns_record_is_not_shadowing_another_ns_record
    shadowed_ns_zone = Zone.find('shadowed-ns-zone.com')
    refute_predicate(shadowed_ns_zone, :valid?, "This zone contains a shadowed NS record")
  end

  def test_shadowed_fqdn_record_overlaps_shadowed_ns_record
    shadowed_a_zone = Zone.find('shadowed-a-zone.com')
    refute_predicate(shadowed_a_zone, :valid?, "This zone contains a shadowed A record")
  end

  def test_a_record_not_detected_as_shadowing_an_ns_record
    shadowed_b_zone = Zone.find('shadowed-b-zone.com')
    assert_predicate(shadowed_b_zone, :valid?, "This zone contains a shadowed NS record")
  end

  def test_zone_unchanged_describes_if_zone_matches_multiple_provider_empty_changeset
    zone = Zone.find('two-providers.com')

    zone.stubs(:build_changesets).returns([
      empty_changeset,
      empty_changeset,
    ])
    assert_predicate(zone, :unchanged?)
  end

  def test_zone_unchanged_describes_if_zone_matches_multiple_provider
    zone = Zone.find('two-providers.com')

    zone.stubs(:build_changesets).returns([
      empty_changeset,
      populated_changeset,
    ])
    refute_predicate(zone, :unchanged?)
  end

  def test_zone_write_format_file_removes_dir
    dir = "#{RecordStore.zones_path}/zone-file.com"
    Dir.mkdir(dir)
    assert(Dir.exist?(dir))

    Zone.find('zone-file.com').write(format: :file)

    refute(Dir.exist?(dir))
  ensure
    FileUtils.remove_entry(dir, true)
  end

  def test_zone_write_format_dir_removes_other_files_in_dir
    removed_record = "#{RecordStore.zones_path}/one-record.com/removed-record.one-record.com.yml"
    FileUtils.touch(removed_record)
    assert(File.exist?(removed_record))

    Zone.find('one-record.com').write(format: :directory)

    refute(File.exist?(removed_record))
  ensure
    FileUtils.remove_entry(removed_record, true)
  end

  def test_zone_write_format_dir_writes_wildcard
    with_zones_tmpdir do
      zone = Zone.new(name: 'wildcard.com', records: [{
        type: 'CNAME',
        fqdn: '*.wildcard.com',
        cname: 'wildcard.com',
        ttl: 60,
      }])

      zone.write(format: :directory)

      assert(Dir.exist?("#{RecordStore.zones_path}/wildcard.com"))
      assert(File.exist?("#{RecordStore.zones_path}/wildcard.com/CNAME__*.yml"))
    end
  end

  def test_zone_write_format_dir_writes_multiple_records
    with_zones_tmpdir do
      zone = Zone.new(name: 'two-records.com', records: [
        { type: 'A', fqdn: 'a-records.two-records.com', address: "10.10.10.10", ttl: 60 },
        { type: 'A', fqdn: 'a-records.two-records.com', address: "10.10.10.11", ttl: 60 },
      ])

      zone.write(format: :directory)

      assert(Dir.exist?("#{RecordStore.zones_path}/two-records.com"))
      assert(File.exist?("#{RecordStore.zones_path}/two-records.com/A__a-records.yml"))
    end
  end

  def test_zone_validates_matching_ttls_for_records_with_same_type_and_fqdn
    valid_zone = Zone.new(name: 'matching-records.com', config: { providers: ['DynECT'] }, records: [
      { type: 'TXT', fqdn: 'matching-records.com', txtdata: "unicorn", ttl: 60 },
      { type: 'TXT', fqdn: 'matching-records.com', txtdata: "walrus",  ttl: 60 },
    ])

    assert_predicate(valid_zone, :valid?)

    invalid_zone = Zone.new(name: 'matching-records.com', config: { providers: ['DynECT'] }, records: [
      { type: 'TXT', fqdn: 'matching-records.com', txtdata: "unicorn", ttl: 60 },
      { type: 'TXT', fqdn: 'matching-records.com', txtdata: "walrus",  ttl: 3600 },
    ])

    refute_predicate(invalid_zone, :valid?)
    assert_equal(
      "All TXT records for matching-records.com. " \
        "should have the same TTL",
      invalid_zone.errors[:records].first,
    )
  end

  def test_zone_validates_no_empty_non_terminal
    valid_zone = Zone.new(
      name: 'domain.example.com',
      config: { providers: ['NS1', 'DNSimple'] },
      records: [
        { type: 'CNAME', fqdn: '*.domain.example.com', cname: 'target1.example.com', ttl: 60 },
        { type: 'CNAME', fqdn: 'b.domain.example.com', cname: 'target2.example.com', ttl: 60 },
        { type: 'CNAME', fqdn: 'a.b.domain.example.com', cname: 'target3.example.com', ttl: 60 },
      ],
    )
    assert_predicate(valid_zone, :valid?)

    valid_zone = Zone.new(
      name: 'domain.example.com',
      config: { providers: ['DNSimple'] },
      records: [
        { type: 'CNAME', fqdn: '*.domain.example.com', cname: 'target1.example.com', ttl: 60 },
        { type: 'CNAME', fqdn: 'a.b.domain.example.com', cname: 'target3.example.com', ttl: 60 },
      ],
    )
    assert_predicate(valid_zone, :valid?)

    invalid_zone = Zone.new(
      name: 'domain.example.com',
      config: { providers: ['NS1', 'DNSimple'] },
      records: [
        { type: 'CNAME', fqdn: '*.domain.example.com', cname: 'target1.example.com', ttl: 60 },
        { type: 'CNAME', fqdn: 'a.b.domain.example.com', cname: 'target3.example.com', ttl: 60 },
      ],
    )
    refute_predicate(invalid_zone, :valid?)
    assert_match(/found empty non-terminal/, invalid_zone.errors[:records].first)
  end

  def test_zone_validates_support_for_alias_records
    valid_zone = Zone.new(
      name: 'matching-records.com',
      config: { providers: ['DynECT'], supports_alias: true },
      records: [{ type: 'ALIAS', fqdn: 'matching-records.com', alias: 'matching-records.herokuapp.com', ttl: 60 }],
    )
    assert_predicate(valid_zone, :valid?)

    invalid_zone = Zone.new(name: 'matching-records.com', config: { providers: ['DynECT'] }, records: [
      { type: 'ALIAS', fqdn: 'matching-records.com', alias: 'matching-records.herokuapp.com', ttl: 60 },
    ])
    refute_predicate(invalid_zone, :valid?)
    assert_match(/does not support ALIAS records/, invalid_zone.errors[:records].first)
  end

  def test_modified_returns_all_zones_with_changes
    zone_a = Zone.find('one-record.com')
    zone_a.stubs(:build_changesets).returns([populated_changeset])

    zone_b = Zone.find('two-providers.com')
    zone_b.stubs(:build_changesets).returns([empty_changeset])

    Zone.stubs(:all).returns([zone_a, zone_b])

    modified_zones = Zone.modified
    assert_equal(1, modified_zones.length)
    assert_equal(zone_a, modified_zones[0])
  end

  def test_zone_downcases_fqdn
    zone = Zone.find('mixed-case-fqdn.com')

    assert_equal(2, zone.records.size)

    fqdns = zone.records.map(&:fqdn)
    assert_equal(fqdns.map(&:downcase), fqdns)
  end

  def test_zone_validates_support_for_sshfp_records
    valid_zone = Zone.new(
      name: 'test.recordstore.io',
      config: { providers: ['DNSimple'] },
      records: [{
        type: 'SSHFP',
        fqdn: 'test.recordstore.io',
        algorithm: Record::SSHFP::Algorithms::RSA,
        fptype: Record::SSHFP::FingerprintTypes::SHA_256,
        fingerprint: '0',
        ttl: 60,
      }],
    )
    assert_predicate(valid_zone, :valid?)

    ['NS1', 'DynECT', 'GoogleCloudDNS'].each do |provider|
      invalid_zone = Zone.new(
        name: 'test.recordstore.io',
        config: { providers: [provider] },
        records: [{
          type: 'SSHFP',
          fqdn: 'test.recordstore.io',
          algorithm: Record::SSHFP::Algorithms::RSA,
          fptype: Record::SSHFP::FingerprintTypes::SHA_256,
          fingerprint: '0',
          ttl: 60,
        }],
      )
      refute_predicate(invalid_zone, :valid?)
      assert_match(/SSHFP is not a supported/, invalid_zone.errors[:records].first)
    end
  end

  def test_zone_validates_support_for_ptr_records
    ['DNSimple', 'NS1'].each do |provider|
      valid_zone = Zone.new(
        name: '1.2.3.4.in-addr.arpa',
        config: { providers: [provider] },
        records: [{
          type: 'PTR',
          fqdn: '1.2.3.4.in-addr.arpa',
          ttl: 60,
          ptrdname: 'example.com.',
        }],
      )
      assert_predicate(valid_zone, :valid?)
    end

    ['DynECT', 'GoogleCloudDNS'].each do |provider|
      invalid_zone = Zone.new(
        name: '1.2.3.4.in-addr.arpa',
        config: { providers: [provider] },
        records: [{
          type: 'PTR',
          fqdn: '1.2.3.4.in-addr.arpa',
          ttl: 60,
          ptrdname: 'example.com.',
        }],
      )
      refute_predicate(invalid_zone, :valid?)
      assert_match(/PTR is not a supported/, invalid_zone.errors[:records].first)
    end
  end

  def test_zone_validates_no_duplicate_keys
    zone = Zone.find('dup-keys.com')
    assert(!zone.valid?)
    assert_equal(zone.errors.size, 1)
    err = zone.errors.first
    assert_equal(err.attribute, :records)
    assert(err.message.match(/multiple definitions for keys \["cname", "fqdn", "ttl", "type"\]/))
  end

  def test_implicit_record_injection_only_injects_for_matching_records
    zone = Zone.new(
      name: 'zone-with-implicit-records.com',
      config: { providers: ['DynECT'], ignore_patterns: [], implicit_records_templates: ['dummy-implicit.yml.erb'] },
      records: [
        { type: 'A', fqdn: 'a.test.com.', address: '10.10.10.10', ttl: 86400 },
        { type: 'ALIAS', fqdn: 'a.test.alias.com.', alias: 'a.test.com.', ttl: 86400 },
      ],
    )
    expected = [
      Record::A.new(fqdn: 'a.test.com.', ttl: 86400, address: '10.10.10.10'),
      Record::ALIAS.new(fqdn: 'a.test.alias.com.', alias: 'a.test.com.', ttl: 86400),
      Record::CNAME.new(fqdn: 'a.test.com.injected.com.', ttl: 3600, cname: 'a.test.com.injected.cname.com.'),
    ]

    assert_equal(expected, zone.records)
  end

  def implicit_record_injection_does_not_inject_template_records_if_they_conflict_with_existing_records
    zone = Zone.new(
      name: 'zone-with-implicit-records.com',
      config: { providers: ['DynECT'], ignore_patterns: [], implicit_records_templates: ['dummy-implicit.yml.erb'] },
      records: [
        { type: 'A', fqdn: 'a.test.com.', address: '10.10.10.10', ttl: 86400 },
        { type: 'ALIAS', fqdn: 'a.test.alias.com.', alias: 'a.test.com.', ttl: 86400 },
        { type: 'TXT', fqdn: 'a.test.com.injected.com.', txtdata: 'abc123', ttl: 86400 },
      ],
    )
    expected = [
      Record::A.new(fqdn: 'a.test.com.', ttl: 86400, address: '10.10.10.10'),
      Record::ALIAS.new(fqdn: 'a.test.alias.com.', alias: 'a.test.com.', ttl: 86400),
      Record::TXT.new(fqdn: 'a.test.com.injected.com.', txtdata: 'abc123', ttl: 86400),
    ]

    assert_equal(expected, zone.records)
  end

  def implicit_record_injection_does_not_inject_template_records_if_they_match_except
    zone = Zone.new(
      name: 'zone-with-implicit-records.com',
      config: { providers: ['DynECT'], ignore_patterns: [], implicit_records_templates: ['dummy-implicit.yml.erb'] },
      records: [
        { type: 'A', fqdn: '_a.test.com.', address: '10.10.10.10', ttl: 86400 },
        { type: 'ALIAS', fqdn: 'a.test.alias.com.', alias: '_a.test.com.', ttl: 86400 },
      ],
    )
    expected = [
      Record::A.new(fqdn: '_a.test.com.', ttl: 86400, address: '10.10.10.10'),
      Record::ALIAS.new(fqdn: 'a.test.alias.com.', alias: '_a.test.com.', ttl: 86400),
    ]

    assert_equal(expected, zone.records)
  end

  def implicit_record_injection_does_not_occur_if_no_implicit_records_templates_are_provided
    zone = Zone.new(
      name: 'zone-with-implicit-records.com',
      config: { providers: ['DynECT'], ignore_patterns: [], implicit_records_templates: [] },
      records: [
        { type: 'A', fqdn: 'a.test.com.', address: '10.10.10.10', ttl: 86400 },
        { type: 'ALIAS', fqdn: 'a.test.alias.com.', alias: 'a.test.com.', ttl: 86400 },
      ],
    )
    expected = [
      Record::A.new(fqdn: 'a.test.com.', ttl: 86400, address: '10.10.10.10'),
      Record::ALIAS.new(fqdn: 'a.test.alias.com.', alias: 'a.test.com.', ttl: 86400),
    ]

    assert_equal(expected, zone.records)
  end

  def test_fetch_authority
    zone = Zone.new(name: 'example.com')
    nameservers = zone.fetch_authority
    expected = [
      Record::NS.new(fqdn: 'example.com', ttl: 172_800, nsdname: 'a.iana-servers.net.'),
      Record::NS.new(fqdn: 'example.com', ttl: 172_800, nsdname: 'b.iana-servers.net.'),
    ]
    assert_equal(expected, nameservers)
  end

  def test_fetch_authority_handles_unreachable_host
    zone = Zone.new(name: 'shopify.ph')

    zone.expects(:fetch_soa).with('b.root-servers.net')
      .yields(mock_reply('ph.', ['ph.communitydns.net', '1.ns.ph']), mock_name('shopify.ph.'))

    zone.expects(:fetch_soa).with('ph.communitydns.net')
      .raises(Errno::EHOSTUNREACH)

    zone.expects(:fetch_soa).with('1.ns.ph')
      .returns(
        [
          Record::NS.new(fqdn: 'shopify.ph', ttl: 86_400, nsdname: 'ns1.dnsimple.com.'),
          Record::NS.new(fqdn: 'shopify.ph', ttl: 86_400, nsdname: 'ns2.dnsimple.com.'),
          Record::NS.new(fqdn: 'shopify.ph', ttl: 86_400, nsdname: 'ns3.dnsimple.com.'),
          Record::NS.new(fqdn: 'shopify.ph', ttl: 86_400, nsdname: 'ns4.dnsimple.com.'),
        ],
      )

    nameservers = zone.fetch_authority('b.root-servers.net')
    expected = [
      Record::NS.new(fqdn: 'shopify.ph', ttl: 86_400, nsdname: 'ns1.dnsimple.com.'),
      Record::NS.new(fqdn: 'shopify.ph', ttl: 86_400, nsdname: 'ns2.dnsimple.com.'),
      Record::NS.new(fqdn: 'shopify.ph', ttl: 86_400, nsdname: 'ns3.dnsimple.com.'),
      Record::NS.new(fqdn: 'shopify.ph', ttl: 86_400, nsdname: 'ns4.dnsimple.com.'),
    ]
    assert_equal(expected, nameservers)
  end

  def test_fetch_authority_handles_nxdomain
    zone = Zone.new(name: 'bc1a82e63eede5c2962efb11df850eea7d4c9a2a-nxdomain.com')
    nameservers = zone.fetch_authority
    assert_equal(nameservers.first.fqdn, 'com.')
  end

  def test_fetch_authority_handles_nxdomain_for_tld
    zone = Zone.new(name: 'nxdomain.bc1a82e63eede5c2962efb11df850eea7d4c9a2a')
    nameservers = zone.fetch_authority
    assert_nil(nameservers)
  end

  def test_loads_zones_alphabetically
    zones = Zone.defined.keys
    assert_equal(zones.sort, zones)
  end

  private

  def mock_name(name)
    n = mock('name')
    n.stubs(:to_s).returns(name)
    n
  end

  def mock_ns(name)
    ns = mock('ns')
    ns.stubs(name: name)
    ns
  end

  def mock_reply(name, nameservers)
    reply = mock('reply')
    reply.stubs(:answer).returns([])
    reply.stubs(:authority).returns(nameservers.map { |ns| [mock_name(name), 86400, mock_ns(ns)] })
    reply
  end

  def valid_zone_from_records(name, records:)
    Zone.new(name: name, records: records, config: { providers: ['DynECT'] })
  end

  def build_config(args)
    default_args = {
      providers: ['DynECT'],
      ignore_patterns: [],
      implicit_records_templates: [],
    }

    Zone::Config.new(**default_args.merge(args))
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

  def empty_changeset
    Changeset.new(
      zone: Zone.find('one-record.com'),
      provider: 'LolWatProvider',
      desired_records: [],
      current_records: [],
    )
  end

  def populated_changeset
    Changeset.new(
      zone: Zone.find('one-record.com'),
      provider: 'LolWatProvider',
      desired_records: [Record::A.new(fqdn: 'real.example.com.', ttl: 600, address: '1.2.3.4')],
      current_records: [],
    )
  end
end
