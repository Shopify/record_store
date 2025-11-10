require 'test_helper'

class CloudflareTest < Minitest::Test
  def setup
    super
    @zone_name = 'record-store-dns-tests.shopitest.com'
    @cloudflare = Provider::Cloudflare
  end

  def test_zones
    VCR.use_cassette('cloudflare_test_zones') do
      zones = @cloudflare.zones
      assert_includes(zones, @zone_name)
    end
  end

  def test_build_a_from_api
    api_record = {
      "id" => "e4b2b841a1126746d255275c2f1aa41",
      "zone_id" => "1a234bc567dea8a9b01251e19abcde8a",
      "zone_name" => "record-store-dns-tests.shopitest.com",
      "name" => "www.record-store-dns-tests.shopitest.com",
      "type" => "A",
      "content" => "192.0.2.1",
      "ttl" => 1,
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::A, record)
    assert_equal('www.record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal('192.0.2.1', record.address)
    assert_equal(1, record.ttl)
  end

  def test_build_caa_from_api
    api_record = {
      "id" => "123458",
      "type" => "CAA",
      "name" => "secure.record-store-dns-tests.shopitest.com",
      "content" => "0 issue \"letsencrypt.org\"",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::CAA, record)
    assert_equal('secure.record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal(0, record.flags)
    assert_equal('issue', record.tag)
    assert_equal('letsencrypt.org', record.value)
    assert_equal(3600, record.ttl)
  end

  def test_build_cname_from_api
    api_record = {
      "id" => "e4b2b841a1126746d255275c2f1aa41",
      "zone_id" => "1a234bc567dea8a9b01251e19abcde8a",
      "zone_name" => "record-store-dns-tests.shopitest.com",
      "name" => "shopify.record-store-dns-tests.shopitest.com",
      "type" => "CNAME",
      "content" => "shopify.com",
      "ttl" => 1,
      "settings" => { "flatten_cname" => false }
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::CNAME, record)
    assert_equal('shopify.record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal('shopify.com.', record.cname)
    assert_equal(1, record.ttl)
  end

  def test_build_mx_from_api
    api_record = {
      "id" => "123460",
      "type" => "MX",
      "name" => "mail",
      "content" => "mail.record-store-dns-tests.shopitest.com",
      "ttl" => 3600,
      "priority" => 10
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::MX, record)
    assert_equal('mail.record-store-dns-tests.shopitest.com.', record.exchange)
    assert_equal(10, record.preference)
    assert_equal(3600, record.ttl)
  end

  def test_build_ns_from_api
    api_record = {
      "id" => "123461",
      "type" => "NS",
      "name" => "ns.record-store-dns-tests.shopitest.com",
      "content" => "cory.ns.cloudflare.com",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::NS, record)
    assert_equal('ns.record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal('cory.ns.cloudflare.com.', record.nsdname)
    assert_equal(3600, record.ttl)
  end

  def test_build_ptr_from_api
    api_record = {
      "id" => "123462",
      "type" => "PTR",
      "name" => "0.183.136.115.in-addr.arpa",
      "content" => "tbnbz2ni.byoip.example.com",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::PTR, record)
    assert_equal('tbnbz2ni.byoip.example.com.', record.ptrdname)
    assert_equal('0.183.136.115.in-addr.arpa.', record.fqdn)
    assert_equal(3600, record.ttl)
  end

  def test_build_txt_from_api_quote
    api_record = {
      "id" => "123465",
      "type" => "TXT",
      "name" => "record-store-dns-tests.shopitest.com",
      "content" => 'v=spf1 ip4:192.0.2.0; \"Hello, world!\"',
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::TXT, record)
    assert_equal('record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal('v=spf1 ip4:192.0.2.0\\; "Hello, world!"', record.txtdata)
    assert_equal(3600, record.ttl)
  end

  def test_build_txt_with_quotes_from_api
    api_record = {
      "id" => "123465",
      "type" => "TXT",
      "name" => "record-store-dns-tests.shopitest.com",
      "content" => '"some text with \" quote"',
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::TXT, record)
    assert_equal('record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal('some text with " quote', record.txtdata)
    assert_equal(3600, record.ttl)
  end

  def test_build_srv_from_api
    api_record = {
      "id" => "123466",
      "type" => "SRV",
      "name" => "_sip._tcp.record-store-dns-tests.shopitest.com",
      "content" => "50 5060 sipserver.record-store-dns-tests.shopitest.com",
      "priority" => "10",
      "ttl" => 3600
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::SRV, record)
    assert_equal('_sip._tcp.record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal(10, record.priority)
    assert_equal(50, record.weight)
    assert_equal(5060, record.port)
    assert_equal('sipserver.record-store-dns-tests.shopitest.com.', record.target)
    assert_equal(3600, record.ttl)
  end

  def test_build_alias_from_api
    api_record = {
      "id" => "123467",
      "type" => "CNAME",
      "name" => "alias.record-store-dns-tests.shopitest.com",
      "content" => "target.record-store-dns-tests.shopitest.com",
      "ttl" => 3600,
      "settings" => { "flatten_cname" => true }
    }

    record = @cloudflare.send(:build_from_api, api_record)

    assert_kind_of(Record::ALIAS, record)
    assert_equal('alias.record-store-dns-tests.shopitest.com.', record.fqdn)
    assert_equal('target.record-store-dns-tests.shopitest.com.', record.alias)
    assert_equal(3600, record.ttl)
  end

  def test_add_changeset
    VCR.use_cassette('cloudflare_test_add_changeset') do
      record = Record::A.new(fqdn: 'add.record-store-dns-tests.shopitest.com', ttl: 600, address: '192.0.2.1')
      changeset = Changeset.new(current_records: [], desired_records: [record], provider: @cloudflare, zone: @zone_name)

      @cloudflare.apply_changeset(changeset)
      assert_includes(@cloudflare.retrieve_current_records(zone: @zone_name), record)
    end
  end

  def test_add_multiple_changesets
    VCR.use_cassette('cloudflare_test_add_multiple_changesets') do
      records = [
        Record::A.new(fqdn: 'multi1.record-store-dns-tests.shopitest.com', ttl: 600, address: '192.0.2.1'),
        Record::A.new(fqdn: 'multi1.record-store-dns-tests.shopitest.com', ttl: 600, address: '192.0.2.3'),
        Record::A.new(fqdn: 'multi2.record-store-dns-tests.shopitest.com', ttl: 600, address: '192.0.2.2')
      ]
      changeset = Changeset.new(current_records: [], desired_records: records, provider: @cloudflare, zone: @zone_name)

      @cloudflare.apply_changeset(changeset)
      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      records.each do |record|
        assert_includes(retrieved_records, record)
      end
    end
  end

  def test_remove_changeset
    VCR.use_cassette('cloudflare_test_remove_changeset') do
      target_fqdn = 'remove.record-store-dns-tests.shopitest.com'
      record = Record::A.new(fqdn: target_fqdn, ttl: 600, address: '192.0.2.1')

      @cloudflare.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      matching_record = retrieved_records.find { |record| record.fqdn == "#{target_fqdn}." }
      record_with_id = Record::A.new(fqdn: target_fqdn, ttl: 600, address: '192.0.2.1', record_id: matching_record.id)

      @cloudflare.apply_changeset(Changeset.new(
        current_records: [record_with_id],
        desired_records: [],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      refute_includes(retrieved_records, record_with_id)
      refute_includes(retrieved_records, record)
    end
  end

  def test_update_changeset
    target_fqdn = 'update.record-store-dns-tests.shopitest.com'
    # Record with capitalization since Cloudflare normalizes to lowercase
    record = Record::CNAME.new(fqdn: target_fqdn, ttl: 600, cname: 'EXAMPLE.COM')
    updated_record = record.dup
    updated_record.cname = 'example.org'
    updated_record.ttl = 3600

    VCR.use_cassette('cloudflare_test_update_changeset_before') do
      @cloudflare.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @cloudflare,
        zone: @zone_name,
      ))
    end

    VCR.use_cassette('cloudflare_test_update_changeset_after') do
      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      matching_record = retrieved_records.find { |record| record.fqdn == "#{target_fqdn}." }
      record.id = matching_record.id

      @cloudflare.apply_changeset(Changeset.new(
        current_records: [record],
        desired_records: [updated_record],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)

      # Check that at least one retrieved record has the cname and fqdn of updated_record
      assert(retrieved_records.any? { |r| r.fqdn == updated_record.fqdn && r.cname == updated_record.cname + '.' })

      # Check that the cname (in both upper and lowercase) of the original record is not included
      refute(retrieved_records.any? { |r| r.fqdn == record.fqdn && r.cname == record.cname.downcase + '.' })
      refute(retrieved_records.any? { |r| r.fqdn == record.fqdn && r.cname == record.cname.upcase + '.' })
    end
  end

  def test_update_changeset_where_domain_doesnt_exist
    VCR.use_cassette('cloudflare_test_update_changeset_where_domain_doesnt_exist') do
      record = Record::A.new(fqdn: 'nonexistent.record-store-dns-tests.shopitest.com', ttl: 600, address: '192.0.2.1')
      updated_record = record.dup
      updated_record.address = '192.0.2.2'
      record.id = '12345'

      assert_raises(RecordStore::Provider::Cloudflare::Error) do
        @cloudflare.apply_changeset(Changeset.new(
          current_records: [record],
          desired_records: [updated_record],
          provider: @cloudflare,
          zone: @zone_name,
        ))
      end
    end
  end

  def test_alias_record_retrieved_after_adding_record_changeset
    VCR.use_cassette('cloudflare_test_alias_record_retrieved_after_adding_record_changeset') do
      record = Record::ALIAS.new(
        fqdn: 'alias.record-store-dns-tests.shopitest.com',
        ttl: 600,
        alias: 'target.record-store-dns-tests.shopitest.com',
      )
      @cloudflare.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @cloudflare,
        zone: @zone_name,
      ))
      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      assert_includes(retrieved_records, record)
    end
  end

  def test_remove_record_should_not_remove_all_records_for_fqdn
    VCR.use_cassette('cloudflare_test_remove_record_should_not_remove_all_records_for_fqdn') do
      target_fqdn = 'multi.record-store-dns-tests.shopitest.com'
      record1 = Record::A.new(fqdn: target_fqdn, ttl: 600, address: '192.0.2.1')
      record2 = Record::A.new(fqdn: target_fqdn, ttl: 600, address: '192.0.2.2')
      @cloudflare.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record1, record2],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)

      matching_record1 = retrieved_records.find do |record|
        record.fqdn == "#{target_fqdn}." && record.address == '192.0.2.1'
      end
      record1.id = matching_record1.id

      matching_record2 = retrieved_records.find do |record|
        record.fqdn == "#{target_fqdn}." && record.address == '192.0.2.2'
      end
      record2.id = matching_record2.id

      @cloudflare.apply_changeset(Changeset.new(
        current_records: [record1, record2],
        desired_records: [record1],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      assert_includes(retrieved_records, record1)
      refute_includes(retrieved_records, record2)
    end
  end

  def test_build_api_body_for_a_record
    record = Record::A.new(fqdn: 'www.record-store-dns-tests.shopitest.com.', ttl: 3600, address: '192.0.2.1')
    api_body = @cloudflare.send(:build_api_body, record)

    expected_api_body = {
      name: 'www.record-store-dns-tests.shopitest.com.',
      ttl: 3600,
      type: 'A',
      content: '192.0.2.1'
    }

    assert_equal(expected_api_body, api_body)
  end

  def test_build_api_body_for_srv_record
    record = Record::SRV.new(
      fqdn: '_sip._tcp.record-store-dns-tests.shopitest.com.',
      ttl: 3600,
      priority: 10,
      weight: 20,
      port: 5060,
      target: 'sip.record-store-dns-tests.shopitest.com.',
    )
    api_body = @cloudflare.send(:build_api_body, record)

    expected_api_body = {
      name: '_sip._tcp.record-store-dns-tests.shopitest.com.',
      ttl: 3600,
      type: 'SRV',
      data: {
        priority: 10,
        weight: 20,
        port: 5060,
        target: 'sip.record-store-dns-tests.shopitest.com.'
      }
    }

    assert_equal(expected_api_body, api_body)
  end

  def test_zones_returns_empty_array_when_api_response_is_empty
    page = 1
    per_page = 50

    empty_api_response = {
      "result" => [],
      "success" => true,
      "errors" => [],
      "messages" => [],
      "result_info" => {
        "page" => 1,
        "per_page" => 50,
        "count" => 0,
        "total_count" => 0,
        "total_pages" => 1
      }
    }

    http_response_stub = stub(
      body: empty_api_response.to_json,
      code: '200',
      :[] => 'application/json',
    )

    Cloudflare::Client.any_instance.stubs(:get).with('/client/v4/zones', page: page, per_page: per_page).returns(
      Cloudflare::Response.new(http_response_stub),
    )

    zones = @cloudflare.zones
    assert_equal([], zones)
  end

  def test_retrieve_current_records_returns_empty_array_when_api_response_is_empty
    page = 1
    per_page = 1000

    empty_api_response = {
      "result" => [],
      "success" => true,
      "errors" => [],
      "messages" => [],
      "result_info" => {
        "page" => 1,
        "per_page" => 1000,
        "count" => 0,
        "total_count" => 0,
        "total_pages" => 1
      }
    }

    http_response_stub = stub(
      body: empty_api_response.to_json,
      code: '200',
      :[] => 'application/json',
    )

    @cloudflare.stubs(:zone_name_to_id).with(@zone_name).returns(@zone_id)

    Cloudflare::Client.any_instance.stubs(:get).with(
      "/client/v4/zones/#{@zone_id}/dns_records", page: page, per_page: per_page
    ).returns(
      Cloudflare::Response.new(http_response_stub),
    )

    records = @cloudflare.retrieve_current_records(zone: @zone_name)
    assert_equal([], records)
  end

  def test_apply_changeset_with_server_error
    target_fqdn = 'error.example.com'
    record = Record::A.new(fqdn: target_fqdn, ttl: 600, address: '192.0.2.1')

    @cloudflare.stubs(:zone_name_to_id).with(@zone_name).returns("test-zone-id")

    stub_request(:post, "https://api.cloudflare.com/client/v4/zones/test-zone-id/dns_records")
      .with(body: hash_including("name" => target_fqdn))
      .to_return(status: 500, body: '{"success":false,"errors":[{"code":10000,"message":"Internal server error"}]}')

    changeset = Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    )

    VCR.use_cassette('cloudflare_test_apply_changeset_with_server_error') do
      assert_raises(
        RecordStore::Provider::Error,
        "Response code: 500 - Internal Server Error; " \
          "{\"success\":false,\"errors\":[{\"code\":10000,\"message\":\"Internal server error\"}]}",
      ) do
        @cloudflare.apply_changeset(changeset)
      end
    end
  end

  def test_txt_record_with_quotes
    VCR.use_cassette('cloudflare_test_txt_record_with_quotes') do
      record = Record::TXT.new(
        fqdn: 'quote.record-store-dns-tests.shopitest.com',
        ttl: 3600,
        txtdata: 'some text with " quote',
      )

      @cloudflare.apply_changeset(Changeset.new(
        current_records: [],
        desired_records: [record],
        provider: @cloudflare,
        zone: @zone_name,
      ))

      retrieved_records = @cloudflare.retrieve_current_records(zone: @zone_name)
      assert_includes(retrieved_records, record)
    end
  end

  def test_retry_on_server_errors
    client = Cloudflare::Client.new("dummy_token")

    # Stub client to error twice then return success
    Cloudflare::Client.any_instance.stubs(:request).raises(
      RecordStore::Provider::RetriableError.new("Server error"),
    ).then.raises(
      RecordStore::Provider::RetriableError.new("Server error"),
    ).then.returns(
      stub(
        body: '{"success":true,"result":"success"}',
        code: '200',
        :[] => 'application/json',
      ),
    )

    result = Provider::Cloudflare.send(:retry_on_connection_errors) do
      client.get("/test")
    end

    assert_equal("success", result.result)
  end

  def test_retry_on_server_errors_exhausts_retries
    client = Cloudflare::Client.new("dummy_token")

    # Always raise RetriableError
    Cloudflare::Client.any_instance.stubs(:request).raises(
      RecordStore::Provider::RetriableError.new("Server error"),
    )

    assert_raises(RecordStore::Provider::RetriableError) do
      Provider::Cloudflare.send(:retry_on_connection_errors) do
        client.get("/test")
      end
    end
  end

  def test_5xx_response_raises_retriable_error
    client = Cloudflare::Client.new("dummy_token")

    # Create a server error typed response
    server_error = Net::HTTPServerError.new("1.1", "500", "Internal Server Error")
    server_error.instance_variable_set(
      :@body,
      '{"success":false,"errors":[{"code":1000,"message":"Internal server error"}]}',
    )

    http_connection = stub
    http_connection.expects(:request).returns(server_error)
    Net::HTTP.stubs(:start).yields(http_connection)

    assert_raises(RecordStore::Provider::RetriableError) do
      client.get("/test")
    end
  end

  def test_apply_changeset_with_no_changes_skips_api_call
    # Create a changeset with identical current and desired records (no actual changes)
    record = Record::A.new(
      fqdn: 'test.record-store-dns-tests.shopitest.com',
      ttl: 600,
      address: '192.0.2.1',
      record_id: 123,
    )
    changeset = Changeset.new(
      current_records: [record],
      desired_records: [record],
      provider: @cloudflare,
      zone: @zone_name,
    )

    # Ensure no API calls are made - the method should return early
    Cloudflare::Client.any_instance.expects(:request).never

    # Apply the changeset - should return early without making any API calls
    @cloudflare.apply_changeset(changeset)
  end
end
