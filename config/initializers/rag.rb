# frozen_string_literal: true
# RAG integration defaults
RAG = {
  base_url: ENV.fetch('RAG_BASE_URL', 'http://rag-service:8000'),
  hmac_key: ENV['RAG_AUTH_HMAC_KEY'],
  timeout: (ENV['RAG_TIMEOUT'] || 15).to_i
}.freeze