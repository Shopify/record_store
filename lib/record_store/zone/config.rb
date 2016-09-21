module RecordStore
  class Zone
    class Config
      include ActiveModel::Validations

      attr_reader :ignore_patterns, :provider, :supports_alias

      validate :validate_zone_config

      def initialize(ignore_patterns: [], provider: nil, supports_alias: nil)
        @ignore_patterns = ignore_patterns
        @provider = provider
        @supports_alias = supports_alias
      end

      def supports_alias?
        @supports_alias = Provider.const_get(provider).supports_alias? if @supports_alias.nil? && valid_provider?
        return @supports_alias
      end

      def to_hash
        {
          provider: provider,
          ignore_patterns: ignore_patterns,
        }
      end

      private

      def validate_zone_config
        errors.add(:provider, 'provider specified does not exist') unless valid_provider?
      end

      def valid_provider?
        Provider.constants.include?(provider.to_s.to_sym)
      end
    end
  end
end
