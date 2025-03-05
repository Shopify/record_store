require 'net/http'
require_relative 'response'

module Cloudflare
  class Client
    API_FQDN = 'api.cloudflare.com'.freeze

    def initialize(api_token)
      @api_token = api_token
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
          if response.is_a?(Net::HTTPRedirection) || response.is_a?(Net::HTTPServerError)
            response.error!
          end
          response
        rescue Net::HTTPRetriableError, Net::HTTPServerError => e
          raise RecordStore::Provider::RetriableError, e.message
        rescue Net::HTTPError => e
          raise RecordStore::Provider::Error, e.message
        end
      end
    end

    private

    def cloudflare_headers
      @cloudflare_headers ||= {
        'User-Agent' => "Ruby",
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@api_token}"
      }
    end

    def build_uri(endpoint, params = {})
      URI::HTTPS.build(
        host: API_FQDN,
        path: endpoint.chomp('/'),
        query: URI.encode_www_form(params),
      )
    end
  end
end
