require 'fog/dnsimple'

module RecordStore
  class Provider::DNSimple < Provider
    class << self
      def supports_alias?
        true
      end

      def add(record, zone)
        record_hash = api_hash(record, zone)
        res = session.create_record(
          zone,
          record_hash.fetch(:name),
          record.type,
          record_hash.fetch(:content),
          ttl: record_hash.fetch(:ttl),
          priority: record_hash.fetch(:priority, nil)
        )

        if record.type == 'ALIAS'
          txt_alias = retrieve_current_records(zone: zone).detect do |rr|
            rr.type == 'TXT' && rr.fqdn == record.fqdn && rr.txtdata == "ALIAS for #{record.alias.chomp('.')}"
          end
          remove(txt_alias, zone)
        end

        res
      end

      def remove(record, zone)
        session.delete_record(zone, record.id)
      end

      def update(id, record, zone)
        session.update_record(zone, id, api_hash(record, zone))
      end

      # returns an array of Record objects that match the records which exist in the provider
      def retrieve_current_records(zone:, stdout: $stdout)
        session.list_records(zone).body.map do |record|
          record_body = record.fetch('record')

          begin
            build_from_api(record_body, zone)
          rescue StandardError
            stdout.puts "Cannot build record: #{record_body}"
            raise
          end
        end.compact
      end

      # Returns an array of the zones managed by provider as strings
      def zones
        session.zones.map(&:domain)
      end

      private

      def session
        @dns ||= Fog::DNS.new(session_params)
      end

      def session_params
        {
          provider: 'DNSimple',
          dnsimple_token: secrets.fetch('api_token'),
          dnsimple_account: secrets.fetch('account_id'),
        }
      end

      def secrets
        super.fetch('dnsimple')
      end

      def build_from_api(api_record, zone)
        record_type = api_record.fetch('type')
        record = {
          record_id: api_record.fetch('id'),
          ttl: api_record.fetch('ttl'),
          fqdn: api_record.fetch('name').present? ? "#{api_record.fetch('name')}.#{zone}" : zone,
        }

        return if record_type == 'SOA'

        case record_type
        when 'A', 'AAAA'
          record.merge!(address: api_record.fetch('content'))
        when 'ALIAS'
          record.merge!(alias: api_record.fetch('content'))
        when 'CNAME'
          record.merge!(cname: api_record.fetch('content'))
        when 'MX'
          record.merge!(preference: api_record.fetch('priority'), exchange: api_record.fetch('content'))
        when 'NS'
          record.merge!(nsdname: api_record.fetch('content'))
        when 'SPF', 'TXT'
          record.merge!(txtdata: api_record.fetch('content').gsub(';', '\;'))
        when 'SRV'
          weight, port, host = api_record.fetch('content').split(' ')

          record.merge!(
            priority: api_record.fetch('priority').to_i,
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
          record_hash[:content] = record.txtdata.gsub('\;', ';')
        when 'SRV'
          record_hash[:content] = "#{record.weight} #{record.port} #{record.target.chomp('.')}"
          record_hash[:priority] = record.priority
        end

        record_hash
      end
    end
  end
end
