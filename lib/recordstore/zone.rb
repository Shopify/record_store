module RecordStore
  class Zone
    module YamlDefinitions
      include Enumerable

      def all
        defined.values
      end

      def defined
        @defined ||= yaml_files.inject({}) { |zones, file| zones.merge(load_yaml_file(file)) }
      end

      def [](name)
        defined.fetch(name)
      end

      def each(&block)
        defined.each(&block)
      end

      def find(name)
        return unless File.exists?(zone_path = "#{RecordStore.zones_path}/#{name}.yml")
        Zone.from_yaml_definition(*YAML.load_file(zone_path).first)
      end

      private

      def load_yaml_file(filename)
        result = {}
        YAML.load_file(filename).each do |name, definition|
          result[name] = Zone.from_yaml_definition(name, definition)
        end
        result
      end

      def yaml_files
        Dir["#{RecordStore.zones_path}/*.yml"]
      end
    end

    extend YamlDefinitions
    include ActiveModel::Validations

    attr_accessor :name
    attr_reader :config
    attr_writer :records

    validates :name, presence: true, format: { with: Record::FQDN_REGEX, message: 'is not a fully qualified domain name' }
    validate :validate_records
    validate :validate_config
    validate :validate_all_records_are_unique
    validate :validate_a_records_for_same_fqdn
    validate :validate_cname_records_for_same_fqdn
    validate :validate_cname_records_dont_point_to_root
    validate :validate_provider_can_handle_zone_records

    def self.from_yaml_definition(name, definition)
      new(name, definition.deep_symbolize_keys)
    end

    def self.download(name, provider_name)
      dns = new(name, config: {provider: provider_name}).provider
      current_records = dns.retrieve_current_records

      File.write("#{RecordStore.zones_path}/#{name}.yml", {
        name => {
          config: {
            provider: provider_name,
            ignore_patterns: [{type: "NS", fqdn: "#{name}."}],
          },
          records: current_records.map(&:to_hash).sort_by! {|r| [r.fetch(:fqdn), r.fetch(:type), r[:nsdname] || r[:address]]}
        }
      }.deep_stringify_keys.to_yaml.gsub("---\n", ''))
    end

    def initialize(name, records: [], config: {})
      @name            = Record.ensure_ends_with_dot(name)
      @config          = RecordStore::Zone::Config.new(config)
      @records         = build_records(records)
    end

    def changeset
      current_records = Zone.filter_records(provider.retrieve_current_records, config.ignore_patterns)

      Changeset.new(
        current_records: current_records,
        desired_records: records
      )
    end

    def unchanged?
      changeset.empty?
    end

    def records
      @records_cache ||= Zone.filter_records(@records, config.ignore_patterns)
    end

    def config=(config)
      @records_cache = nil
      @config = config
    end

    def provider
      Provider.const_get(config.provider).new(zone: name.gsub(/\.\z/, ''))
    end

    private

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

    def validate_a_records_for_same_fqdn
      a_records = records.select { |record| record.is_a?(Record::A) }.group_by(&:fqdn)
      a_records.each do |fqdn, records|
        if records.map(&:ttl).uniq.size > 1
          errors.add(:records, "All A records for #{fqdn} should have the same TTL")
        end
      end
    end

    def validate_cname_records_for_same_fqdn
      cname_records = records.select { |record| record.is_a?(Record::CNAME) }
      cname_records.each do |cname_record|
        records.each do |record|
          if record.fqdn == cname_record.fqdn && record != cname_record
            case record.type
              when 'SIG', 'NXT', 'KEY'
                # this is fine
              when 'CNAME'
                errors.add(:records, "Multiple CNAME records are defined for #{record.fqdn}: #{record}")
              else
                errors.add(:records, "A CNAME record is defined for #{cname_record.fqdn}, so this record is not allowed: #{record}")
            end
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

    def self.filter_records(current_records, ignore_patterns)
      ignore_patterns.inject(current_records) do |remaining_records, pattern|
        remaining_records.reject do |record|
          pattern.all? { |(key, value)| record.respond_to?(key) && value === record.send(key) }
        end
      end
    end

    def validate_provider_can_handle_zone_records
      record_types = records.map(&:type).to_set
      return unless config.valid?
      provider_supported_record_types = Provider.const_get(config.provider).record_types

      (record_types - provider_supported_record_types).each do |record_type|
        errors.add(:records, "#{record_type} is a not a supported record type in #{config.provider}")
      end
    end
  end
end
