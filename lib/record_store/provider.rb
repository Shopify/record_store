require 'resolv'

module RecordStore
  class Provider
    class << self
      def provider_for(zone_name)
        dns = Resolv::DNS.new(nameserver: ['8.8.8.8', '8.8.4.4'])

        begin
          ns_server = dns.getresource(zone_name, Resolv::DNS::Resource::IN::SOA).mname.to_s
        rescue Resolv::ResolvError
          abort "Domain doesn't exist"
        end

        case ns_server
        when /dnsimple\.com\z/
          'DNSimple'
        when /dynect\.net\z/
          'DynECT'
        when /googledomains\.com\z/
          'GoogleCloudDNS'
        else
          nil
        end
      end

      def record_types
        Set.new([
          'A',
          'AAAA',
          'ALIAS',
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

      def add(record)
        raise NotImplementedError
      end

      def remove(record)
        raise NotImplementedError
      end

      def update(id, record)
        raise NotImplementedError
      end

      # Applies changeset to provider
      def apply_changeset(changeset, stdout = $stdout)
        begin
          stdout.puts "Applying #{changeset.additions.size} additions, #{changeset.removals.size} removals, & #{changeset.updates.size} updates..."

          changeset.changes.each do |change|
            case change.type
              when :removal;
                stdout.puts "Removing #{change.record}..."
                remove(change.record, changeset.zone)
              when :addition;
                stdout.puts "Creating #{change.record}..."
                add(change.record, changeset.zone)
              when :update;
                stdout.puts "Updating record with ID #{change.id} to #{change.record}..."
                update(change.id, change.record, changeset.zone)
              else
                raise ArgumentError, "Unknown change type #{change.type.inspect}"
            end
          end

          puts "\nPublished #{changeset.zone} changes to #{changeset.provider.to_s}\n"
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
        self.respond_to?(:thaw_zone)
      end

      def freezable?
        self.respond_to?(:freeze_zone)
      end

      def to_s
        self.name.demodulize
      end
    end
  end
end
