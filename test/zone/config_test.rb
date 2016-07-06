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
"""
    tmp_config.write(zonefile)
    tmp_config.close

    zone = Zone.from_yaml_definition(*YAML.load_file(tmp_config.path).first)

    assert_equal [{type: 'NS'}, {type: 'A', fqdn: 'a.example.com.'}], zone.config.ignore_patterns
    assert_equal 'DynECT', zone.config.provider
  end
end
