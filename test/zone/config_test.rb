require 'test_helper'

class ConfigTest < Minitest::Test
  def test_config_is_invalid_without_provider
    zone = Zone.new('bad-config.com', config: {})
    refute_predicate zone.config, :valid?
  end

  def test_config_checks_for_valid_provider
    zone = Zone.new('bad-config.com', config: {provider: 'NotARealProvider'})

    refute_predicate zone.config, :valid?
    assert_includes zone.config.errors.full_messages.join, 'provider specified does not exist'
  end

  def test_config_is_properly_loaded_from_zonefile
    tmp_config = Tempfile.new(['config', '.yml'])
    zonefile = """
example.com:
  config:
    ignore_patterns:
      - type: NS
      - type: A
        fqdn: a.example.com.
    provider: DynECT
    supports_alias: true
"""
    tmp_config.write(zonefile)
    tmp_config.close

    name, definition = YAML.load_file(tmp_config.path).first
    zone = Zone.new(name, definition.deep_symbolize_keys)

    assert_equal [{type: 'NS'}, {type: 'A', fqdn: 'a.example.com.'}], zone.config.ignore_patterns
    assert_equal 'DynECT', zone.config.provider
    assert_predicate zone.config, :supports_alias?
  end

  def test_config_supports_alias_based_on_provider
    config = Zone.new('dynect-config.com', config: {provider: 'DynECT'}).config
    refute_predicate config, :supports_alias?

    config = Zone.new('dnsimple-config.com', config: {provider: 'DNSimple'}).config
    assert_predicate config, :supports_alias?
  end
end
