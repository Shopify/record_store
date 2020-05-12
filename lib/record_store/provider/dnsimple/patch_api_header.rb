# Patch Dnsimple client method which retrieves headers for API rate limit dynamically
module Dnsimple
  class Client
    def execute(method, path, data = nil, options = {})
      response = request(method, path, data, options)
      rate_limit_sleep(response.headers["x-ratelimit-reset"].to_i, response.headers["x-ratelimit-remaining"].to_i)

      case response.code
      when 200..299
        response
      when 401
        raise AuthenticationFailed, response["message"]
      when 404
        raise NotFoundError, response
      else
        raise RequestError, response
      end
    end

    private

    def rate_limit_sleep(rate_limit_reset, rate_limit_remaining)
      rate_limit_reset_in = [0, rate_limit_reset - Time.now.to_i].max
      rate_limit_periods = rate_limit_remaining + 1
      wait_time = rate_limit_reset_in / rate_limit_periods.to_f

      sleep(wait_time) if wait_time > 0
    end
  end
end
