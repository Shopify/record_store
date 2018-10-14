require 'json'
require 'yaml'
require 'active_support'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string'
require 'active_model'
require 'active_model/validations'
require 'ipaddr'
require 'thor'
require 'pathname'

require 'record_store/record'
require 'record_store/record/a'
require 'record_store/record/aaaa'
require 'record_store/record/alias'
require 'record_store/record/cname'
require 'record_store/record/mx'
require 'record_store/record/ns'
require 'record_store/record/txt'
require 'record_store/record/spf'
require 'record_store/record/srv'
require 'record_store/zone/yaml_definitions'
require 'record_store/zone'
require 'record_store/zone/config'
require 'record_store/zone/config/ignore_pattern'
require 'record_store/changeset'
require 'record_store/provider'
require 'record_store/provider/dynect'
require 'record_store/provider/dnsimple'
require 'record_store/provider/google_cloud_dns'
require 'record_store/cli'

module RecordStore
  MAXIMUM_REMOVALS = 20

  class << self
    attr_writer :secrets_path
    attr_writer :zones_path

    def secrets_path
      @secrets_path ||= File.expand_path(config.fetch('secrets_path'), File.dirname(config_path))
    end

    def zones_path
      @zones_path ||= Pathname.new(File.expand_path(config.fetch('zones_path'), File.dirname(config_path))).realpath.to_s
    end

    def config_path
      @config_path ||= File.expand_path('config.yml', Dir.pwd)
    end

    def config_path=(config_path)
      @config = @zones_path = @secrets_path = nil
      @config_path = config_path
    end

    def config
      @config ||= YAML.load_file(config_path)
    end

    def defined_zones
      @defined_zones ||= Zone.all.map(&:name)
    end

    def expected_zones
      config.fetch('zones')
    end
  end
end
