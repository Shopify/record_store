SECRET_KEYS = {
  'google_cloud_dns' => %w(
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
  'ns1' => %w(
    api_key
  ),
  'dnsimple' => %w(
    account_id
    api_token
    base_url
  ),
  'oracle_cloud_dns' => %w(
    compartment_id
    user
    fingerprint
    key_content
    tenancy
    region
  ),
  'cloudflare' => %w(
    api_token
    account_id
  ),
}

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into(:webmock)
  config.debug_logger = File.open(File.expand_path('../vcr_debug.log', __dir__), 'w') if ENV['DEBUG']

  if File.exist?(RecordStore.secrets_path)
    secrets = JSON.parse(File.read(RecordStore.secrets_path))

    SECRET_KEYS.each do |provider, secret_keys|
      secret_keys.each do |key|
        config.filter_sensitive_data("<#{provider.upcase}_#{key.upcase}>") do
          secrets.fetch(provider).fetch(key)
        end
      end
    end
  end

  config.filter_sensitive_data('<NS1_API_KEY>') do |interaction|
    next unless interaction.request.uri =~ /nsone/

    if (auth_token = interaction.request.headers['NS1_API_KEY']).present?
      auth_token.first
    end
  end

  config.filter_sensitive_data('<DYNECT_AUTH_TOKEN>') do |interaction|
    if interaction.request.uri =~ /dynect/
      res = JSON.parse(interaction.response.body)
      if res.fetch('data').is_a?(Hash) && res.fetch('data').key?('token')
        res.fetch('data').fetch('token')
      end
    end
  end

  config.filter_sensitive_data('<DYNECT_AUTH_TOKEN>') do |interaction|
    if (auth_token = interaction.request.headers['Auth-Token']).present?
      auth_token.first
    end
  end

  config.filter_sensitive_data('<GOOGLE_CLOUD_DNS_AUTH_TOKEN>') do |interaction|
    if interaction.request.uri == '<GOOGLE_CLOUD_DNS_TOKEN_URI>'
      JSON.parse(interaction.response.body)['access_token']
    end
  end

  config.filter_sensitive_data('<GOOGLE_CLOUD_DNS_AUTH_TOKEN>') do |interaction|
    next unless interaction.request.uri =~ /<GOOGLE_CLOUD_DNS_TOKEN_URI>/

    if (auth_token = interaction.request.headers['Authorization']).present?
      auth_token.first
    end
  end

  config.filter_sensitive_data('<GOOGLE_CLOUD_DNS_AUTH_SECRET>') do |interaction|
    if interaction.request.uri == '<GOOGLE_CLOUD_DNS_TOKEN_URI>'
      interaction.request.body
    end
  end

  config.filter_sensitive_data('<ORACLE_CLOUD_DNS_COMPARTMENT_ID>') do |interaction|
    next unless interaction.request.uri =~ /oraclecloud/

    if (auth_token = interaction.request.headers['ORACLE_CLOUD_DNS_COMPARTMENT_ID']).present?
      auth_token.first
    end
  end

  config.before_playback do |interaction|
    interaction.response.headers['X-Ratelimit-Period'] = 0
  end
end
