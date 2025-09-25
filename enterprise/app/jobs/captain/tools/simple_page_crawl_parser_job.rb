class Captain::Tools::SimplePageCrawlParserJob < ApplicationJob
  queue_as :low

  def perform(assistant_id:, page_link:)
    assistant = Captain::Assistant.find(assistant_id)
    account = assistant.account

    if limit_exceeded?(account)
      Rails.logger.info("Document limit exceeded for #{assistant_id}")
      return
    end

    crawler = Captain::Tools::SimplePageCrawlService.new(page_link)

    page_title = crawler.page_title || ''
    content = crawler.body_text_content || ''

    document = assistant.documents.find_or_initialize_by(
      external_link: page_link
    )

    document.update!(
      name: page_title[0..254], content: content[0..14_999], status: :available
    )

    # Optional RAG indexing
    if ENV['FEATURE_RAG_ENABLED'] == 'true'
      begin
        require 'rag/client'
        rag = Rag::Client.new(
          base_url: ENV.fetch('RAG_BASE_URL', 'http://rag-service:8000'),
          hmac_key: ENV['RAG_AUTH_HMAC_KEY'],
          timeout: (ENV['RAG_TIMEOUT'] || 15).to_i
        )
        rag.index(
          text: content,
          source: page_link,
          metadata: {
            account_id: account.id,
            assistant_id: assistant.id,
            document_id: document.id,
            name: document.name
          }
        )
      rescue StandardError => e
        Rails.logger.warn("[RAG] Index failed for #{page_link}: #{e.message}")
      end
    end
  rescue StandardError => e
    raise "Failed to parse data: #{page_link} #{e.message}"
  end

  private

  def limit_exceeded?(account)
    limits = account.usage_limits[:captain][:documents]
    limits[:current_available].negative? || limits[:current_available].zero?
  end
end
