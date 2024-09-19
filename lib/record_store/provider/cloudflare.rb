require_relative 'cloudflare/client'

module RecordStore
  class Provider::Cloudflare < Provider
    class << self
      def record_types
        super | Set.new(%w(PTR))
      end

      def supports_alias?
        # False in parent class already
        # Investigate if must be true for our implementation
        false
      end

      def supports_spf?
        # New as Cloudflare doesn't support the now deprecated spf type
        false
      end

      # Must implement for parent class
      # Returns: an array of `Record` for each record in the provider's zone
      def retrieve_current_records(zone:, stdout: $stdout)
        # TODO: fake implementation
        retry_on_connection_errors do
          session.zones.all_zone_records(account_id, zone).data.map do |record|
            build_from_api(record, zone)
          rescue StandardError
            stdout.puts "Cannot build record: #{record}"
            raise
          end.compact
        end
      end

      # Returns an array of the zones managed by provider as strings
      # Cloudflare returns zones across all accounts
      def zones
        retry_on_connection_errors do
          client.get('/client/v4/zones').result_raw.map { |zone| zone['name'] }
        end
      end

      # there's no need to wrap `Provider#apply_changeset` unless it's necessary to do something before/after making changes to a zone._

      private

      def add(record, zone)
        zone_id = zone_name_to_id(zone)

        api_record = build_api_body(record)

        retry_on_connection_errors do
          client.post("/client/v4/zones/#{zone_id}/dns_records", api_record)
        end
      end

      def remove(record, zone)
        zone_id = zone_name_to_id(zone)

        retry_on_connection_errors do
          client.delete("/client/v4/zones/#{zone_id}/dns_records/#{record.id}")
        end
      end

      def update(record, zone)
        # Implementation for updating a record in the provider's zone
      end

      def secrets
        super.fetch('cloudflare')
      end

      def build_api_body(record)
        api_record = {
          comment: '',
          name: record[:fqdn],
          proxied: false,
          settings: {},
          tags: record[:tags] || [],
          ttl: record[:ttl] || 1,
          type: record[:type],
        }
        case record
        when Record::A, Record::AAAA
          api_record[:content] = record.rdata_txt
        when Record::CNAME
          api_record[:content] = record.rdata_txt
        when Record::PTR
          api_record[:content] = record.rdata_txt
        when Record::MX
          api_record[:content] = record.exchange
          api_record[:priority] = record.preference
        when Record::TXT, Record::SPF
          api_record[:content] = record.txtdata.gsub('\;', ';')
        when Record::CAA
          api_record[:data] = record.rdata
        when Record::SRV
          api_record[:data] = rdata
        end

        api_record
      end

      # Not required but used in proctical implementations of retrieve_current_records
      def build_from_api(api_record)
        fqdn = Record.ensure_ends_with_dot(api_record['name'])

        record_type = api_record['type']

        record = {
          record_id: api_record['id'],
          ttl: api_record['ttl'],
          fqdn: fqdn.downcase,
        }

        case record_type
        when 'A', 'AAAA'
          record.merge!(address: api_record['content'])
        when 'CNAME'
          record.merge!(cname: api_record['content'])
        when 'TXT'
          record.merge!(txtdata: Record.unescape(api_record['content']).gsub(';', '\;'))
        when 'MX'
          record.merge!(preference: api_record['priority'], exchange: api_record['content'])
        when 'PTR'
          record.merge!(ptrdname: api_record['content'])
        when 'CAA'
          flags, tag, value = api_record['content'].split(' ')

          record.merge!(
            flags: flags.to_i,
            tag: tag,
            value: Record.unquote(value),
          )
        when 'SRV'
          weight, port, host = api_record['content'].split(' ')

          record.merge!(
            priority: api_record['priority'].to_i,
            weight: weight.to_i,
            port: port.to_i,
            target: Record.ensure_ends_with_dot(host),
          )
          # TODO: How to build ALIAS?
        end

        Record.const_get(record_type).new(record)
      end

      def client
        Cloudflare::Client.new(
          secrets['api_fqdn'],
          secrets['api_token'],
          secrets['account_id'],
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
