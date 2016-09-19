module RecordStore
  class Zone
    class Config
      include ActiveModel::Validations

      attr_reader :ignore_patterns, :provider, :supports_alias
      alias supports_alias? supports_alias

      validate :validate_zone_config

      def initialize(ignore_patterns: [], provider: nil, supports_alias: false)
        @ignore_patterns = ignore_patterns
        @provider = provider
        @supports_alias = supports_alias
      end

      def to_hash
        {
          provider: provider,
          ignore_patterns: ignore_patterns,
        }
      end

      private

      def validate_zone_config
        unless Provider.constants.include?(provider.to_s.to_sym)
          errors.add(:provider, 'provider specified does not exist')
        end
      end
    end
  end
end
