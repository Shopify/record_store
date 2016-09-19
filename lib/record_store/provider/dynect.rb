require 'fog/dynect'

module RecordStore
  class Provider::DynECT < Provider
    def self.record_types
      super.add('ALIAS')
    end

    def freeze_zone
      session.put_zone(@zone_name, freeze: true)
    end

    def thaw
      session.put_zone(@zone_name, thaw: true)
    end

    def add(record)
      session.post_record(record.type, @zone_name, record.fqdn, record.rdata, ttl: record.ttl)
    end

    def remove(record)
      session.delete_record(record.type, @zone_name, record.fqdn, record.id)
    end

    def update(id, record)
      session.put_record(record.type, @zone_name, record.fqdn, record.rdata, ttl: record.ttl, record_id: id)
    end

    def publish
      session.put_zone(@zone_name, publish: true)
    end

    # Applies changeset to provider
    def apply_changeset(changeset, stdout = $stdout)
      begin
        thaw
        super
        publish
      rescue StandardError
        puts "An exception occurred while applying DNS changes, deleting changeset"
        discard_change_set
        raise
      ensure
        freeze_zone
      end
    end

    # returns an array of Record objects that match the records which exist in the provider
    def retrieve_current_records(stdout = $stdout)
      session.get_all_records(@zone_name).body.fetch('data').flat_map do |type, records|
        records.map do |record_body|
          begin
            build_from_api(record_body)
          rescue StandardError => e
            stdout.puts "Cannot build record: #{record_body}"
          end
        end
      end.select(&:present?)
    end

    # Returns an array of the zones managed by provider as strings
    def zones
      session.zones.map(&:domain)
    end

    private

    def discard_change_set
      session.request(expects: 200, method: :delete, path: "ZoneChanges/#{@zone_name}")
    end

    def session
      @dns ||= Fog::DNS.new(session_params)
    end

    def session_params
      {
        provider: 'Dynect',
        dynect_customer: secrets.fetch('customer'),
        dynect_username: secrets.fetch('username'),
        dynect_password: secrets.fetch('password')
      }
    end

    def secrets
      super.fetch('dynect')
    end

    def build_from_api(api_record)
      record_type = api_record.fetch('record_type')
      record = api_record.merge(api_record.fetch('rdata')).slice!('rdata').symbolize_keys

      return if record_type == 'SOA'

      unless record.fetch(:fqdn).ends_with?('.')
        record[:fqdn] = "#{record.fetch(:fqdn)}."
      end

      Record.const_get(record_type).new(record)
    end
  end
end
