module Dnsimple
  class RequestError < Error
    private

    alias_method :original_message_from, :message_from

    def message_from(http_response)
      message = original_message_from(http_response)
      return unless json_response?(http_response)

      base_error = http_response.parsed_response.dig("errors", "base")&.join(", ")
      message += ": #{base_error}" unless base_error.nil?
      message
    end

    def json_response?(http_response)
      http_response.headers["Content-Type"]&.start_with?("application/json")
    end
  end
end
