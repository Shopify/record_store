require 'oci'

module RecordStore
  class Provider::OracleCloudDNS < Provider
    class Error < StandardError; end

    class << self
      def client
        config = OCI::Config.new
        config.user = secrets["user"]
        config.fingerprint = secrets["fingerprint"]
        config.key_content = secrets["key_content"]
        config.tenancy = secrets["tenancy"]
        config.region = secrets["region"]
        OCI::Dns::DnsClient.new(config: config)
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

      # Returns the version of the zone
      def zone_version(zone)
        client.get_zone(zone).data.version
      end

      # Creates a new record to the zone. It is expected this call modifies external state.
      #
      # Arguments:
      # record - a kind of `Record`
      def add(record, zone)
        record_rdata = retrieve_rdata_based_on_record_type(record)

        patch_add_record = [
          OCI::Dns::Models::RecordOperation.new(
            domain: record.fqdn,
            rtype: record.type,
            ttl: record.ttl,
            rdata: record_rdata,
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
        record_fqdn = record.fqdn.sub(/\.$/, '') # for add, seems not require
        record_hash = ''
        record_rdata = retrieve_rdata_based_on_record_type(record)

        client.get_zone_records(
          zone,
          rtype: record.type,
          zone_version: client.get_zone(zone).data.version,
          domain: record_fqdn,
        ).each do |response|
          response.data.items.each do |r|
            record_hash = r.record_hash
          end
        end

        patch_remove_record = [
          OCI::Dns::Models::RecordOperation.new(
            domain: record_fqdn,
            record_hash: record_hash,
            rtype: record.type,
            ttl: record.ttl,
            rdata: record_rdata,
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
        record_fqdn = record.fqdn.sub(/\.$/, '')
        record_rdata = retrieve_rdata_based_on_record_type(record)

        # Retrieve all records that you want to keep before it's updated because it will overwrite
        all_records = []
        client.get_zone_records(zone, zone_version: zone_version(zone)).each do |response|
          all_records += response.data.items
        end

        update_zone_record_items = all_records.map do |r|
          OCI::Dns::Models::RecordDetails.new(
            domain: r.domain,
            ttl: r.ttl,
            rtype: r.rtype,
            recordHash: r.record_hash,
            rdata: r.rdata,
            rrsetVersion: r.rrset_version,
            isProtected: true
          )
        end
        update_zone_record_items << OCI::Dns::Models::RecordDetails.new(
          domain: record_fqdn,
          ttl: record.ttl,
          rtype: record.type,
          rdata: record_rdata
        )
        update_zone_record_items.delete_if { |r| id == r.record_hash }

        client.update_zone_records(
          zone,
          OCI::Dns::Models::UpdateZoneRecordsDetails.new(items: update_zone_record_items)
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
          preference, exchange = api_record.rdata.split(' ')
          record.merge!(
            preference: preference.to_i,
            exchange: exchange,
          )
        when 'NS'
          record.merge!(nsdname: api_record.rdata)
        when 'SPF', 'TXT'
          record.merge!(txtdata: Record.unquote(api_record.rdata).gsub("\"", ""))
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

      def retrieve_rdata_based_on_record_type(record)
        case record.type
        when 'ALIAS'
          record.rdata[:alias]
        when 'A'
          record.rdata[:address]
        when 'CAA'
          [record.flags.to_s, record.tag, record.value].join(' ')
        when 'SRV'
          [record.priority.to_s, record.weight.to_s, record.port.to_s, record.target].join(' ')
        when 'CNAME'
          record.cname
        when 'MX'
          [record.preference, record.exchange.to_s].join(' ')
        when 'NS'
          record.nsdname
        when 'TXT', 'SPF'
          record.txtdata
        end
      end
    end
  end
end
