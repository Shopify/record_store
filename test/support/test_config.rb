module TestConfig
  def build_record_store_config(
    zones_path: 'zones/',
    secrets_path: 'secrets.json',
    zones: ['empty.com', 'one-record.com']
  )
    {
      zones_path: zones_path,
      secrets_path: secrets_path,
      zones: zones,
    }.deep_stringify_keys.to_yaml.gsub("---\n", '')
  end
end

Minitest::Test.send(:prepend, TestConfig)
