require 'net/http'
require_relative '../provider_utils/rate_limit'

# Patch the method which retrieves headers for API rate limit dynamically
module NS1::Transport
  class NetHttp
    def process_response(response)
      sleep_time = response.to_hash['x-ratelimit-period'].first.to_i /
                   [1, response.to_hash['x-ratelimit-remaining'].first.to_i].max.to_f

      rate_limit = RateLimit.new('NS1')
      rate_limit.sleep_for(sleep_time)

      body = JSON.parse(response.body)
      case response
      when Net::HTTPOK
        NS1::Response::Success.new(body, response.code.to_i)
      else
        NS1::Response::Error.new(body, response.code.to_i)
      end
    rescue JSON::ParserError
      raise NS1::Transport::ResponseParseError
    end
  end
end
