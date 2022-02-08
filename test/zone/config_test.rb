require 'test_helper'

class ConfigTest < Minitest::Test
  def test_config_is_invalid_without_provider
    zone = Zone.new(name: 'bad-config.com', config: {})
    refute_predicate(zone.config, :valid?)
  end

  def test_config_checks_for_valid_provider
    zone = Zone.new(name: 'bad-config.com', config: { providers: ['NotARealProvider'] })

    refute_predicate(zone.config, :valid?)
    assert_includes(zone.config.errors.full_messages.join, 'provider specified does not exist')
  end

  def test_config_is_properly_loaded_from_zonefile
    tmp_config = Tempfile.new(['config', '.yml'])
    zonefile = "
example.com:
  config:
    ignore_patterns:
      - type: NS
      - type: A
        fqdn: a.example.com.
    providers:
      - DynECT
      - DNSimple
    supports_alias: true
"
    tmp_config.write(zonefile)
    tmp_config.close

    zone_name, definition = YAML.load_file(tmp_config.path).first
    zone = Zone.new(**definition.deep_symbolize_keys.merge(name: zone_name))

    assert_equal([{ type: 'NS' }, { type: 'A', fqdn: 'a.example.com.' }],
      zone.config.ignore_patterns.map(&:to_hash))
    assert_equal(['DynECT', 'DNSimple'], zone.config.providers)
    assert_predicate(zone.config, :supports_alias?)
    assert_predicate(zone.config, :empty_non_terminal_over_wildcard?)
  end

  def test_config_supports_alias_based_on_provider
    config = Zone.new(name: 'dynect-config.com', config: { providers: ['DynECT'] }).config
    refute_predicate(config, :supports_alias?)

    config = Zone.new(name: 'dnsimple-config.com', config: { providers: ['DNSimple'] }).config
    assert_predicate(config, :supports_alias?)
  end

  def test_config_does_not_supports_alias_when_multiple_providers_disagree
    config = Zone.new(name: 'dnsimple-config.com', config: { providers: ['DNSimple', 'DynECT'] }).config
    refute_predicate(config, :supports_alias?)
  end

  def test_config_empty_non_terminal_over_wildcard_when_multiple_providers_disagree
    config = Zone.new(name: 'dnsimple-config.com', config: { providers: ['DNSimple', 'DynECT'] }).config
    assert_predicate(config, :empty_non_terminal_over_wildcard?)
  end

  def test_config_empty_non_terminal_over_wildcard_based_on_provider
    config = Zone.new(name: 'dynect-config.com', config: { providers: ['DynECT'] }).config
    assert_predicate(config, :empty_non_terminal_over_wildcard?)

    config = Zone.new(name: 'dnsimple-config.com', config: { providers: ['DNSimple'] }).config
    refute_predicate(config, :empty_non_terminal_over_wildcard?)
  end
end
