module RecordStore
  class Zone
    class Config
      include ActiveModel::Validations

      attr_reader :ignore_patterns, :providers, :supports_alias, :implicit_records_templates

      validate :validate_zone_config

      def initialize(ignore_patterns: [], providers: nil, supports_alias: nil, implicit_records_templates: [])
        @ignore_patterns = ignore_patterns.map do |ignore_pattern|
          Zone::Config::IgnorePattern.new(ignore_pattern)
        end
        @implicit_records_templates = implicit_records_templates.map do |filename|
          Zone::Config::ImplicitRecordTemplate.from_file(filename: filename)
        end
        @providers = providers
        @supports_alias = supports_alias
      end

      def supports_alias?
        if @supports_alias.nil?
          valid_providers? && providers.all? { |provider| Provider.const_get(provider).supports_alias? }
        else
          @supports_alias
        end
      end

      def empty_non_terminal_over_wildcard?
        valid_providers? && providers.any? { |provider| Provider.const_get(provider).empty_non_terminal_over_wildcard? }
      end

      def to_hash
        config_hash = {
          providers: providers,
          ignore_patterns: ignore_patterns.map(&:to_hash),
        }
        config_hash.merge!(supports_alias: supports_alias) if supports_alias

        config_hash
      end

      private

      def validate_zone_config
        errors.add(:providers, 'provider specified does not exist') unless valid_providers?
      end

      def valid_providers?
        providers.present? && providers.all? { |provider| Provider.constants.include?(provider.to_s.to_sym) }
      end
    end
  end
end
