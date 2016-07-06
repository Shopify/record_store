require 'test_helper'

class ChangesetTest < Minitest::Test
  def setup
    @cname_record = Record::CNAME.new(fqdn: 'www.example.com', ttl: 60, cname: 'www.example.org')
    @cname_record_copy = Record::CNAME.new(fqdn: 'www.example.com', ttl: 60, cname: 'www.example.org')
    @a_record = Record::A.new(fqdn: 'www.example.com', ttl: 60, address: '10.11.12.13')
    @a_record_copy = Record::A.new(fqdn: 'www.example.com', ttl: 60, address: '10.11.12.13')
  end

  def test_additions
    cs = Changeset.new(
      current_records: [],
      desired_records: [@cname_record, @a_record]
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
      current_records: [@cname_record, @a_record].each{|rr| rr.id = rand(1..100)},
      desired_records: []
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
      current_records: [@cname_record, @a_record].each{|rr| rr.id = rand(1..100)},
      desired_records: [@cname_record_copy, @a_record_copy]
    )

    assert_equal 0, cs.changes.length
    assert_equal 0, cs.additions.length
    assert_equal 0, cs.removals.length
    assert_equal 0, cs.updates.length

    assert_equal Set[@cname_record, @a_record], cs.unchanged
  end

  def test_removal_and_addition
    cs = Changeset.new(
      current_records: [@cname_record].each{|rr| rr.id = rand(1..100)},
      desired_records: [@a_record]
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
      current_records: [@cname_record].each{|rr| rr.id = rand(1..100)},
      desired_records: [@cname_record_copy]
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
      current_records: [@a_record, a_record_dup].each{|rr| rr.id = rand(1..100)},
      desired_records: [@a_record_copy]
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
      current_records: [@a_record].each{|rr| rr.id = rand(1..100)},
      desired_records: [@a_record_copy, a_record_dup]
    )

    assert_equal 2, cs.changes.length
    assert_equal 1, cs.additions.length
    assert_equal 0, cs.removals.length
    assert_equal 1, cs.updates.length
  end

  def test_additions_removals_and_changes_are_enumerable
    cs = Changeset.new(
      current_records: [@cname_record].each{|rr| rr.id = rand(1..100)},
      desired_records: [@cname_record_copy]
    )

    assert_kind_of Enumerable, cs.additions
    assert_kind_of Enumerable, cs.removals
    assert_kind_of Enumerable, cs.changes
  end
end
