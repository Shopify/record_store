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

      authority = <<~AUTHORITY
        Authoritative nameservers:
        - [NSRecord] example.com. 172800 IN NS a.iana-servers.net.
        - [NSRecord] example.com. 172800 IN NS b.iana-servers.net.
      AUTHORITY

      assert_includes($stdout.string, authority)
    end
  end
end
