require_relative 'cloudflare/client'

module RecordStore
  class Provider::Cloudflare < Provider
    # Cloudflare returns at most 50 zones per page.
    ZONE_LIST_PER_PAGE = 50

    ZONE_IDS_MUTEX = Mutex.new
    private_constant :ZONE_IDS_MUTEX

    class << self
      def record_types
        super | Set.new(%w(PTR))
      end

      def supports_alias?
        true
      end

      def supports_spf?
        # New as Cloudflare doesn't support the now deprecated spf type
        false
      end

      # Returns: an array of `Record` for each record in the provider's zone
      def retrieve_current_records(zone:, stdout: $stdout)
        zone_id = zone_name_to_id(zone)

        all_records = []
        page = 1
        per_page = 1000

        loop do
          response = nil
          retry_on_connection_errors do
            response = client.get("/client/v4/zones/#{zone_id}/dns_records", page: page, per_page: per_page)
          end

          records = response.result_raw || []
          all_records.concat(records)

          break if page * per_page >= response.result_info_raw['total_count']

          page += 1
        end

        all_records.map { |api_body| build_from_api(api_body) }
      end

      # Returns an array of the zones managed by provider as strings
      # Cloudflare returns zones across all accounts accessible by the API token
      # Can implement filtering in request if needed
      def zones
        list_zones.map { |zone| zone['name'] }
      end

      # Forgets the zone name => id mapping, so the next lookup lists the zones again. The mapping is kept for the
      # life of the process, which is a single record-store run.
      def clear_zone_id_cache
        ZONE_IDS_MUTEX.synchronize { @zone_ids = nil }
      end

      def apply_changeset(changeset, stdout = $stdout)
        deletes = []
        patches = []
        posts = []
        puts = []

        changeset.changes.each do |change|
          case change.type
          when :removal
            stdout.puts "Removing #{change.record}..."
            deletes << { id: change.record.id }
          when :addition
            stdout.puts "Creating #{change.record}..."
            posts << build_api_body(change.record)
          when :update
            stdout.puts "Updating record with ID #{change.id} to #{change.record}..."
            patches << build_api_body(change.record).merge(id: change.id)
          else
            raise ArgumentError, "Unknown change type #{change.type.inspect}"
          end
        end

        return if deletes.empty? && patches.empty? && posts.empty? && puts.empty?

        zone_id = zone_name_to_id(changeset.zone)
        api_body = {
          deletes: deletes,
          patches: patches,
          posts: posts,
          puts: puts
        }

        retry_on_connection_errors do
          response = client.post("/client/v4/zones/#{zone_id}/dns_records/batch", api_body)
          unless response.success
            error_message = response.errors.map { |error| error['message'] }.join(', ')
            raise RecordStore::Provider::Error, "Cloudflare API error: #{error_message}"
          end
        end
      end

      private

      def secrets
        super.fetch('cloudflare')
      end

      def build_api_body(record)
        api_body = {
          name: record.fqdn,
          ttl: record.ttl,
          type: record.type,
        }
        case record
        when Record::A, Record::AAAA
          api_body[:content] = record.rdata_txt
        when Record::CNAME
          api_body[:content] = record.rdata_txt
        when Record::PTR
          api_body[:content] = record.rdata_txt
        when Record::MX
          api_body[:content] = record.exchange
          api_body[:priority] = record.preference
        when Record::TXT, Record::SPF
          api_body[:content] = Record.quote(record.txtdata.gsub('\;', ';'))
        when Record::CAA
          api_body[:data] = record.rdata
        when Record::SRV
          api_body[:data] = record.rdata
        when Record::ALIAS
          api_body[:type] = 'CNAME'
          api_body[:content] = record.rdata_txt
          api_body[:settings] = { flatten_cname: true }
        when Record::NS
          api_body[:content] = record.nsdname
        end

        api_body
      end

      def build_from_api(api_response)
        fqdn = Record.ensure_ends_with_dot(api_response['name'])

        record_type = api_response['type']

        record = {
          record_id: api_response['id'],
          ttl: api_response['ttl'],
          fqdn: fqdn.downcase,
        }

        case record_type
        when 'A', 'AAAA'
          record.merge!(address: api_response['content'])
        when 'CNAME'
          if api_response.dig('settings', 'flatten_cname')
            record_type = 'ALIAS'
            record.merge!(alias: api_response['content'])
          else
            record.merge!(cname: api_response['content'])
          end
        when 'TXT'
          content = Record.unquote(api_response['content'])
          record.merge!(txtdata: content.gsub(';', '\;'))
        when 'MX'
          record.merge!(preference: api_response['priority'], exchange: api_response['content'])
        when 'PTR'
          record.merge!(ptrdname: api_response['content'])
        when 'CAA'
          flags, tag, value = api_response['content'].split(' ')

          record.merge!(
            flags: flags.to_i,
            tag: tag,
            value: Record.unquote(value),
          )
        when 'SRV'
          weight, port, host = api_response['content'].split(' ')

          record.merge!(
            priority: api_response['priority'].to_i,
            weight: weight.to_i,
            port: port.to_i,
            target: Record.ensure_ends_with_dot(host),
          )
        when 'NS'
          record.merge!(nsdname: api_response['content'])
        end

        Record.const_get(record_type).new(record)
      end

      def client
        Cloudflare::Client.new(
          secrets['api_token'],
        )
      end

      # Returns every zone the token can see, as the raw API hashes.
      def list_zones
        all_zones = []
        page = 1

        loop do
          response = nil
          retry_on_connection_errors do
            response = client.get('/client/v4/zones', page: page, per_page: ZONE_LIST_PER_PAGE)
          end

          zones = response.result_raw || []
          all_zones.concat(zones)

          break if page * ZONE_LIST_PER_PAGE >= response.result_info_raw['total_count']

          page += 1
        end

        all_zones
      end

      # Zone ids are looked up from one listing of all zones, which is fetched on first use and shared by every
      # thread. A zone that is not in that listing (for example one created after it was fetched) is looked up on its
      # own, and the answer is remembered.
      def zone_name_to_id(zone_name)
        key = zone_id_cache_key(zone_name)
        ids = zone_ids_by_name[key]

        if ids.nil?
          ids = zone_ids_from_lookup(zone_name)
          remember_zone_ids(key, ids) if ids.size == 1
        end

        case ids.size
        when 0
          raise "Zone not found for #{zone_name}"
        when 1
          ids.first
        else
          raise "Multiple zones found for #{zone_name}. " \
            "API key must only return the zone on which records are to be managed."
        end
      end

      def zone_id_cache_key(zone_name)
        zone_name.to_s.chomp('.').downcase
      end

      # name => [id, ...] for every zone in the account(s). Several ids under one name means the name is ambiguous.
      def zone_ids_by_name
        @zone_ids || ZONE_IDS_MUTEX.synchronize do
          @zone_ids ||= list_zones
            .group_by { |zone| zone_id_cache_key(zone['name']) }
            .transform_values { |zones| zones.map { |zone| zone['id'] } }
            .freeze
        end
      end

      def remember_zone_ids(key, ids)
        ZONE_IDS_MUTEX.synchronize do
          @zone_ids = @zone_ids.merge(key => ids.freeze).freeze if @zone_ids
        end
      end

      def zone_ids_from_lookup(zone_name)
        retry_on_connection_errors do
          matching_zones = client.get("/client/v4/zones", name: zone_name).result_raw || []
          matching_zones.map { |zone| zone['id'] }
        end
      end
    end
  end
end
