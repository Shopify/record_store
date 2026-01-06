require 'test_helper'

module CLI
  class InfoTest < Minitest::Test
    def setup
      super
      Zone.expects(:defined).returns(
        'example.com' => Zone.new(name: 'example.com', config: { providers: %w(DNSimple NS1) }),
      )
    end

    def teardown
      super
      RecordStore.config_path = DUMMY_CONFIG_PATH
    end

    def test_prints_zone
      RecordStore::CLI.start(%w(info))

      assert_includes($stdout.string, "Zone: example.com")
    end

    def test_lists_providers
      RecordStore::CLI.start(%w(info))

      providers = <<~PROVIDERS
        Providers:
        - DNSimple
        - NS1
      PROVIDERS

      assert_includes($stdout.string, providers)
    end

    def test_lists_authoritative_nameservers
      RecordStore::CLI.start(%w(info))

      output = $stdout.string
      assert_includes(output, "Authoritative nameservers:")
      assert_includes(output, "hera.ns.cloudflare.com.")
      assert_includes(output, "elliott.ns.cloudflare.com.")
    end
  end
end
