require 'net/http'
require_relative '../provider_utils/waiter'

# Patch the method which retrieves headers for API rate limit dynamically
module NS1::Transport
  class NetHttp
    X_RATELIMIT_PERIOD = 'x-ratelimit-period'.freeze
    X_RATELIMIT_REMAINING = 'x-ratelimit-remaining'.freeze

    def process_response(response)
      response_hash = response.to_hash

      if response_hash.key?(X_RATELIMIT_PERIOD) && response_hash.key?(X_RATELIMIT_REMAINING)
        sleep_time = response_hash[X_RATELIMIT_PERIOD].first.to_i /
                     [1, response_hash[X_RATELIMIT_REMAINING].first.to_i].max.to_f

        rate_limit = RateLimitWaiter.new('NS1')
        rate_limit.wait(sleep_time)
      end

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
