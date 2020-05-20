require 'test_helper'

module CLI
  class ValidateAuthorityTest < Minitest::Test
    def teardown
      super
      RecordStore.config_path = DUMMY_CONFIG_PATH
    end

    def test_prints_zones
      mock_defined_zones('business.new' => { authority: ns_unknown('new') })

      RecordStore::CLI.start(%w(validate_authority))

      assert_includes($stdout.string, "Zone: business.new")
    end

    def test_excludes_valid_zone
      mock_defined_zones('shopify.com')

      RecordStore::CLI.start(%w(validate_authority))

      refute_includes($stdout.string, "Zone: shopify.com")
    end

    def test_verbose_option_includes_valid_zones
      mock_defined_zones('shopify.com')

      RecordStore::CLI.start(%w(validate_authority --verbose))

      assert_includes($stdout.string, "Zone: shopify.com")
    end

    def test_reports_missing_authority
      mock_defined_zones('myshopify.cloud' => { authority: ns_dnsimple('myshopify.cloud') })
      RecordStore::CLI.start(%w(validate_authority))

      assert_includes($stdout.string, "- NS1: authoritative nameservers not found for configured provider")
    end

    def test_excludes_valid_authority
      mock_defined_zones('myshopify.cloud' => { authority: ns_dnsimple('myshopify.cloud') })
      RecordStore::CLI.start(%w(validate_authority))

      refute_includes($stdout.string, "- DNSimple:")
    end

    def test_verbose_option_includes_valid_authority
      mock_defined_zones('myshopify.cloud' => { authority: ns_dnsimple('myshopify.cloud') })
      RecordStore::CLI.start(%w(validate_authority --verbose))

      authority = <<~AUTHORITY
        - DNSimple:
          - ns1.dnsimple.com.
          - ns2.dnsimple.com.
          - ns3.dnsimple.com.
          - ns4.dnsimple.com.
      AUTHORITY

      assert_includes($stdout.string, authority)
    end

    def test_reports_extra_authority
      mock_defined_zones('myshopify.cloud' => { providers: %w(DNSimple) })
      RecordStore::CLI.start(%w(validate_authority))

      authority = <<~AUTHORITY
        - NS1: unexpected authoritative nameservers found
          - ns1.p06.nsone.net.
          - ns2.p06.nsone.net.
          - ns3.p06.nsone.net.
          - ns4.p06.nsone.net.
      AUTHORITY

      assert_includes($stdout.string, authority)
    end

    def test_reports_unknown_authority
      mock_defined_zones('business.new' => { authority: ns_unknown('new') })

      RecordStore::CLI.start(%w(validate_authority))

      assert_includes($stdout.string, "Zone: business.new")

      authority = <<~AUTHORITY
        - Unknown: unknown authoritative nameservers found
          - ns1.charlestonroadregistry.com.
          - ns2.charlestonroadregistry.com.
          - ns3.charlestonroadregistry.com.
          - ns4.charlestonroadregistry.com.
          - ns5.charlestonroadregistry.com.
      AUTHORITY

      assert_includes($stdout.string, authority)
    end

    private

    def mock_defined_zones(zones)
      defined = Array(zones).map { |zone_name, options| [zone_name, mock_zone(zone_name, **Hash(options))] }.to_h
      Zone.expects(:defined).returns(defined)
    end

    def mock_zone(zone_name, providers: %w(DNSimple NS1), authority: ns_dnsimple(zone_name) + ns_ns1(zone_name))
      zone = Zone.new(name: zone_name, config: { providers: providers })
      zone.expects(:fetch_authority).returns(authority)
      zone
    end

    def ns_records(fqdn:, nsdomain:, count:, ttl: 172800)
      count.times.map do |i|
        Record::NS.new(fqdn: fqdn, ttl: ttl, nsdname: "ns#{i + 1}.#{nsdomain}.")
      end
    end

    def ns_dnsimple(fqdn)
      ns_records(fqdn: fqdn, nsdomain: 'dnsimple.com', count: 4)
    end

    def ns_googlecloud(fqdn)
      ns_records(fqnd: fqdn, nsdomain: 'googledomains.com', count: 4)
    end

    def ns_ns1(fqdn)
      ns_records(fqdn: fqdn, nsdomain: 'p06.nsone.net', count: 4)
    end

    def ns_unknown(fqdn)
      ns_records(fqdn: fqdn, nsdomain: 'charlestonroadregistry.com', count: 5)
    end

    # def test_lists_providers
    #   RecordStore::CLI.start(%w(info))

    #   providers = <<~PROVIDERS
    #     Providers:
    #     - DNSimple
    #     - NS1
    #   PROVIDERS

    #   assert_includes($stdout.string, providers)
    # end

    # def test_lists_authoritative_nameservers
    #   RecordStore::CLI.start(%w(info))

    #   authority = <<~AUTHORITY
    #     Authoritative nameservers:
    #     - [NSRecord] example.com. 172800 IN NS a.iana-servers.net.
    #     - [NSRecord] example.com. 172800 IN NS b.iana-servers.net.
    #   AUTHORITY

    #   assert_includes($stdout.string, authority)
    # end
  end
end
