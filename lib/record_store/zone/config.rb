module RecordStore
  class Zone
    class Config
      include ActiveModel::Validations

      attr_reader :ignore_patterns, :providers, :supports_alias

      validate :validate_zone_config

      def initialize(ignore_patterns: [], providers: nil, supports_alias: nil)
        @ignore_patterns = ignore_patterns
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

      def to_hash
        {
          providers: providers,
          ignore_patterns: ignore_patterns,
        }
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
