require 'dnsimple'
require_relative 'dnsimple/patch_api_header'

module RecordStore
  class Provider::DNSimple < Provider
    class << self
      def record_types
        super | Set.new(%w(PTR SSHFP))
      end

      def supports_alias?
        true
      end

      # returns an array of Record objects that match the records which exist in the provider
      def retrieve_current_records(zone:, stdout: $stdout)
        retry_on_connection_errors do
          session.zones.all_records(account_id, zone).data.map do |record|
            begin
              build_from_api(record, zone)
            rescue StandardError
              stdout.puts "Cannot build record: #{record}"
              raise
            end
          end.compact
        end
      end

      # Returns an array of the zones managed by provider as strings
      def zones
        retry_on_connection_errors do
          session.zones.all_zones(account_id).data.map(&:name)
        end
      end

      private

      def add(record, zone)
        record_hash = api_hash(record, zone)
        res = session.zones.create_record(account_id, zone, record_hash)

        if record.type == 'ALIAS'
          txt_alias = retrieve_current_records(zone: zone).detect do |rr|
            rr.type == 'TXT' && rr.fqdn == record.fqdn && rr.txtdata == "ALIAS for #{record.alias.chomp('.')}"
          end
          remove(txt_alias, zone)
        end

        res
      end

      def remove(record, zone)
        session.zones.delete_record(account_id, zone, record.id)
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
        fqdn = api_record.name.present? ? "#{api_record.name}.#{zone}" : zone
        fqdn = "#{fqdn}." unless fqdn.ends_with?('.')

        record_type = api_record.type
        record = {
          record_id: api_record.id,
          ttl: api_record.ttl,
          fqdn: fqdn.downcase,
        }

        return if record_type == 'SOA'

        case record_type
        when 'A', 'AAAA'
          record.merge!(address: api_record.content)
        when 'ALIAS'
          record.merge!(alias: api_record.content)
        when 'CAA'
          flags, tag, value = api_record.content.split(' ')

          record.merge!(
            flags: flags.to_i,
            tag: tag,
            value: Record.unquote(value),
          )
        when 'CNAME'
          record.merge!(cname: api_record.content)
        when 'MX'
          record.merge!(preference: api_record.priority, exchange: api_record.content)
        when 'NS'
          record.merge!(nsdname: api_record.content)
        when 'PTR'
          record.merge!(ptrdname: api_record.content)
        when 'SSHFP'
          algorithm, fptype, fingerprint = api_record.content.split(' ')
          record.merge!(
            algorithm: algorithm.to_i,
            fptype: fptype.to_i,
            fingerprint: fingerprint,
          )
        when 'SPF', 'TXT'
          record.merge!(txtdata: Record.unescape(api_record.content).gsub(';', '\;'))
        when 'SRV'
          weight, port, host = api_record.content.split(' ')

          record.merge!(
            priority: api_record.priority,
            weight: weight.to_i,
            port: port.to_i,
            target: Record.ensure_ends_with_dot(host),
          )
        end

        Record.const_get(record_type).new(record)
      end

      def api_hash(record, zone)
        record_hash = {
          name: record.fqdn.gsub(Record.ensure_ends_with_dot(zone).to_s, '').chomp('.'),
          ttl: record.ttl,
          type: record.type,
        }

        case record.type
        when 'A', 'AAAA'
          record_hash[:content] = record.address
        when 'ALIAS'
          record_hash[:content] = record.alias.chomp('.')
        when 'CAA'
          record_hash[:content] = "#{record.flags} #{record.tag} \"#{record.value.chomp('.')}\""
        when 'CNAME'
          record_hash[:content] = record.cname.chomp('.')
        when 'MX'
          record_hash[:priority] = record.preference
          record_hash[:content] = record.exchange.chomp('.')
        when 'NS'
          record_hash[:content] = record.nsdname.chomp('.')
        when 'PTR'
          record_hash[:content] = record.ptrdname.chomp('.')
        when 'SSHFP'
          record_hash[:content] = record.rdata_txt
        when 'SPF', 'TXT'
          record_hash[:content] = Record.escape(record.txtdata).gsub('\;', ';')
        when 'SRV'
          record_hash[:content] = "#{record.weight} #{record.port} #{record.target.chomp('.')}"
          record_hash[:priority] = record.priority
        end
        record_hash
      end
    end
  end
end
