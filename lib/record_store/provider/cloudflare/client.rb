require 'net/http'

module Cloudflare
  class Client
    attr_reader :config

    def initialize(config = Cloudflare::Configuration.new)
      @config = config
    end

    def get(endpoint, params = {})
      uri = build_uri(endpoint, params)

      response = request(:get, uri)
      Cloudflare::Response.new(response)
    end

    def post(endpoint, body = nil)
      uri = build_uri(endpoint)

      response = request(:post, uri, body: body)
      Cloudflare::Response.new(response)
    end

    def put(endpoint, body = nil)
      uri = build_uri(endpoint)

      response = request(:put, uri, body: body)
      Cloudflare::Response.new(response)
    end

    def patch(endpoint, body = nil)
      uri = build_uri(endpoint)

      response = request(:patch, uri, body: body)
      Cloudflare::Response.new(response)
    end

    def delete(endpoint)
      uri = build_uri(endpoint)

      response = request(:delete, uri)
      Cloudflare::Response.new(response)
    end

    def request(method, uri, body: nil)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |conn|
        request = case method
        when :get
          Net::HTTP::Get.new(uri)
        when :post
          request = Net::HTTP::Post.new(uri)
          request.body = body.to_json if body
          request
        when :put
          request = Net::HTTP::Put.new(uri)
          request.body = body.to_json if body
          request
        when :patch
          request = Net::HTTP::Patch.new(uri)
          request.body = body.to_json if body
          request
        when :delete
          Net::HTTP::Delete.new(uri)
        end

        cloudflare_headers.each { |k, v| request[k] = v }

        begin
          response = conn.request(request)
        rescue StandardError => e
          raise "HTTP error: #{e.message}"
        end
        response
      end
    end

    private

    def cloudflare_headers
      @cloudflare_headers ||= {
        'User-Agent' => "Ruby",
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{config.api_token}"
      }
    end

    def build_uri(endpoint, params = {})
      URI::HTTPS.build(
        host: config.api_host,
        path: endpoint.chomp('/'),
        query: URI.encode_www_form(params),
      )
    end
  end
end
