require 'oci'
require 'byebug'

module RecordStore
  class Provider::OracleCloudDNS < Provider
    class Error < StandardError; end

    class << self
      def client
        @client ||= begin
          config = OCI::Config.new
          config.user = secrets['user']
          config.fingerprint = secrets['fingerprint']
          config.key_content = secrets['key_content']
          config.tenancy = secrets['tenancy']
          config.region = secrets['region']
          config.validate
          OCI::Dns::DnsClient.new(config: config)
        end
      end

      # Downloads all the records from the provider.
      #
      # Returns: an array of `Record` for each record in the provider's zone
      def retrieve_current_records(zone:, stdout: $stdout)
        client.get_zone_records(zone)
          .flat_map { |response| response.data.items }
          .flat_map { |api_record| build_from_api(api_record) }
          .compact
      rescue OCI::Errors::HttpRequestBasedError
        stdout.puts "Cannot build record for zone: #{zone}"
        raise
      end

      # Returns an array of the zones managed by provider as strings
      def zones
        client.list_zones(secrets['compartment_id']).data.map(&:name)
      end

      private

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
            rdata: record.rdata_txt,
            operation: 'ADD',
          ),
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
        record_fqdn = Record.ensure_ends_without_dot(record.fqdn)
        found_record = client.get_zone_records(
          zone,
          rtype: record.type,
          domain: record_fqdn,
        ).data.items.select { |r| r.rdata == record.rdata_txt }

        return unless found_record
        record_hash = found_record.first.record_hash if found_record.length == 1
        patch_remove_record = [
          OCI::Dns::Models::RecordOperation.new(
            domain: record_fqdn,
            record_hash: record_hash,
            rtype: record.type,
            ttl: record.ttl,
            rdata: record.rdata_txt,
            operation: 'REMOVE',
          ),
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
        record_fqdn = Record.ensure_ends_without_dot(record.fqdn)

        # Retrieve all records that you want to keep before it's updated because it will overwrite
        all_records = client.get_zone_records(zone).map(&:data).map(&:items).flatten

        update_zone_record_items = all_records.map do |r|
          OCI::Dns::Models::RecordDetails.new(
            domain: r.domain,
            ttl: r.ttl,
            rtype: r.rtype,
            recordHash: r.record_hash,
            rdata: r.rdata,
            rrsetVersion: r.rrset_version,
            isProtected: true,
          )
        end

        update_zone_record_items << OCI::Dns::Models::RecordDetails.new(
          domain: record_fqdn,
          ttl: record.ttl,
          rtype: record.type,
          rdata: record.rdata_txt
        )
        update_zone_record_items.delete_if { |r| id == r.record_hash }

        client.update_zone_records(
          zone,
          OCI::Dns::Models::UpdateZoneRecordsDetails.new(items: update_zone_record_items),
        )
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
          record[:address] = api_record.rdata
        when 'ALIAS'
          record[:alias] = api_record.rdata
        when 'CAA'
          flags, tag, value = api_record.rdata.split
          record[:flags] = flags.to_i
          record[:tag] = tag
          record[:value] = Record.unquote(value)
        when 'CNAME'
          record[:cname] = api_record.rdata
        when 'MX'
          preference, exchange = api_record.rdata.split
          record[:preference] = preference.to_i
          record[:exchange] = exchange
        when 'NS'
          record[:nsdname] = api_record.rdata
        when 'SPF', 'TXT'
          record[:txtdata] = Record.unquote(api_record.rdata)
        when 'SRV'
          priority, weight, port, host = api_record.rdata.split
          record[:priority] = priority.to_i
          record[:weight] = weight.to_i
          record[:port] = port.to_i
          record[:target] = Record.ensure_ends_with_dot(host)
        else
          raise NameError, "Unsupported record type: #{record_type}"
        end
        Record.const_get(record_type).new(record)
      end
    end
  end
end
