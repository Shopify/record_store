require 'test_helper'

# Zone id lookups for the Cloudflare provider: one listing of all zones, shared and remembered for the run.
# No real calls: every request is answered by WebMock.
class CloudflareZoneIdsTest < Minitest::Test
  ZONES_URL = 'https://api.cloudflare.com/client/v4/zones'.freeze

  def setup
    super
    @cloudflare = Provider::Cloudflare
    @cloudflare.clear_zone_id_cache
  end

  def test_lists_all_pages_once_and_maps_names_to_ids
    stub_zone_list(numbered_zones(120))

    assert_equal('id-1', zone_id('zone-1.example'))
    assert_equal('id-60', zone_id('zone-60.example'))
    assert_equal('id-120', zone_id('zone-120.example'))

    assert_equal(3, list_requests)
    assert_equal(0, name_lookup_requests)
  end

  def test_zone_ids_are_remembered_between_lookups
    stub_zone_list(numbered_zones(3))

    3.times { assert_equal('id-2', zone_id('zone-2.example')) }
    assert_equal('id-3', zone_id('zone-3.example'))

    assert_equal(1, list_requests)
  end

  def test_a_listing_that_fits_on_one_page_is_one_request
    stub_zone_list(numbered_zones(50))

    assert_equal('id-50', zone_id('zone-50.example'))

    assert_equal(1, list_requests)
  end

  def test_lookup_ignores_case_and_a_trailing_dot
    stub_zone_list([zone('Example.COM', 'abc')])

    assert_equal('abc', zone_id('example.com'))
    assert_equal('abc', zone_id('example.com.'))
    assert_equal('abc', zone_id('EXAMPLE.com'))
    assert_equal(1, list_requests)
  end

  def test_retrieving_records_for_many_zones_lists_zones_once
    zones = numbered_zones(5)
    stub_zone_list(zones)
    zones.each { |z| stub_records(z['id'], [a_record(z['name'])]) }

    zones.each do |z|
      records = @cloudflare.retrieve_current_records(zone: z['name'])

      assert_equal(["www.#{z['name']}."], records.map(&:fqdn))
    end

    assert_equal(1, list_requests)
    assert_equal(0, name_lookup_requests)
    assert_equal(5, record_requests)
  end

  def test_applying_a_changeset_uses_the_remembered_zone_id
    stub_zone_list([zone('example.com', 'zone-id')])
    batch = stub_request(:post, "#{ZONES_URL}/zone-id/dns_records/batch")
      .to_return(json_response(success: true, errors: [], messages: [], result: {}))
    record = Record::A.new(fqdn: 'www.example.com', ttl: 600, address: '192.0.2.1')
    changeset = Changeset.new(
      current_records: [],
      desired_records: [record],
      provider: @cloudflare,
      zone: 'example.com',
    )

    @cloudflare.apply_changeset(changeset)

    assert_requested(batch)
    assert_equal(1, list_requests)
    assert_equal(0, name_lookup_requests)
  end

  def test_unknown_zone_is_looked_up_on_its_own_and_raises_when_not_found
    stub_zone_list([zone('known.example', 'id-known')])
    stub_name_lookup('missing.example', [])

    error = assert_raises(RuntimeError) { zone_id('missing.example') }

    assert_equal('Zone not found for missing.example', error.message)
    assert_equal(1, list_requests)
    assert_equal(1, name_lookup_requests('missing.example'))
  end

  def test_a_zone_created_after_the_listing_was_fetched_is_found_with_one_lookup
    stub_zone_list([zone('known.example', 'id-known')])
    stub_name_lookup('new.example', [zone('new.example', 'id-new')])

    assert_equal('id-known', zone_id('known.example'))
    assert_equal('id-new', zone_id('new.example'))
    assert_equal('id-new', zone_id('new.example'))

    assert_equal(1, list_requests)
    assert_equal(1, name_lookup_requests('new.example'))
  end

  def test_a_zone_that_stays_missing_is_looked_up_again_each_time
    stub_zone_list([])
    stub_name_lookup('later.example', [])

    2.times { assert_raises(RuntimeError) { zone_id('later.example') } }
    stub_name_lookup('later.example', [zone('later.example', 'id-later')])

    assert_equal('id-later', zone_id('later.example'))
    assert_equal(3, name_lookup_requests('later.example'))
    assert_equal(1, list_requests)
  end

  def test_multiple_zones_with_the_same_name_in_the_listing_raise
    stub_zone_list([zone('twice.example', 'id-1'), zone('other.example', 'id-3'), zone('twice.example', 'id-2')])

    error = assert_raises(RuntimeError) { zone_id('twice.example') }

    assert_equal(
      'Multiple zones found for twice.example. API key must only return the zone on which records are to be managed.',
      error.message,
    )
    assert_equal('id-3', zone_id('other.example'))
    assert_equal(0, name_lookup_requests)
  end

  def test_multiple_zones_with_the_same_name_in_a_single_lookup_raise
    stub_zone_list([])
    stub_name_lookup('twice.example', [zone('twice.example', 'id-1'), zone('twice.example', 'id-2')])

    error = assert_raises(RuntimeError) { zone_id('twice.example') }

    assert_match(/\AMultiple zones found for twice\.example\. /, error.message)
  end

  def test_zone_that_is_ambiguous_in_a_lookup_is_not_remembered
    stub_zone_list([])
    stub_name_lookup('twice.example', [zone('twice.example', 'id-1'), zone('twice.example', 'id-2')])
    assert_raises(RuntimeError) { zone_id('twice.example') }

    stub_name_lookup('twice.example', [zone('twice.example', 'id-2')])

    assert_equal('id-2', zone_id('twice.example'))
  end

  def test_a_failed_listing_is_not_remembered
    stub_request(:get, ZONES_URL).with(query: { page: '1', per_page: '50' })
      .to_return(status: 403, headers: json_headers, body: '{"success":false,"errors":[{"code":9109,"message":"no"}]}')
    assert_raises(Provider::Error) { zone_id('example.com') }

    stub_zone_list([zone('example.com', 'id-1')])

    assert_equal('id-1', zone_id('example.com'))
  end

  def test_threads_share_one_listing
    stub_request(:get, ZONES_URL).with(query: { page: '1', per_page: '50' }).to_return do |_request|
      sleep(0.05)
      api_response(numbered_zones(10))
    end

    ids = Array.new(10) { |i| Thread.new { zone_id("zone-#{i + 1}.example") } }.map(&:value)

    assert_equal((1..10).map { |i| "id-#{i}" }, ids)
    assert_equal(1, list_requests)
  end

  def test_clearing_the_cache_lists_zones_again
    stub_zone_list([zone('example.com', 'id-1')])
    zone_id('example.com')

    @cloudflare.clear_zone_id_cache
    zone_id('example.com')

    assert_equal(2, list_requests)
  end

  def test_zones_still_returns_every_zone_name
    stub_zone_list(numbered_zones(75))

    assert_equal((1..75).map { |i| "zone-#{i}.example" }, @cloudflare.zones)
  end

  private

  def zone_id(name)
    @cloudflare.send(:zone_name_to_id, name)
  end

  def zone(name, id)
    { 'id' => id, 'name' => name, 'status' => 'active' }
  end

  def numbered_zones(count)
    (1..count).map { |i| zone("zone-#{i}.example", "id-#{i}") }
  end

  def a_record(zone_name)
    { 'id' => "rec-#{zone_name}", 'name' => "www.#{zone_name}", 'type' => 'A', 'content' => '192.0.2.1', 'ttl' => 600 }
  end

  def json_headers
    { 'Content-Type' => 'application/json' }
  end

  def json_response(body)
    { status: 200, headers: json_headers, body: JSON.generate(body) }
  end

  def api_response(result, page: 1, per_page: 50, total: result.size)
    json_response(
      success: true,
      errors: [],
      messages: [],
      result: result,
      result_info: { page: page, per_page: per_page, count: result.size, total_count: total },
    )
  end

  # Serves the zones 50 to a page, the way Cloudflare does.
  def stub_zone_list(zones)
    pages = zones.empty? ? [[]] : zones.each_slice(50).to_a
    pages.each_with_index do |slice, index|
      stub_request(:get, ZONES_URL)
        .with(query: { page: (index + 1).to_s, per_page: '50' })
        .to_return(api_response(slice, page: index + 1, total: zones.size))
    end
  end

  def stub_name_lookup(name, zones)
    stub_request(:get, ZONES_URL).with(query: { name: name }).to_return(api_response(zones, per_page: 20))
  end

  def stub_records(zone_id, records)
    stub_request(:get, "#{ZONES_URL}/#{zone_id}/dns_records")
      .with(query: { page: '1', per_page: '1000' })
      .to_return(api_response(records, per_page: 1000))
  end

  def list_requests
    requests_matching { |uri| uri.path == '/client/v4/zones' && uri.query.to_s.include?('per_page=50') }
  end

  def name_lookup_requests(name = nil)
    requests_matching do |uri|
      uri.path == '/client/v4/zones' && uri.query.to_s.start_with?('name=') &&
        (name.nil? || uri.query == "name=#{name}")
    end
  end

  def record_requests
    requests_matching { |uri| uri.path.end_with?('/dns_records') }
  end

  def requests_matching
    WebMock::RequestRegistry.instance.requested_signatures.hash.sum do |signature, count|
      yield(signature.uri) ? count : 0
    end
  end
end
