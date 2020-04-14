module ProviderTeardown
  def teardown
    super
    RecordStore::Provider::DynECT.instance_variable_set(:@dns, nil)
    RecordStore::Provider::DNSimple.instance_variable_set(:@dns, nil)
    RecordStore::Provider::GoogleCloudDNS.instance_variable_set(:@dns, nil)
    RecordStore::Provider::OracleCloudDNS.instance_variable_set(:@dns, nil)
  end
end

Minitest::Test.prepend(ProviderTeardown)
