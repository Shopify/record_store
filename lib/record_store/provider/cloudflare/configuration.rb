module Cloudflare
  class Configuration
    attr_writer :api_host, :zone_id, :api_token, :account_id

    class << self
      def config(&block)
        @current_config = new(&block) if block
        @current_config || new
      end

      def reset
        @current_config = nil
      end
    end

    def initialize
      yield(self) if block_given?
    end

    def api_host
      @api_host || ENV['CLOUDFLARE_API_HOST']
    end

    def zone_id
      @zone_id || ENV['CLOUDFLARE_ZONE_ID']
    end

    def api_token
      @api_token || ENV['CLOUDFLARE_API_TOKEN']
    end

    def account_id
      @account_id || ENV['CLOUDFLARE_ACCOUNT_ID']
    end
  end
end
