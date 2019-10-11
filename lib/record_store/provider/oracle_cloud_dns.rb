require 'byebug'
require 'oci'

module RecordStore
  class Provider::OracleCloudDNS < Provider
    class Error < StandardError; end
    
    class << self
      def client
        OCI::Dns::DnsClient.new
      end

      # Downloads all the records from the provider.
      #
      # Returns: an array of `Record` for each record in the provider's zone
      def retrieve_current_records(zone:, stdout: $stdout) # rubocop:disable Lint/UnusedMethodArgument
        all_records = []
        client.get_zone_records(zone, zone_version: zone_version(zone)).each do |response|
          all_records += response.data.items
        end
        all_records.map { |r| build_from_api(r) }.flatten.compact
      end

      # Returns an array of the zones managed by provider as strings
      def zones
        client.list_zones(secrets["compartment_id"]).data.map(&:name) 
      end

      private

      #
      def get_zone(zone)
        client.get_zone(zone).data
      end

      # Returns a version of the zone
      def zone_version(zone)
        client.get_zone(zone).data.version
      end

      # Creates a new record to the zone. It is expected this call modifies external state.
      #
      # Arguments:
      # record - a kind of `Record`
      def add(record, zone)
        patch_add_record = [
          OCI::Dns::Models::RecordOperation.new(
            domain: record.fqdn,
            rtype: record.type,
            ttl: record.ttl,
            rdata: record.rdata[:address],
            operation: 'ADD'
          )
        ]
        
        client.patch_zone_records(
          zone,
          OCI::Dns::Models::PatchZoneRecordsDetails.new(items: patch_add_record)
        )
      end

      # Deletes an existing record from the zone. It is expected this call modifies external state.
      #
      # Arguments:
      # record - a kind of `Record`
      def remove(record, zone)
        record_fqdn = record.fqdn.sub(/\.$/, '') # for add, seems not require
        record_hash = ""

        client.get_zone_records(
          zone,
          rtype: record.type,
          zone_version: client.get_zone(zone).data.version,
          domain: record_fqdn,
        ).each do |response|
           response.data.items.each do |r| record_hash = r.record_hash end
        end

        patch_remove_record = [
          OCI::Dns::Models::RecordOperation.new(
            domain: record_fqdn,
            record_hash: record_hash,
            rtype: record.type,
            ttl: record.ttl,
            rdata: record.rdata[:address],
            operation: 'REMOVE'
          )
        ]
        
        client.patch_zone_records(
          zone,
          OCI::Dns::Models::PatchZoneRecordsDetails.new(items: patch_remove_record)
        )
      end

      # Updates an existing record in the zone. It is expected this call modifies external state.
      #
      # Arguments:
      # id - provider specific ID of record to update
      # record - a kind of `Record` which the record with `id` should be updated to
      def update(id, record, zone)

      end

      def secrets
        super.fetch('oracle_cloud_dns')
      end

      def build_from_api(api_record)
        fqdn = Record.ensure_ends_with_dot(api_record.domain)

        record_type = api_record.rtype
        return if record_type == 'SOA'

        record = {
          ttl: api_record.ttl,
          fqdn: fqdn.downcase,
          record_id: api_record.record_hash,
        }
        
        case record_type
        when 'A', 'AAAA'
          record.merge!(address: api_record.rdata)
        when 'ALIAS'
          record.merge!(alias: api_record.rdata)
        when 'CAA'
          flags, tag, value = api_record.rdata.split(' ')

          record.merge!(
            flags: flags.to_i,
            tag: tag,
            value: Record.unquote(value),
          )
        when 'CNAME'
          record.merge!(cname: api_record.rdata)
        when 'MX'

          preference, exchange = api_record.rdata

          record.merge!(
            preference: preference.to_i,
            exchange: exchange,
          )
        when 'NS'
          record.merge!(nsdname: api_record.rdata)
        when 'SPF', 'TXT'
          record.merge!(txtdata: Record.unescape(api_record.rdata).gsub(';', '\;'))
        when 'SRV'
          priority, weight, port, host = api_record.rdata.split(' ')

          record.merge!(
            priority: priority.to_i,
            weight: weight.to_i,
            port: port.to_i,
            target: Record.ensure_ends_with_dot(host),
          )
        end
        Record.const_get(record_type).new(record)
      end
    end
  end
end
