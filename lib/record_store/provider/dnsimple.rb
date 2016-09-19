require 'fog/dnsimple'

module RecordStore
  class Provider::DNSimple < Provider
    def self.record_types
      super.add('ALIAS')
    end

    def add(record)
      record_hash = api_hash(record)
      res = session.create_record(
        @zone_name,
        record_hash.fetch(:name),
        record.type,
        record_hash.fetch(:content),
        ttl: record_hash.fetch(:ttl),
        priority: record_hash.fetch(:prio, nil)
      )

      if record.type == 'ALIAS'
        txt_alias = retrieve_current_records.detect do |rr|
          rr.type == 'TXT' && rr.fqdn == record.fqdn && rr.txtdata == "ALIAS for #{record.alias.gsub(/.\z/, '')}"
        end
        remove(txt_alias)
      end

      res
    end

    def remove(record)
      session.delete_record(@zone_name, record.id)
    end

    def update(id, record)
      record_hash = api_hash(record)
      session.update_record(@zone_name, id, api_hash(record))
    end

    # returns an array of Record objects that match the records which exist in the provider
    def retrieve_current_records(stdout = $stdout)
      session.list_records(@zone_name).body.map do |record|
        record_body = record.fetch('record')

        begin
          build_from_api(record_body)
        rescue StandardError
          stdout.puts "Cannot build record: #{record_body}"
          raise
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
        provider: 'DNSimple',
        dnsimple_email: secrets.fetch('email'),
        dnsimple_token: secrets.fetch('api_token'),
      }
    end

    def secrets
      super.fetch('dnsimple')
    end

    def build_from_api(api_record)
      record_type = api_record.fetch('record_type')
      record = {
        record_id: api_record.fetch('id'),
        ttl: api_record.fetch('ttl'),
        fqdn: api_record.fetch('name').present? ? "#{api_record.fetch('name')}.#{@zone_name}" : @zone_name,
      }

      return if record_type == 'SOA'

      case record_type
      when 'A'
        record.merge!(address: api_record.fetch('content'))
      when 'AAAA'
        record.merge!(address: api_record.fetch('content'))
      when 'ALIAS'
        record.merge!(alias: api_record.fetch('content'))
      when 'CNAME'
        record.merge!(cname: api_record.fetch('content'))
      when 'MX'
        record.merge!(preference: api_record.fetch('prio'), exchange: api_record.fetch('content'))
      when 'NS'
        record.merge!(nsdname: api_record.fetch('content'))
      when 'SPF'
        record.merge!(txtdata: api_record.fetch('content'))
      when 'SRV'
        weight, port, host = api_record.fetch('content').split(' ')

        record.merge!(
          priority: api_record.fetch('prio'),
          weight: weight,
          port: port,
          target: Record.ensure_ends_with_dot(host),
        )
      when 'TXT'
        record.merge!(txtdata: api_record.fetch('content'))
      end

      unless record.fetch(:fqdn).ends_with?('.')
        record[:fqdn] += '.'
      end

      Record.const_get(record_type).new(record)
    end

    def api_hash(record)
      record_hash = {
        name: record.fqdn.gsub("#{Record.ensure_ends_with_dot(@zone_name)}", '').gsub(/.\z/, ''),
        ttl: record.ttl,
        type: record.type,
      }

      case record.type
      when 'A'
        record_hash[:content] = record.address
      when 'AAAA'
        record_hash[:content] = record.address
      when 'ALIAS'
        record_hash[:content] = record.alias.gsub(/.\z/, '')
      when 'CNAME'
        record_hash[:content] = record.cname.gsub(/.\z/, '')
      when 'MX'
        record_hash[:prio] = record.preference
        record_hash[:content] = record.exchange.gsub(/.\z/, '')
      when 'NS'
        record_hash[:content] = record.nsdname.gsub(/.\z/, '')
      when 'SPF'
        record_hash[:content] = record.txtdata
      when 'SRV'
        record_hash[:content] = "#{record.weight} #{record.port} #{record.target.gsub(/.\z/, '')}"
        record_hash[:prio] = record.priority
      when 'TXT'
        record_hash[:content] = record.txtdata
      end

      record_hash
    end
  end
end
