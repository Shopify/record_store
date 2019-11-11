require 'net/http'

# Patch the method which retrieves headers for API rate limit dynamically
module NS1::Transport
  class NetHttp
    def process_response(response)
      sleep(response.to_hash["x-ratelimit-period"].first.to_i /
        [1, response.to_hash["x-ratelimit-remaining"].first.to_i].max.to_f)

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
