module RecordStore
  class Zone
    class Config
      include ActiveModel::Validations

      attr_reader :ignore_patterns, :providers, :supports_alias

      validate :validate_zone_config

      # TODO(es): delete provider when doing major version bump
      def initialize(ignore_patterns: [], providers: nil, supports_alias: nil)
        @ignore_patterns = ignore_patterns
        @providers = providers
        @supports_alias = supports_alias
      end


      # TODO(es): Test for one provider supporting ALIAS and another not
      def supports_alias?
        if @supports_alias.nil?
          valid_providers? && providers.map { |provider| Provider.const_get(provider).supports_alias? }.all?
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
        providers.map { |provider| Provider.constants.include?(provider.to_s.to_sym) }.all?
      end
    end
  end
end
