require 'dnsimple'

module RecordStore
  class Provider::DNSimple < Provider
    class << self
      def supports_alias?
        true
      end

      # returns an array of Record objects that match the records which exist in the provider
      def retrieve_current_records(zone:, stdout: $stdout)
        session.zones.all_zone_records(account_id, zone).data.map do |record|
          begin
            build_from_api(record, zone)
          rescue StandardError
            stdout.puts "Cannot build record: #{record}"
            raise
          end
        end.compact
      end

      # Returns an array of the zones managed by provider as strings
      def zones
        session.zones.all_zones(account_id).data.map(&:name)
      end

      private

      def add(record, zone)
        record_hash = api_hash(record, zone)
        res = session.zones.create_zone_record(account_id, zone, record_hash)

        if record.type == 'ALIAS'
          txt_alias = retrieve_current_records(zone: zone).detect do |rr|
            rr.type == 'TXT' && rr.fqdn == record.fqdn && rr.txtdata == "ALIAS for #{record.alias.chomp('.')}"
          end
          remove(txt_alias, zone)
        end

        res
      end

      def remove(record, zone)
        session.zones.delete_zone_record(account_id, zone, record.id)
      end

      def update(id, record, zone)
        session.zones.update_record(account_id, zone, id, api_hash(record, zone))
      end

      def session
        @dns ||= Dnsimple::Client.new(
          base_url: secrets.fetch('base_url'),
          access_token: secrets.fetch('api_token')
        )
      end

      def account_id
        @account_id ||= secrets.fetch('account_id')
      end

      def secrets
        super.fetch('dnsimple')
      end

      def build_from_api(api_record, zone)
        record_type = api_record.type
        record = {
          record_id: api_record.id,
          ttl: api_record.ttl,
          fqdn: api_record.name.present? ? "#{api_record.name}.#{zone}" : zone,
        }

        return if record_type == 'SOA'

        case record_type
        when 'A', 'AAAA'
          record.merge!(address: api_record.content)
        when 'ALIAS'
          record.merge!(alias: api_record.content)
        when 'CNAME'
          record.merge!(cname: api_record.content)
        when 'MX'
          record.merge!(preference: api_record.priority, exchange: api_record.content)
        when 'NS'
          record.merge!(nsdname: api_record.content)
        when 'SPF', 'TXT'
          record.merge!(txtdata: Record::TXT.unescape(api_record.content).gsub(';', '\;'))
        when 'SRV'
          weight, port, host = api_record.content.split(' ')

          record.merge!(
            priority: api_record.priority,
            weight: weight.to_i,
            port: port.to_i,
            target: Record.ensure_ends_with_dot(host),
          )
        end

        unless record.fetch(:fqdn).ends_with?('.')
          record[:fqdn] += '.'
        end

        Record.const_get(record_type).new(record)
      end

      def api_hash(record, zone)
        record_hash = {
          name: record.fqdn.gsub("#{Record.ensure_ends_with_dot(zone)}", '').chomp('.'),
          ttl: record.ttl,
          type: record.type,
        }

        case record.type
        when 'A', 'AAAA'
          record_hash[:content] = record.address
        when 'ALIAS'
          record_hash[:content] = record.alias.chomp('.')
        when 'CNAME'
          record_hash[:content] = record.cname.chomp('.')
        when 'MX'
          record_hash[:priority] = record.preference
          record_hash[:content] = record.exchange.chomp('.')
        when 'NS'
          record_hash[:content] = record.nsdname.chomp('.')
        when 'SPF', 'TXT'
          record_hash[:content] = Record::TXT.escape(record.txtdata).gsub('\;', ';')
        when 'SRV'
          record_hash[:content] = "#{record.weight} #{record.port} #{record.target.chomp('.')}"
          record_hash[:priority] = record.priority
        end

        record_hash
      end
    end
  end
end
