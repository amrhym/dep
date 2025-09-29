class Api::V1::Widget::Integrations::JitsiController < Api::V1::Widget::BaseController
  before_action :set_message, only: [:add_participant_to_meeting]
  
  def create_a_meeting
    # Pick an agent to attribute the message/title to; fallback to any account user
    agent = @web_widget.inbox.account.users.first

    unless agent
      return render json: { error: I18n.t('errors.jitsi.missing_agent', default: 'Agent not available') }, status: :unprocessable_entity
    end

    @conversation ||= conversation
    unless @conversation
      return render json: { error: I18n.t('errors.jitsi.missing_conversation', default: 'Conversation not found') }, status: :unprocessable_entity
    end

    response = jitsi_processor_service.create_a_meeting(agent)
    render_response(response)
  end

  def add_participant_to_meeting
    if @message.content_type != 'integrations' || @message.content_attributes['type'] != 'jitsi'
      return render json: {
        error: I18n.t('errors.jitsi.invalid_message_type')
      }, status: :unprocessable_entity
    end

    room_name = @message.content_attributes['data']['room_name']

    render_response(
      jitsi_processor_service.add_participant_to_meeting(room_name)
    )
  end

  private

  def render_response(response)
    render json: response, status: response[:error].blank? ? :ok : :unprocessable_entity
  end

  def jitsi_processor_service
    Integrations::JitsiService.new(account: @web_widget.inbox.account, conversation: @conversation || conversation)
  end

  def permitted_params
    params.permit(:website_token, :conversation_id, :message_id, message: [:referer_url, :timestamp])
  end

  def set_message
    @message = @web_widget.inbox.messages.find(permitted_params[:message_id])
    @conversation = @message.conversation
  end
end