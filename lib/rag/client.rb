# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Rag
  class Client
    def initialize(base_url:, hmac_key: nil, timeout: 15)
      @base_url = base_url.chomp('/')
      @hmac_key = hmac_key
      @timeout = timeout
    end

    def generate(payload)
      res = post_json('/v1/generate', payload)
      body = JSON.parse(res.body) rescue {}
      normalize_generate(body)
    end

    def index(payload)
      res = post_json('/v1/index', payload)
      JSON.parse(res.body) rescue { 'status' => 'unknown' }
    end

    def search(payload)
      res = post_json('/v1/search', payload)
      JSON.parse(res.body) rescue { 'hits' => [] }
    end

    private

    def post_json(path, payload)
      uri = URI.parse(@base_url + path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = @timeout
      http.open_timeout = @timeout
      http.use_ssl = uri.scheme == 'https'

      req = Net::HTTP::Post.new(uri.request_uri)
      req['Content-Type'] = 'application/json'
      add_hmac_headers!(req, payload)
      req.body = JSON.generate(payload)
      http.request(req)
    end

    def add_hmac_headers!(req, payload)
      return unless @hmac_key
      ts = Time.now.to_i.to_s
      mac = OpenSSL::HMAC.hexdigest('SHA256', @hmac_key, ts + JSON.generate(payload))
      req['X-RAG-Timestamp'] = ts
      req['X-RAG-Signature'] = mac
    end

    def normalize_generate(body)
      # Accept various shapes from rag-service; coerce to { output:, stop:, tool_call: }
      if body['tool_call']
        { tool_call: body['tool_call'], output: nil, stop: false }
      else
        output = body['answer'] || body['output'] || body['response'] || ''
        stop = body['stop'] || false
        { output: output, stop: stop }
      end
    end
  end
end