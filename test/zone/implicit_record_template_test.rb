require 'test_helper'
require 'tmpdir'

class ImplicitRecordTemplateTest < Minitest::Test
  InvalidTemplateFilename = Zone::Config::ImplicitRecordTemplate::InvalidTemplateFilename

  def setup
    @original_templates_path = RecordStore.implicit_records_templates_path
    @root = File.realpath(Dir.mktmpdir('record-store-templates'))
    @templates_dir = File.join(@root, 'templates')
    @outside_dir = File.join(@root, 'outside')
    @marker = File.join(@root, 'rendered')
    FileUtils.mkdir_p([@templates_dir, @outside_dir])

    File.write(File.join(@templates_dir, 'cname.yml.erb'), <<~YAML)
      each_record:
      - type: A
      injected_records:
      - type: CNAME
        ttl: 3600
        fqdn: <%= record.fqdn %>injected.com.
        cname: <%= record.fqdn %>injected.cname.com.
    YAML
    File.write(File.join(@outside_dir, 'payload.yml.erb'), payload_template)

    RecordStore.implicit_records_templates_path = @templates_dir
  end

  def teardown
    RecordStore.implicit_records_templates_path = @original_templates_path
    FileUtils.rm_rf(@root)
  end

  def test_loads_template_by_plain_file_name
    zone = build_zone('cname.yml.erb')

    assert_includes(
      zone.records,
      Record::CNAME.new(
        fqdn: 'a.implicit-template.com.injected.com.',
        ttl: 3600,
        cname: 'a.implicit-template.com.injected.cname.com.',
      ),
    )
  end

  def test_renders_erb_from_templates_inside_the_templates_directory
    # Proves the side-effect marker used by the rejection tests below actually fires on render.
    File.write(File.join(@templates_dir, 'payload.yml.erb'), payload_template)

    build_zone('payload.yml.erb')

    assert_path_exists(@marker)
  end

  def test_rejects_parent_directory_traversal
    error = assert_raises(InvalidTemplateFilename) { build_zone('../outside/payload.yml.erb') }

    assert_match(/must be a plain file name/, error.message)
    assert_match(/zone implicit-template\.com/, error.message)
    refute_path_exists(@marker)
  end

  def test_rejects_absolute_path
    assert_raises(InvalidTemplateFilename) { build_zone(File.join(@outside_dir, 'payload.yml.erb')) }
    refute_path_exists(@marker)
  end

  def test_rejects_path_into_subdirectory
    FileUtils.mkdir_p(File.join(@templates_dir, 'nested'))
    FileUtils.cp(File.join(@templates_dir, 'cname.yml.erb'), File.join(@templates_dir, 'nested', 'cname.yml.erb'))

    assert_raises(InvalidTemplateFilename) { build_zone('nested/cname.yml.erb') }
  end

  def test_rejects_dot_entries_and_empty_names
    ['', '.', '..'].each do |name|
      assert_raises(InvalidTemplateFilename, "expected #{name.inspect} to be rejected") { build_zone(name) }
    end
  end

  def test_rejects_symlink_that_points_outside_the_templates_directory
    File.symlink(File.join(@outside_dir, 'payload.yml.erb'), File.join(@templates_dir, 'link.yml.erb'))

    error = assert_raises(InvalidTemplateFilename) { build_zone('link.yml.erb') }

    assert_match(/resolves outside/, error.message)
    refute_path_exists(@marker)
  end

  def test_missing_template_still_raises_enoent
    assert_raises(Errno::ENOENT) { build_zone('missing.yml.erb') }
  end

  private

  def build_zone(template)
    Zone.new(
      name: 'implicit-template.com',
      config: { providers: ['DynECT'], implicit_records_templates: [template] },
      records: [{ type: 'A', fqdn: 'a.implicit-template.com.', address: '10.10.10.10', ttl: 60 }],
    )
  end

  def payload_template
    <<~YAML
      each_record:
      - type: A
      injected_records: []
      marker: '<% File.write(#{@marker.inspect}, "rendered") %>'
    YAML
  end
end
