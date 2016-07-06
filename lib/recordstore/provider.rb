module RecordStore
  class Provider
    def self.provider_for(zone_name)
      dns = Resolv::DNS.new(nameserver: ['8.8.8.8', '8.8.4.4'])

      begin
        ns_server = dns.getresource(zone_name, Resolv::DNS::Resource::IN::SOA).mname.to_s
      rescue Resolv::ResolvError => e
        abort "Domain doesn't exist"
      end

      case ns_server
      when /dnsimple\.com\z/
        'DNSimple'
      when /dynect\.net\z/
        'DynECT'
      else
        nil
      end
    end

    def self.record_types
      Set.new([
        'A',
        'AAAA',
        'CNAME',
        'MX',
        'NS',
        'SPF',
        'SRV',
        'TXT',
      ])
    end

    def initialize(zone:)
      @zone_name = zone
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
              remove(change.record)
            when :addition;
              stdout.puts "Creating #{change.record}..."
              add(change.record)
            when :update;
              stdout.puts "Updating record with ID #{change.id} to #{change.record}..."
              update(change.id, change.record)
            else
              raise ArgumentError, "Unknown change type #{change.type.inspect}"
          end
        end

        puts "\nPublished #{@zone_name} changes"
      end
    end

    # returns an array of Record objects that match the records which exist in the provider
    def retrieve_current_records(stdout = $stdout)
      raise NotImplementedError
    end

    # Returns an array of the zones managed by provider as strings
    def zones
      raise NotImplementedError
    end

    def secrets
      @secrets ||= if File.exists?(RecordStore.secrets_path)
        JSON.parse(File.read(RecordStore.secrets_path))
      else
        raise "You don't have a secrets.json file set up!"
      end
    end

    def thawable?
      self.class.method_defined?(:thaw)
    end

    def freezable?
      self.class.method_defined?(:freeze_zone)
    end
  end
end
