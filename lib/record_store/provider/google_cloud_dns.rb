require 'google/cloud/dns'

module RecordStore
  class Provider::GoogleCloudDNS < Provider
    class << self
      def apply_changeset(changeset, stdout = $stdout)
        zone = session.zone(convert_to_name(changeset.zone))

        deletions = convert_records_to_gcloud_record_sets(zone, changeset.current_records)
        additions = convert_records_to_gcloud_record_sets(zone, changeset.desired_records)

        # The Google API library will handle applying the changeset transactionally
        zone.update(additions, deletions)
      end

      # returns an array of Record objects that match the records which exist in the provider
      def retrieve_current_records(zone:, stdout: $stdout)
        gcloud_record_sets = session.zone(convert_to_name(zone)).records

        records = gcloud_record_sets.map do |record_set|
          next if record_set.type == 'SOA'

          # Unroll each record set into multiple records
          record_set.data.map do |record|
            begin
              record_set_member = record_set.dup
              record_set_member.data = [record]
              build_from_api(record_set_member)
            rescue StandardError
              stdout.puts "Cannot build record: #{record}"
            end
          end
        end

        # We need to filter out for nil records (i.e. since skip the SOA record)
        records.flatten.compact
      end

      # Returns an array of the zones managed by provider as strings
      def zones
        session.zones.map { |zone| zone.gapi.dns_name }
      end

      private

      def session
        @dns ||= begin
          Google::Cloud::Dns.new(
            project_id: secrets.fetch('project_id'),
            credentials: Google::Cloud::Dns::Credentials.new(secrets),
          )
        end
      end

      def secrets
        super.fetch('google_cloud_dns')
      end

      def convert_to_name(zone)
        zone.gsub('.', '-')
      end

      # Google's API operates on resource record sets instead of individual
      # records. A resource record set is a single object that has the rdata
      # for all resource records with the same fully qualified domain name and
      # record type. See https://cloud.google.com/dns/api/v1/resourceRecordSets
      #
      # This methods takes an array of records and builds Google API
      # ResourceRecordSets objects.
      def convert_records_to_gcloud_record_sets(zone, records)
        record_sets = records.group_by do |record|
          [record.type, record.fqdn]
        end

        record_sets.map do |(rr_type, rr_fqdn), records_for_set|
          zone.record(rr_fqdn, rr_type, records_for_set[0].ttl, records_for_set.map(&:rdata_txt))
        end
      end

      def build_from_api(record)
        fqdn = record.name.downcase
        fqdn = "#{fqdn}." unless fqdn.ends_with?('.')

        record_params = {
          id: record.object_id,
          ttl: record.ttl,
          fqdn: fqdn,
        }

        return if record.type == 'SOA'

        case record.type
        when 'A', 'AAAA'
          record_params.merge!(address: record.data[0])
        when 'CAA'
          flags, tag, value = record.data[0].split(' ')

          record_params.merge!(
            flags: flags.to_i,
            tag: tag,
            value: Record.unquote(value),
          )
        when 'CNAME'
          record_params.merge!(cname: record.data[0])
        when 'MX'
          preference, exchange = record.data[0].split(' ')
          record_params.merge!(preference: preference, exchange: exchange)
        when 'NS'
          record_params.merge!(nsdname: record.data[0])
        when 'SPF', 'TXT'
          txtdata = Record.unquote(record.data[0]).gsub(';', '\;')
          record_params.merge!(txtdata: txtdata)
        when 'SRV'
          priority, weight, port, target = record.data[0].split(' ')

          record_params.merge!(
            priority: priority.to_i,
            weight: weight.to_i,
            port: port.to_i,
            target: target,
          )
        end

        Record.const_get(record.type).new(record_params)
      end
    end
  end
end
