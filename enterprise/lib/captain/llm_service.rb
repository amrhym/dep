require 'openai'

class Captain::LlmService
  def initialize(config)
    @client = OpenAI::Client.new(
      access_token: config[:api_key],
      log_errors: Rails.env.development?
    )
    @logger = Rails.logger
    @rag_client = begin
      require 'rag/client'
      Rag::Client.new(
        base_url: ENV.fetch('RAG_BASE_URL', 'http://rag-service:8000'),
        hmac_key: ENV['RAG_AUTH_HMAC_KEY'],
        timeout: (ENV['RAG_TIMEOUT'] || 15).to_i
      )
    rescue LoadError
      nil
    end
  end

  def call(messages, functions = [])
    if ENV['FEATURE_RAG_ENABLED'] == 'true' && @rag_client
      begin
        return call_via_rag(messages, functions)
      rescue StandardError => e
        @logger.warn("RAG path failed, falling back to OpenAI: #{e.message}")
      end
    end

    openai_params = {
      model: 'gpt-4o',
      response_format: { type: 'json_object' },
      messages: messages
    }
    openai_params[:tools] = functions if functions.any?

    response = @client.chat(parameters: openai_params)
    handle_response(response)
  rescue StandardError => e
    handle_error(e)
  end

  private

  def call_via_rag(messages, functions)
    payload = {
      messages: messages,
      retrieval: { top_k: (ENV['RAG_TOP_K'] || 6).to_i },
      assistant_config: {},
      tools: functions
    }
    resp = @rag_client.generate(payload)
    # Expecting resp to be a hash with keys: output, stop, tool_call (optional)
    if resp[:tool_call]
      { tool_call: resp[:tool_call], output: nil, stop: false }
    else
      { output: resp[:output].to_s, stop: resp[:stop] || false }
    end
  end

  def handle_response(response)
    if response['choices'][0]['message']['tool_calls']
      handle_tool_calls(response)
    else
      handle_direct_response(response)
    end
  end

  def handle_tool_calls(response)
    tool_call = response['choices'][0]['message']['tool_calls'][0]
    {
      tool_call: tool_call,
      output: nil,
      stop: false
    }
  end

  def handle_direct_response(response)
    content = response.dig('choices', 0, 'message', 'content').strip
    parsed = JSON.parse(content)

    {
      output: parsed['result'] || parsed['thought_process'],
      stop: parsed['stop'] || false
    }
  rescue JSON::ParserError => e
    handle_error(e, content)
  end

  def handle_error(error, content = nil)
    @logger.error("LLM call failed: #{error.message}")
    @logger.error(error.backtrace.join("\n"))
    @logger.error("Content: #{content}") if content

    { output: 'Error occurred, retrying', stop: false }
  end
end
