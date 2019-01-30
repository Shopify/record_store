require 'test_helper'

class CLITest < Minitest::Test
  EJSON_PUBLIC_KEY = '2b3c17d703a46e4e1e34206ca61474865d32e24e85405c9e92fdd0172b01a81a'
  EJSON_PRIVATE_KEY = '739c6c987f8520b725fe608ac9f537610f7cfbe612d73d5256d3ac56ae060a1b'

  def teardown
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
      `ejson encrypt #{secrets_ejson_path}`

      RecordStore::CLI.start("secrets -c #{config_path}".split(' '))

      assert_equal secrets_ejson, File.read(RecordStore.secrets_path)
    end

  ensure
    ENV['EJSON_KEYDIR'] = ejson_keydir
  end

  def test_returns_nonzero_exit_status
    stderr = STDERR.clone
    STDERR.reopen(File::NULL, "w")
    Thor.expects(:exit).with(false)
    RecordStore::CLI.start(%w(does not exist))
  ensure
    STDERR.reopen(stderr)
  end
end
