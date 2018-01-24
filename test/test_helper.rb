require 'minitest/autorun'
require 'mocha/mini_test'
require 'vcr'
require 'pry'
require 'fileutils'
require 'webmock'

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require 'record_store'

class Minitest::Test
  include RecordStore
  DUMMY_CONFIG_PATH = File.expand_path('../dummy/config.yml', __FILE__)

  RecordStore.config_path = DUMMY_CONFIG_PATH

  SECRET_KEYS = {
    'google_cloud_dns' =>  %w(
      type
      private_key_id
      private_key
      client_email
      client_id
      auth_uri
      token_uri
      auth_provider_x509_cert_url
      client_x509_cert_url
    ),
    'dynect' => %w(
      password
      username
    ),
    'dnsimple' => %w(
      email
      api_token
    )
  }

  VCR.configure do |config|
    config.cassette_library_dir = "test/fixtures/vcr_cassettes"
    config.hook_into :webmock
    config.debug_logger = File.open(File.expand_path('../vcr_debug.log', __FILE__), 'w') if ENV['DEBUG']

    if File.exist?(RecordStore.secrets_path)
      secrets = JSON.parse(File.read(RecordStore.secrets_path))

      SECRET_KEYS.each do |provider, secret_keys|
        secret_keys.each do |key|
          config.filter_sensitive_data "<#{provider.upcase}_#{key.upcase}>" do
            secrets.fetch(provider).fetch(key)
          end
        end
      end
    end

    config.filter_sensitive_data '<DYNECT_AUTH_TOKEN>' do |interaction|
      if interaction.request.uri =~ /dynect/
        res = JSON.parse(interaction.response.body)
        if res.fetch('data').is_a?(Hash) && res.fetch('data').has_key?('token')
          res.fetch('data').fetch('token')
        end
      end
    end

    config.filter_sensitive_data '<DYNECT_AUTH_TOKEN>' do |interaction|
      if (auth_token = interaction.request.headers['Auth-Token']).present?
        auth_token.first
      end
    end

    config.filter_sensitive_data '<GOOGLE_CLOUD_DNS_AUTH_TOKEN>' do |interaction|
      if interaction.request.uri == '<GOOGLE_CLOUD_DNS_TOKEN_URI>'
        JSON.parse(interaction.response.body)['access_token']
      end
    end

    config.filter_sensitive_data '<GOOGLE_CLOUD_DNS_AUTH_TOKEN>' do |interaction|
      if (auth_token = interaction.request.headers['Authorization']).present?
        auth_token.first
      end
    end

    config.filter_sensitive_data '<GOOGLE_CLOUD_DNS_AUTH_SECRET>' do |interaction|
      if interaction.request.uri == '<GOOGLE_CLOUD_DNS_TOKEN_URI>'
        interaction.request.body
      end
    end
  end

  def teardown
    Provider::DynECT.instance_variable_set(:@dns, nil)
    Provider::DNSimple.instance_variable_set(:@dns, nil)
    Provider::GoogleCloudDNS.instance_variable_set(:@dns, nil)
  end

  def build_record_store_config(zones_path: 'zones/', secrets_path: 'secrets.json', zones: ['empty.com', 'one-record.com'])
    {
      zones_path: zones_path,
      secrets_path: secrets_path,
      zones: zones
    }.deep_stringify_keys.to_yaml.gsub("---\n", '')
  end
end
