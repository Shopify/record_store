module RecordStore
  class Zone
    class Config
      include ActiveModel::Validations

      attr_reader :ignore_patterns, :provider

      validate :validate_zone_config

      def initialize(ignore_patterns: [], provider: nil)
        @ignore_patterns = ignore_patterns
        @provider = provider
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
