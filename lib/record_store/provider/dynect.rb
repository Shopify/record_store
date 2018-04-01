require 'fog/dynect'

module RecordStore
  class Provider::DynECT < Provider
    class << self
      def freeze_zone(zone)
        session.put_zone(zone, freeze: true)
      end

      def thaw_zone(zone)
        session.put_zone(zone, thaw: true)
      end

      def publish(zone)
        session.put_zone(zone, publish: true)
      end

      # Applies changeset to provider
      def apply_changeset(changeset, stdout = $stdout)
        begin
          thaw_zone(changeset.zone)
          super
          publish(changeset.zone)
        rescue StandardError
          puts "An exception occurred while applying DNS changes, deleting changeset"
          discard_change_set(changeset.zone)
          raise
        ensure
          freeze_zone(changeset.zone)
        end
      end

      # returns an array of Record objects that match the records which exist in the provider
      def retrieve_current_records(zone:, stdout: $stdout)
        session.get_all_records(zone).body.fetch('data').flat_map do |type, records|
          records.map do |record_body|
            begin
              build_from_api(record_body)
            rescue StandardError
              stdout.puts "Cannot build record: #{record_body}"
            end
          end
        end.compact
      end

      # Returns an array of the zones managed by provider as strings
      def zones
        session.zones.map(&:domain)
      end

      private

      def add(record, zone)
        session.post_record(record.type, zone, record.fqdn, record.rdata, 'ttl' => record.ttl)
      end

      def remove(record, zone)
        session.delete_record(record.type, zone, record.fqdn, record.id)
      end

      def update(id, record, zone)
        session.put_record(record.type, zone, record.fqdn, record.rdata, 'ttl' => record.ttl, 'record_id' => id)
      end

      def discard_change_set(zone)
        session.request(expects: 200, method: :delete, path: "ZoneChanges/#{zone}")
      end

      def session
        @dns ||= Fog::DNS.new(session_params)
      end

      def session_params
        {
          provider: 'Dynect',
          dynect_customer: secrets.fetch('customer'),
          dynect_username: secrets.fetch('username'),
          dynect_password: secrets.fetch('password'),
          job_poll_timeout: 20
        }
      end

      def secrets
        super.fetch('dynect')
      end

      def build_from_api(api_record)
        record = api_record.merge(api_record.fetch('rdata')).slice!('rdata').symbolize_keys

        return if record.fetch(:record_type) == 'SOA'

        unless record.fetch(:fqdn).ends_with?('.')
          record[:fqdn] = "#{record.fetch(:fqdn)}."
        end

        Record.const_get(record.fetch(:record_type)).new(record)
      end
    end
  end
end
