require 'test_helper'

class CLITest < Minitest::Test
  EJSON_PUBLIC_KEY = '2b3c17d703a46e4e1e34206ca61474865d32e24e85405c9e92fdd0172b01a81a'
  EJSON_PRIVATE_KEY = '739c6c987f8520b725fe608ac9f537610f7cfbe612d73d5256d3ac56ae060a1b'

  def teardown
    super
    RecordStore.config_path = DUMMY_CONFIG_PATH
  end

  def test_secrets_uses_secrets_path_to_find_ejson_file
    ejson_keydir = ENV['EJSON_KEYDIR']

    Dir.mktmpdir do |dir|
      File.write(config_path = "#{dir}/config.yml", build_record_store_config)
      File.write("#{dir}/#{EJSON_PUBLIC_KEY}", EJSON_PRIVATE_KEY)
      File.write(secrets_ejson_path = "#{dir}/secrets.#{ENV['CI'] ? 'ci' : 'dev'}.ejson", secrets_ejson = """
{
  \"_public_key\": \"#{EJSON_PUBLIC_KEY}\",
  \"secret\": \"password\"
}
""")
      ENV['EJSON_KEYDIR'] = dir
      %x(ejson encrypt #{secrets_ejson_path})

      RecordStore::CLI.start("secrets -c #{config_path}".split(' '))

      assert_equal(secrets_ejson, File.read(RecordStore.secrets_path))
    end
  ensure
    ENV['EJSON_KEYDIR'] = ejson_keydir
  end

  def test_applies_no_changes_if_any_zone_invalid
    ns1_config = { providers: ['NS1'] }
    Zone.expects(:modified).returns([
      Zone.new(name: 'test.recordstore.io', config: ns1_config, records: [{
        type: 'TXT',
        fqdn: "test.recordstore.io.",
        ttl: 3600,
        txtdata: 'This record is valid',
      }]),
      Zone.new(name: 'sshfp1.test.recordstore.io', config: ns1_config, records: [{
        type: 'SSHFP',
        fqdn: "ns1.does.not.support.sshfp1.test.recordstore.io.",
        ttl: 3600,
        algorithm: Record::SSHFP::Algorithms::ED25519,
        fptype: Record::SSHFP::FingerprintTypes::SHA_256,
        fingerprint: '0000000000000000000000000000000000000000000000000000000000000000',
      }]),
    ])

    RecordStore::Changeset.any_instance.expects(:apply).never

    VCR.use_cassette('test_applies_no_changes_if_any_zone_invalid') do
      RecordStore::CLI.start(%w(apply))
    end
  rescue SystemExit
    # pass: CLI is expected to `abort`. Prevent the Minitest reporter from dying.
  end

  def test_validate_records_reports_record_errors
    with_configuration(zones: ["invalid.com"]) do |config_path, zones_path|
      zone_path = File.join(zones_path, "invalid.com.yml")
      zone_yaml = <<~YAML
        invalid.com:
          config:
            providers:
              - DNSimple
          records:
            - type: TXT
              fqdn: invalid.com.
              ttl: "3600"
              txtdata: "asdf;asdf"
      YAML

      File.write(zone_path, zone_yaml)

      RecordStore::CLI.start(["validate_records", "--config", config_path])
    end

    assert_equal("The following zones were invalid: invalid.com\n", $stderr.string)

    assert_equal(<<~ERROR, $stdout.string)
      invalid.com definition is not valid:
       - Records invalid record: [TXTRecord] invalid.com. 3600 IN TXT "asdf;asdf"
        Invalid records
          [TXTRecord] invalid.com. 3600 IN TXT "asdf;asdf"
            - txtdata: has unescaped semicolons (See RFC 1035).
    ERROR
  end

  def test_returns_nonzero_exit_status
    Thor.expects(:exit).with(false)
    RecordStore::CLI.start(%w(does not exist))
  end

  private

  def with_configuration(zones: [])
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config.yml")
      zones_path = File.join(dir, "zones")

      Dir.mkdir(zones_path)
      File.write(config_path, build_record_store_config(zones_path: zones_path, zones: zones))

      yield config_path, zones_path
    end
  rescue SystemExit
    # pass: CLI is expected to `abort`. Prevent the Minitest reporter from dying.
  end
end
