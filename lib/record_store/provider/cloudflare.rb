require_relative 'cloudflare/client'

module RecordStore
  class Provider::Cloudflare < Provider
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

        retry_on_connection_errors do
          client.get("/client/v4/zones/#{zone_id}/dns_records").result_raw.map do |api_body|
            build_from_api(api_body)
          end
        end
      end

      # Returns an array of the zones managed by provider as strings
      # Cloudflare returns zones across all accounts accessible by the API token
      # Can implement filtering in request if needed
      def zones
        retry_on_connection_errors do
          client.get('/client/v4/zones').result_raw.map { |zone| zone['name'] }
        end
      end

      private

      def add(record, zone)
        zone_id = zone_name_to_id(zone)

        api_body = build_api_body(record)

        retry_on_connection_errors do
          client.post("/client/v4/zones/#{zone_id}/dns_records", api_body)
        end
      end

      def remove(record, zone)
        zone_id = zone_name_to_id(zone)

        retry_on_connection_errors do
          client.delete("/client/v4/zones/#{zone_id}/dns_records/#{record.id}")
        end
      end

      def update(id, record, zone)
        zone_id = zone_name_to_id(zone)

        current_records = retrieve_current_records(zone: zone)
        existing_record = current_records.find { |r| r.id == id }

        if existing_record.nil?
          raise RecordStore::Provider::Error, "Record with id #{id} not found"
        elsif existing_record.fqdn != record.fqdn
          raise RecordStore::Provider::Error, "FQDN mismatch for record with id #{id}"
        end

        api_body = build_api_body(record)

        retry_on_connection_errors do
          client.patch("/client/v4/zones/#{zone_id}/dns_records/#{id}", api_body)
        end
      end

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
          api_body[:content] = record.txtdata.gsub('\;', ';')
        when Record::CAA
          api_body[:data] = record.rdata
        when Record::SRV
          api_body[:data] = rdata
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
          if api_response['settings']['flatten_cname'] == false
            record.merge!(cname: api_response['content'])
          elsif api_response['settings']['flatten_cname'] == true
            record_type = 'ALIAS'
            record.merge!(alias: api_response['content'])
          end
        when 'TXT'
          record.merge!(txtdata: Record.unescape(api_response['content']).gsub(';', '\;'))
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
          secrets['api_fqdn'],
          secrets['api_token'],
        )
      end

      def zone_name_to_id(zone_name)
        retry_on_connection_errors do
          zone_id = nil
          client.get('/client/v4/zones').result_raw.each do |zone|
            zone_id = zone['id'] if zone['name'] == zone_name
          end
          raise "Zone not found: #{zone_name}" unless zone_id

          zone_id
        end
      end
    end
  end
end
