require 'minitest/autorun'
require 'mocha/mini_test'
require 'vcr'
require 'pry'
require 'fileutils'

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require 'record_store'

class Minitest::Test
  include RecordStore
  DUMMY_CONFIG_PATH = File.expand_path('../dummy/config.yml', __FILE__)

  RecordStore.config_path = DUMMY_CONFIG_PATH

  def teardown
    Provider::DynECT.instance_variable_set(:@dns, nil)
    Provider::DNSimple.instance_variable_set(:@dns, nil)
  end

  VCR.configure do |config|
    config.cassette_library_dir = "test/fixtures/vcr_cassettes"
    config.hook_into :excon
    config.debug_logger = File.open(File.expand_path('../vcr_debug.log', __FILE__), 'w') if ENV['DEBUG']

    config.default_cassette_options[:allow_unused_http_interactions] = false
    config.default_cassette_options[:match_requests_on] << :body

    if File.exist?(RecordStore.secrets_path)
      secrets = JSON.parse(File.read(RecordStore.secrets_path))

      config.filter_sensitive_data '<DYNECT_PASSWORD>' do
        secrets.fetch('dynect').fetch('password')
      end

      config.filter_sensitive_data '<DYNECT_USERNAME>' do
        secrets.fetch('dynect').fetch('username')
      end

      config.filter_sensitive_data '<DNSIMPLE_EMAIL>' do
        secrets.fetch('dnsimple').fetch('email')
      end

      config.filter_sensitive_data '<DNSIMPLE_API_TOKEN>' do
        secrets.fetch('dnsimple').fetch('api_token')
      end
    end

    config.filter_sensitive_data '<DYNECT_AUTH_TOKEN>' do |interaction|
      next if interaction.request.uri =~ /dnsimple/

      res = JSON.parse(interaction.response.body)
      if res.fetch('data').is_a?(Hash) && res.fetch('data').has_key?('token')
        res.fetch('data').fetch('token')
      end
    end

    config.filter_sensitive_data '<DYNECT_AUTH_TOKEN>' do |interaction|
      if (auth_token = interaction.request.headers['Auth-Token']).present?
        auth_token.first
      end
    end
  end

  def build_record_store_config(zones_path: 'zones/', secrets_path: 'secrets.json', zones: ['empty.com', 'one-record.com'])
    {
      zones_path: zones_path,
      secrets_path: secrets_path,
      zones: zones
    }.deep_stringify_keys.to_yaml.gsub("---\n", '')
  end
end
