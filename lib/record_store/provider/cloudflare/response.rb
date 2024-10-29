require 'json'

module Cloudflare
  class Response
    attr_reader :http_response

    def initialize(http_response)
      @http_response = http_response
    end

    def status_code
      @http_response.code.to_i
    end

    def result_raw
      result = json['result']

      return if result.nil? || result.empty? || !success

      result
    end

    def result
      result = result_raw
      return result.first if result.is_a?(Array)

      result
    end

    def result_info_raw
      result_info_raw = json['result_info']

      return if result_info_raw.nil? || result_info_raw.empty? || !success

      result_info_raw
    end

    def success
      json['success']
    end

    def errors
      json.fetch('errors', [])
    end

    def messages
      json.fetch('messages', [])
    end

    def error_messages
      errors.map { |error| error['message'] }
    end

    private

    def json_content?
      @http_response['Content-Type']&.match?(%r{application/json})
    end

    def json
      return {} unless json_content?

      JSON.parse(@http_response.body)
    rescue JSON::ParserError => e
      raise "JSON parsing error: #{e.message}"
    end
  end
end
