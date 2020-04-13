module RecordStore
  class Zone
    extend YamlDefinitions
    include ActiveModel::Validations

    attr_accessor :name
    attr_reader :config

    validates :name, presence: true, format:
      {
        with: Record::FQDN_REGEX,
        message: 'is not a fully qualified domain name',
      }
    validate :validate_records
    validate :validate_config
    validate :validate_all_records_are_unique
    validate :validate_cname_records_for_same_fqdn
    validate :validate_cname_records_dont_point_to_root
    validate :validate_same_ttl_for_records_sharing_fqdn_and_type
    validate :validate_provider_can_handle_zone_records
    validate :validate_can_handle_alias_records

    class << self
      def download(name, provider_name, **write_options)
        zone = Zone.new(name: name, config: { providers: [provider_name] })
        raise ArgumentError, zone.errors.full_messages.join("\n") unless zone.valid?

        zone.records = zone.providers.first.retrieve_current_records(zone: name)

        zone.config = Zone::Config.new(
          providers: [provider_name],
          ignore_patterns: [{ type: "NS", fqdn: "#{name}." }],
          supports_alias: (zone.records.map(&:type).include?('ALIAS') || nil)
        )

        zone.write(**write_options)
      end

      def filter_records(current_records, ignore_patterns)
        ignore_patterns.inject(current_records) do |remaining_records, pattern|
          remaining_records.reject do |record|
            pattern.ignore?(record)
          end
        end
      end

      MAX_PARALLEL_THREADS = 10
      def modified(verbose: false) # rubocop:disable Lint/UnusedMethodArgument
        modified_zones = []
        mutex = Mutex.new
        zones = all

        (1..MAX_PARALLEL_THREADS).map do
          Thread.new do
            current_zone = nil
            while zones.any?
              mutex.synchronize { current_zone = zones.shift }
              mutex.synchronize { modified_zones << current_zone } unless current_zone.unchanged?
            end
          end
        end.each(&:join)

        modified_zones
      end
    end

    def initialize(name:, records: [], config: {})
      @name = Record.ensure_ends_with_dot(name)
      @config = RecordStore::Zone::Config.new(config.deep_symbolize_keys)
      @records = build_records(records)
    end

    def build_changesets
      @changesets ||= begin
        providers.map do |provider|
          Changeset.build_from(provider: provider, zone: self)
        end
      end
    end

    def unchanged?
      build_changesets.all?(&:empty?)
    end

    def unrooted_name
      @name.chomp('.')
    end

    def all
      @records
    end

    def records
      @records_cache ||= Zone.filter_records(@records, config.ignore_patterns)
    end

    def records=(records)
      @records_cache = nil
      @records = records
    end

    def config=(config)
      @records_cache = nil
      @config = config
    end

    def providers
      @providers ||= config.providers.map { |provider| Provider.const_get(provider) }
    end

    def write(**write_options)
      self.class.write(name, config: config, records: records, **write_options)
    end

    ROOT_SERVERS = %w(
      a.root-servers.net
      b.root-servers.net
      c.root-servers.net
      d.root-servers.net
      e.root-servers.net
      f.root-servers.net
      g.root-servers.net
      h.root-servers.net
      i.root-servers.net
      j.root-servers.net
      k.root-servers.net
      l.root-servers.net
      m.root-servers.net
    )

    def fetch_delegation(nameserver = ROOT_SERVERS.sample)
      Resolv::DNS.open(nameserver: nameserver) do |resolv|
        resolv.fetch_resource(name, Resolv::DNS::Resource::IN::SOA) do |reply, name|
          break if reply.answer.any?

          raise "No authority found (#{name})" unless reply.authority.any?

          break extract_delegation(reply)
        end
      end
    end

    private

    def extract_delegation(reply)
      authority = reply.authority.sample

      if unrooted_name.casecmp?(authority.first.to_s)
        extract_authority(reply.authority)
      else
        fetch_delegation(authority.last.name.to_s) || extract_authority(reply.authority)
      end
    end

    def extract_authority(authority)
      authority.map.with_index do |(name, ttl, data), index|
        Record::NS.new(ttl: ttl, fqdn: name.to_s, nsdname: data.name.to_s, record_id: index)
      end
    end

    def build_records(records)
      records.map { |record| Record.build_from_yaml_definition(record) }
    end

    def validate_records
      records.each do |record|
        unless record.fqdn.end_with?(name)
          errors.add(:records, "record #{record} does not belong in zone #{name}")
        end

        unless record.valid?
          errors.add(:records, "invalid record: #{record}")
        end
      end
    end

    def validate_config
      unless config.valid?
        errors.add(:config, "invalid config: #{config}")
      end
    end

    def validate_all_records_are_unique
      duplicates = records.select { |r| records.count(r) > 1 }
      duplicates.uniq.each do |record|
        errors.add(:records, "Duplicate record: #{record}")
      end
    end

    def validate_same_ttl_for_records_sharing_fqdn_and_type
      records_sharing_fqdn_and_type = records.group_by { |record| [record.type, record.fqdn] }
      records_sharing_fqdn_and_type.each do |(type, fqdn), matching_records|
        all_ttls = matching_records.map(&:ttl).uniq
        if all_ttls.length > 1
          errors.add(:records, "All #{type} records for #{fqdn} should have the same TTL")
        end
      end
    end

    def validate_cname_records_for_same_fqdn
      cname_records = records.select { |record| record.is_a?(Record::CNAME) }
      cname_records.each do |cname_record|
        records.each do |record|
          next unless record.fqdn == cname_record.fqdn && record != cname_record
          case record.type
          when 'SIG', 'NXT', 'KEY'
            # this is fine
          when 'CNAME'
            errors.add(:records, "Multiple CNAME records are defined for #{record.fqdn}: #{record}")
          else
            cname_error = "A CNAME record is defined for #{cname_record.fqdn}, so this record is not allowed: #{record}"
            errors.add(:records, cname_error)
          end
        end
      end
    end

    def validate_cname_records_dont_point_to_root
      cname_record = records.detect { |record| record.is_a?(Record::CNAME) && record.fqdn == @name }

      unless cname_record.nil?
        errors.add(:records, "A CNAME record cannot be defined on the root of the zone: #{cname_record}")
      end
    end

    def validate_provider_can_handle_zone_records
      record_types = records.map(&:type).to_set
      return unless config.valid?

      providers.each do |provider|
        (record_types - provider.record_types).each do |record_type|
          errors.add(:records, "#{record_type} is not a supported record type in #{provider}")
        end
      end
    end

    def validate_can_handle_alias_records
      return unless records.any? { |record| record.is_a?(Record::ALIAS) }
      return if config.supports_alias?

      # TODO(es): refactor to specify which provider
      errors.add(:records, "one of the providers for #{unrooted_name} does not support ALIAS records")
    end

    def validate_alias_points_to_root
      alias_record = records.find { |record| record.is_a?(Record::ALIAS) && record.fqdn != @name }

      return unless alias_record

      errors.add(:records, "ALIAS record should be defined on the root of the zone: #{alias_record}")
    end
  end
end
