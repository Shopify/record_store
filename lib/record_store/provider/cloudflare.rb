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
          if api_response.dig('settings', 'flatten_cname')
            record_type = 'ALIAS'
            record.merge!(alias: api_response['content'])
          else
            record.merge!(cname: api_response['content'])
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
          matching_zones = client.get('/client/v4/zones').result_raw.select { |zone| zone['name'] == zone_name }

          case matching_zones.size
          when 0
            raise "Zone not found for #{zone_name}"
          when 1
            matching_zones.first['id']
          else
            raise "Multiple zones found for #{zone_name}. " \
              "API key must only return the zone on which records are to be managed."
          end
        end
      end
    end
  end
end
