require 'test_helper'
require 'tmpdir'

# Covers which records an implicit record template injects when `conflict_with` matches something already in the zone.
class ImplicitRecordTemplateConflictsTest < Minitest::Test
  def setup
    @original_templates_path = RecordStore.implicit_records_templates_path
    @templates_dir = File.realpath(Dir.mktmpdir('record-store-conflict-templates'))
    RecordStore.implicit_records_templates_path = @templates_dir
  end

  def teardown
    RecordStore.implicit_records_templates_path = @original_templates_path
    FileUtils.rm_rf(@templates_dir)
  end

  def test_injects_when_nothing_conflicts
    zone = build_zone(
      conflict_with: <<~YAML,
        - type: TXT
          fqdn: <%= record.fqdn %>
      YAML
      records: [a('www.example.com.', '10.0.0.1')],
    )

    assert_equal(['www.example.com.', 'www.example.com.injected.'], fqdns(zone))
  end

  def test_skips_injection_when_a_record_with_the_same_type_and_fqdn_exists
    zone = build_zone(
      conflict_with: <<~YAML,
        - type: TXT
          fqdn: <%= record.fqdn %>
      YAML
      records: [a('www.example.com.', '10.0.0.1'), txt('www.example.com.')],
    )

    assert_equal([['A', 'www.example.com.'], ['TXT', 'www.example.com.']], types_and_fqdns(zone))
  end

  def test_a_record_with_the_same_fqdn_but_a_different_type_is_not_a_conflict
    zone = build_zone(
      conflict_with: <<~YAML,
        - type: TXT
          fqdn: <%= record.fqdn %>injected.
      YAML
      records: [a('www.example.com.', '10.0.0.1'), a('www.example.com.injected.', '10.0.0.2')],
    )

    assert_includes(types_and_fqdns(zone), ['CNAME', 'www.example.com.injected.'])
  end

  def test_a_record_with_the_same_type_but_a_different_fqdn_is_not_a_conflict
    zone = build_zone(
      conflict_with: <<~YAML,
        - type: TXT
          fqdn: <%= record.fqdn %>
      YAML
      records: [a('www.example.com.', '10.0.0.1'), txt('other.example.com.')],
    )

    assert_includes(types_and_fqdns(zone), ['CNAME', 'www.example.com.injected.'])
  end

  def test_any_one_of_several_conflict_filters_blocks_injection
    zone = build_zone(
      conflict_with: <<~YAML,
        - type: TXT
          fqdn: <%= record.fqdn %>
        - type: CNAME
          fqdn: <%= record.fqdn %>injected.
      YAML
      records: [a('www.example.com.', '10.0.0.1'), cname('www.example.com.injected.', 'elsewhere.example.com.')],
    )

    assert_equal(1, zone.records.count { |r| r.fqdn == 'www.example.com.injected.' })
    assert_equal('elsewhere.example.com.', zone.records.find { |r| r.type == 'CNAME' }.cname)
  end

  def test_a_template_without_conflict_filters_always_injects
    zone = build_zone(conflict_with: nil, records: [a('www.example.com.', '10.0.0.1'), txt('www.example.com.')])

    assert_includes(types_and_fqdns(zone), ['CNAME', 'www.example.com.injected.'])
  end

  def test_an_injected_record_blocks_the_same_injection_for_a_later_source_record
    # Two A records on one fqdn both template the same CNAME. The second sees the first's CNAME and does not inject.
    zone = build_zone(
      conflict_with: <<~YAML,
        - type: CNAME
          fqdn: <%= record.fqdn %>injected.
      YAML
      records: [a('www.example.com.', '10.0.0.1'), a('www.example.com.', '10.0.0.2')],
    )

    assert_equal(1, zone.records.count { |r| r.type == 'CNAME' })
  end

  def test_an_injected_record_from_one_fqdn_blocks_injection_for_another_that_templates_the_same_fqdn
    zone = build_zone(
      injected_fqdn: 'shared.example.com.',
      conflict_with: <<~YAML,
        - type: CNAME
          fqdn: shared.example.com.
      YAML
      records: [a('one.example.com.', '10.0.0.1'), a('two.example.com.', '10.0.0.2')],
    )

    assert_equal(['one.example.com.', 'two.example.com.', 'shared.example.com.'], fqdns(zone))
  end

  def test_wildcard_fqdns_only_match_exactly
    zone = build_zone(
      conflict_with: <<~YAML,
        - type: TXT
          fqdn: "<%= record.fqdn %>"
      YAML
      records: [a('*.example.com.', '10.0.0.1'), a('www.example.com.', '10.0.0.2'), txt('*.example.com.')],
    )

    # the wildcard has a TXT record of its own, so it is skipped; www is not covered by the wildcard's TXT record
    assert_equal(['www.example.com.injected.'], fqdns(zone).grep(/injected/))
  end

  def test_regexp_conflict_filters_are_honoured
    zone = build_zone(
      conflict_with: <<~YAML,
        - fqdn: !ruby/regexp /^reserved\\./
      YAML
      records: [a('www.example.com.', '10.0.0.1'), txt('reserved.example.com.')],
    )

    # the regexp matches a record in the zone, so nothing is injected for any record
    assert_empty(fqdns(zone).grep(/injected/))
  end

  def test_conflict_filters_on_other_attributes_are_honoured
    zone = build_zone(
      conflict_with: <<~YAML,
        - type: A
          address: 10.0.0.2
      YAML
      records: [a('one.example.com.', '10.0.0.1'), a('two.example.com.', '10.0.0.2')],
    )

    assert_empty(fqdns(zone).grep(/injected/))
  end

  def test_conflict_filters_on_other_attributes_do_not_block_when_nothing_matches
    zone = build_zone(
      conflict_with: <<~YAML,
        - type: A
          address: 10.0.0.99
      YAML
      records: [a('one.example.com.', '10.0.0.1'), a('two.example.com.', '10.0.0.2')],
    )

    assert_equal(2, fqdns(zone).grep(/injected/).size)
  end

  def test_an_injected_record_is_seen_by_regexp_conflict_filters
    # The general path must also see records injected earlier in the same run.
    zone = build_zone(
      conflict_with: <<~YAML,
        - type: CNAME
          fqdn: !ruby/regexp /\\.injected\\.$/
      YAML
      records: [a('one.example.com.', '10.0.0.1'), a('two.example.com.', '10.0.0.2')],
    )

    assert_equal(['one.example.com.injected.'], fqdns(zone).grep(/injected/))
  end

  def test_excluded_records_are_not_templated
    zone = build_zone(
      except: <<~YAML,
        except_record:
        - fqdn: !ruby/regexp /^_/
      YAML
      conflict_with: nil,
      records: [a('_hidden.example.com.', '10.0.0.1'), a('www.example.com.', '10.0.0.2')],
    )

    assert_equal(['www.example.com.injected.'], fqdns(zone).grep(/injected/))
  end

  # The original implementation, kept here as the reference the optimised one has to agree with.
  def reference_generate(template, current_records)
    conflicts = lambda do |tr, records|
      (tr[:conflict_with] || []).any? do |filter|
        records.any? { |r| template.send(:record_match?, record: r, filter: filter) }
      end
    end

    current_records
      .select { |record| template.send(:should_template?, record: record) }
      .map { |record| template.send(:template_record_for, record: record, current_records: current_records) }
      .each_with_object([]) do |tr, injected|
        next if conflicts.call(tr, current_records + injected)

        injected.push(*tr.fetch(:injected_records, []).map { |y| Record.build_from_yaml_definition(y) })
      end
  end

  def test_agrees_with_the_reference_implementation_on_generated_zones
    conflict_sets = [
      "- type: TXT\n  fqdn: <%= record.fqdn %>\n",
      "- type: CNAME\n  fqdn: <%= record.fqdn %>injected.\n",
      "- type: CNAME\n  fqdn: <%= record.fqdn %>injected.\n- type: TXT\n  fqdn: <%= record.fqdn %>\n",
      "- type: CNAME\n  fqdn: !ruby/regexp /^h1\\./\n",
      "- type: A\n  address: 10.0.0.3\n",
      "- type: TXT\n  fqdn: shared.example.com.\n",
      nil,
    ]
    rng = Random.new(321)

    conflict_sets.each_with_index do |conflict_with, index|
      20.times do
        records = Array.new(rng.rand(0..12)) do
          host = "h#{rng.rand(0..4)}.example.com."
          case rng.rand(0..3)
          when 0 then a(host, "10.0.0.#{rng.rand(1..4)}")
          when 1 then txt(host)
          when 2 then cname(host, 'target.example.com.')
          else a("_h#{rng.rand(0..2)}.example.com.", '10.0.0.9')
          end
        end
        records = records.uniq
        name = "set-#{index}.yml.erb"
        write_template(name, conflict_with: conflict_with, injected_fqdn: index == 5 ? 'shared.example.com.' : nil)
        template = Zone::Config::ImplicitRecordTemplate.from_file(filename: name)
        built = records.map { |r| Record.build_from_yaml_definition(r) }

        expected = reference_generate(template, built)
        actual = template.generate_records_to_inject(current_records: built)

        message = "conflict set #{index}, records #{records.map { |r| r[:fqdn] }}"
        assert_equal(expected.map(&:to_s), actual.map(&:to_s), message)
      end
    end
  end

  private

  def a(fqdn, address)
    { type: 'A', fqdn: fqdn, ttl: 60, address: address }
  end

  def txt(fqdn)
    { type: 'TXT', fqdn: fqdn, ttl: 60, txtdata: 'hello' }
  end

  def cname(fqdn, target)
    { type: 'CNAME', fqdn: fqdn, ttl: 60, cname: target }
  end

  def fqdns(zone)
    zone.records.map(&:fqdn)
  end

  def types_and_fqdns(zone)
    zone.records.map { |r| [r.type, r.fqdn] }
  end

  def write_template(name, conflict_with:, injected_fqdn: nil, except: nil)
    body = +"each_record:\n- type: A\n"
    body << except if except
    body << "conflict_with:\n#{conflict_with}" if conflict_with
    fqdn = injected_fqdn || '<%= record.fqdn %>injected.'
    body << "injected_records:\n- type: CNAME\n  ttl: 3600\n  fqdn: \"#{fqdn}\"\n"
    body << "  cname: target.injected.example.com.\n"
    File.write(File.join(@templates_dir, name), body)
  end

  def build_zone(conflict_with:, records:, injected_fqdn: nil, except: nil)
    write_template('t.yml.erb', conflict_with: conflict_with, injected_fqdn: injected_fqdn, except: except)

    Zone.new(
      name: 'example.com',
      config: { providers: ['DynECT'], implicit_records_templates: ['t.yml.erb'] },
      records: records,
    )
  end
end
