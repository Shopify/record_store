require 'ns1'

module RecordStore
  class Provider::NS1 < Provider
    class Error < StandardError; end

    class Client < ::NS1::Client
      def initialize(api_key:)
        super(api_key)
      end

      def zones
        super
      end

      def zone(name)
        super(name)
      end

      def record(zone:, fqdn:, type:, must_exist: false)
        result = super(zone, fqdn, type)
        raise(Error, result.to_s) if must_exist && result.is_a?(NS1::Response::Error)
        return nil if result.is_a?(NS1::Response::Error)
        result
      end

      def create_record(zone:, fqdn:, type:, params:)
        result = super(zone, fqdn, type, params)
        raise(Error, result.to_s) if result.is_a? NS1::Response::Error
        nil
      end

      def modify_record(zone:, fqdn:, type:, params:)
        result = super(zone, fqdn, type, params)
        raise(Error, result.to_s) if result.is_a? NS1::Response::Error
        nil
      end

      def delete_record(zone:, fqdn:, type:)
        result = super(zone, fqdn, type)
        raise(Error, result.to_s) if result.is_a? NS1::Response::Error
        nil
      end
    end
  end

end
