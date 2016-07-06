require 'json'
require 'yaml'
require 'active_support'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string'
require 'active_model'
require 'active_model/validations'
require 'ipaddr'
require 'thor'
require 'pathname'

require 'recordstore/record'
require 'recordstore/record/a'
require 'recordstore/record/aaaa'
require 'recordstore/record/alias'
require 'recordstore/record/cname'
require 'recordstore/record/mx'
require 'recordstore/record/ns'
require 'recordstore/record/txt'
require 'recordstore/record/spf'
require 'recordstore/record/srv'
require 'recordstore/zone'
require 'recordstore/zone/config'
require 'recordstore/changeset'
require 'recordstore/provider'
require 'recordstore/provider/dynect'
require 'recordstore/provider/dnsimple'
require 'recordstore/cli'

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
