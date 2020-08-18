require 'resolv'

module RecordStore
  class Provider
    class << self
      def provider_for(object)
        ns_server =
          case object
          when Record::NS
            object.nsdname.chomp('.')
          else
            begin
              master_nameserver_for(object)
            rescue Resolv::ResolvError
              $stderr.puts "Domain doesn't exist (#{object})"
              return
            end
          end

        case ns_server
        when /\.dnsimple\.com\z/
          'DNSimple'
        when /\.dynect\.net\z/
          'DynECT'
        when /\.googledomains\.com\z/
          'GoogleCloudDNS'
        when /\.nsone\.net\z/,
             /\.ns1global\.net\z/,
             /\.ns1global\.org\z/
          'NS1'
        when /\.oraclecloud\.net\z/
          'OracleCloudDNS'
        end
      end

      def record_types
        Set.new([
          'A',
          'AAAA',
          'ALIAS',
          'CAA',
          'CNAME',
          'MX',
          'NS',
          'SPF',
          'SRV',
          'TXT',
        ])
      end

      def supports_alias?
        false
      end

      def build_zone(zone_name:, config:)
        zone = Zone.new(name: zone_name)
        zone.records = retrieve_current_records(zone: zone_name)
        zone.config = config

        zone
      end

      # returns an array of Record objects that match the records which exist in the provider
      def retrieve_current_records(zone:, stdout: $stdout)
        raise NotImplementedError
      end

      # Applies changeset to provider
      def apply_changeset(changeset, stdout = $stdout)
        changeset.changes.each do |change|
          case change.type
          when :removal
            stdout.puts "Removing #{change.record}..."
            remove(change.record, changeset.zone)
          when :addition
            stdout.puts "Creating #{change.record}..."
            add(change.record, changeset.zone)
          when :update
            stdout.puts "Updating record with ID #{change.id} to #{change.record}..."
            update(change.id, change.record, changeset.zone)
          else
            raise ArgumentError, "Unknown change type #{change.type.inspect}"
          end
        end
      end

      # Returns an array of the zones managed by provider as strings
      def zones
        raise NotImplementedError
      end

      def secrets
        @secrets ||= if File.exist?(RecordStore.secrets_path)
          JSON.parse(File.read(RecordStore.secrets_path))
        else
          raise "You don't have a secrets.json file set up!"
        end
      end

      def thawable?
        respond_to?(:thaw_zone)
      end

      def freezable?
        respond_to?(:freeze_zone)
      end

      def to_s
        name.demodulize
      end

      private

      def add(record)
        raise NotImplementedError
      end

      def remove(record)
        raise NotImplementedError
      end

      def update(id, record)
        raise NotImplementedError
      end

      def master_nameserver_for(zone_name)
        dns = Resolv::DNS.new(nameserver: ['8.8.8.8', '8.8.4.4'])

        dns.getresource(zone_name, Resolv::DNS::Resource::IN::SOA).mname.to_s
      end

      def retry_on_connection_errors(
        max_timeouts: 5,
        max_conn_resets: 5,
        delay: 1,
        backoff_multiplier: 2,
        max_backoff: 10
      )
        loop do
          begin
            return yield
          rescue Net::OpenTimeout
            raise if max_timeouts <= 0
            max_timeouts -= 1

            $stderr.puts("Retrying after a connection timeout")
          rescue Errno::ECONNRESET
            raise if max_conn_resets <= 0
            max_conn_resets -= 1

            $stderr.puts("Retrying in #{delay}s after a connection reset")
            backoff_sleep(delay)
            delay = [delay * backoff_multiplier, max_backoff].min
          end
        end
      end

      def backoff_sleep(delay)
        sleep(delay)
      end
    end
  end
end
