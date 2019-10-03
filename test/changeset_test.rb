require 'test_helper'

class ChangesetTest < Minitest::Test
  def setup
    @cname_record = Record::CNAME.new(fqdn: 'www.example.com', ttl: 60, cname: 'www.example.org')
    @cname_record_copy = Record::CNAME.new(fqdn: 'www.example.com', ttl: 60, cname: 'www.example.org')
    @a_record = Record::A.new(fqdn: 'www.example.com', ttl: 60, address: '10.11.12.13')
    @a_record_copy = Record::A.new(fqdn: 'www.example.com', ttl: 60, address: '10.11.12.13')
    @provider = RecordStore::Provider::DNSimple
    @zone = 'dns-test.shopify.io'
  end

  def test_additions
    cs = Changeset.new(
      current_records: [],
      desired_records: [@cname_record, @a_record],
      provider: @provider,
      zone: @zone,
    )

    assert cs.changes.all? { |c| c.is_a?(Changeset::Change) }
    assert cs.changes.all?(&:addition?)
    assert_equal 2, cs.changes.length
    assert_equal 2, cs.additions.length
    assert_equal 0, cs.removals.length
    assert_equal 0, cs.updates.length
  end

  def test_removals
    cs = Changeset.new(
      current_records: [@cname_record, @a_record].each { |rr| rr.id = rand(1..100) },
      desired_records: [],
      provider: @provider,
      zone: @zone,
    )

    assert cs.changes.all? { |c| c.is_a?(Changeset::Change) }
    assert cs.changes.all?(&:removal?)
    assert_equal 2, cs.changes.length
    assert_equal 0, cs.additions.length
    assert_equal 2, cs.removals.length
    assert_equal 0, cs.updates.length
  end

  def test_no_changes
    cs = Changeset.new(
      current_records: [@cname_record, @a_record].each { |rr| rr.id = rand(1..100) },
      desired_records: [@cname_record_copy, @a_record_copy],
      provider: @provider,
      zone: @zone,
    )

    assert_equal 0, cs.changes.length
    assert_equal 0, cs.additions.length
    assert_equal 0, cs.removals.length
    assert_equal 0, cs.updates.length

    assert_equal Set[@cname_record, @a_record], cs.unchanged
  end

  def test_removal_and_addition
    cs = Changeset.new(
      current_records: [@cname_record].each { |rr| rr.id = rand(1..100) },
      desired_records: [@a_record],
      provider: @provider,
      zone: @zone,
    )

    assert_equal 2, cs.changes.length
    assert_equal 1, cs.additions.length
    assert_equal 1, cs.removals.length
    assert_equal 0, cs.updates.length

    assert_equal @a_record, cs.additions.first.record
    assert_equal @cname_record, cs.removals.first.record
  end

  def test_modifying_records_attr_is_done_through_update
    @cname_record_copy.cname = 'www.example2.org'

    cs = Changeset.new(
      current_records: [@cname_record].each { |rr| rr.id = rand(1..100) },
      desired_records: [@cname_record_copy],
      provider: @provider,
      zone: @zone,
    )

    assert_equal 1, cs.changes.length
    assert_equal 0, cs.additions.length
    assert_equal 0, cs.removals.length
    assert_equal 1, cs.updates.length
  end

  def test_diff_is_correct_when_current_records_is_larger_then_desired_records
    a_record_dup = @a_record.dup
    a_record_dup.ttl += 60
    @a_record.address = '8.8.8.8'

    cs = Changeset.new(
      current_records: [@a_record, a_record_dup].each { |rr| rr.id = rand(1..100) },
      desired_records: [@a_record_copy],
      provider: @provider,
      zone: @zone,
    )

    assert_equal 2, cs.changes.length
    assert_equal 0, cs.additions.length
    assert_equal 1, cs.removals.length
    assert_equal 1, cs.updates.length
  end

  def test_diff_is_correct_when_desired_records_is_larger_then_current_records
    a_record_dup = @a_record.dup
    a_record_dup.ttl += 60
    @a_record_copy.address = '8.8.8.8'

    cs = Changeset.new(
      current_records: [@a_record].each { |rr| rr.id = rand(1..100) },
      desired_records: [@a_record_copy, a_record_dup],
      provider: @provider,
      zone: @zone,
    )

    assert_equal 2, cs.changes.length
    assert_equal 1, cs.additions.length
    assert_equal 0, cs.removals.length
    assert_equal 1, cs.updates.length
  end

  def test_additions_removals_and_changes_are_enumerable
    cs = Changeset.new(
      current_records: [@cname_record].each { |rr| rr.id = rand(1..100) },
      desired_records: [@cname_record_copy],
      provider: @provider,
      zone: @zone,
    )

    assert_kind_of Enumerable, cs.additions
    assert_kind_of Enumerable, cs.removals
    assert_kind_of Enumerable, cs.changes
  end

  def test_changeset_build_from_creates_changeset_from_diff_between_zone_and_provider
    zone = Zone.new(
      name: 'dns-test.shopify.io',
      config: { providers: ['DynECT'] },
      records: [{
        type: 'NS',
        ttl: 86400,
        fqdn: 'dns-test.shopify.io',
        nsdname: 'ns1.p19.dynect.net.',
      }, {
        type: 'NS',
        ttl: 86400,
        fqdn: 'dns-test.shopify.io',
        nsdname: 'ns2.p19.dynect.net.',
      }, {
        type: 'NS',
        ttl: 86400,
        fqdn: 'dns-test.shopify.io',
        nsdname: 'ns3.p19.dynect.net.',
      }, {
        type: 'NS',
        ttl: 86400,
        fqdn: 'dns-test.shopify.io',
        nsdname: 'ns4.p19.dynect.net.',
      }, {
        type: 'A',
        ttl: 86400,
        fqdn: 'test-record.dns-test.shopify.io',
        address: '10.10.10.10',
      }]
    )

    # Cassette matches zone's records except with an additional ALIAS record
    VCR.use_cassette 'dynect_retrieve_current_records' do
      changeset = Changeset.build_from(provider: zone.providers[0], zone: zone)

      assert_equal 1, changeset.removals.length
      assert_kind_of Record::ALIAS, changeset.removals[0].record
      assert_predicate changeset.additions, :empty?
      refute_predicate changeset.unchanged, :empty?
    end
  end

  def test_records_with_matching_content_take_priority_when_being_updated
    current_records = [
      Record::NS.new(
        ttl: 3600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns4.dnsimple.com.',
        record_id: 1
      ),
      Record::NS.new(
        ttl: 3600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns3.dnsimple.com.',
        record_id: 2
      ),
      Record::NS.new(
        ttl: 3600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns2.dnsimple.com.',
        record_id: 3
      ),
      Record::NS.new(
        ttl: 3600,
        fqdn: 'dns-scratch.me',
        nsdname: 'ns1.dnsimple.com.',
        record_id: 4
      ),
    ]
    desired_records = current_records.map(&:dup)

    current_records += [
      Record::NS.new(
        ttl: 3600,
        fqdn: 'ns-test.dns-scratch.me',
        nsdname: 'ns1.dnsimple.com.',
        record_id: 5
      ),
      Record::NS.new(
        ttl: 3600,
        fqdn: 'ns-test.dns-scratch.me',
        nsdname: 'ns2.dnsimple.com.',
        record_id: 6
      ),
    ]

    # Swapped order is important here
    desired_records += [
      Record::NS.new(
        ttl: 600,
        fqdn: 'ns-test.dns-scratch.me',
        nsdname: 'ns2.dnsimple.com.',
      ),
      Record::NS.new(
        ttl: 600,
        fqdn: 'ns-test.dns-scratch.me',
        nsdname: 'ns1.dnsimple.com.',
      ),
    ]

    changeset = Changeset.new(
      current_records: current_records,
      desired_records: desired_records,
      provider: nil,
      zone: 'dns-scratch.me'
    )

    changes = changeset.updates.group_by(&:id)
    assert_equal 'ns1.dnsimple.com.', changes[5].first.record.nsdname
    assert_equal 'ns2.dnsimple.com.', changes[6].first.record.nsdname
  end
end
