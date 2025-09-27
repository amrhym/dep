class Api::V1::Accounts::Integrations::JitsiController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation, only: [:create_a_meeting]
  before_action :fetch_message, only: [:add_participant_to_meeting]
  before_action :authorize_request

  def create_a_meeting
    render_response(jitsi_processor_service.create_a_meeting(Current.user))
  end

  def add_participant_to_meeting
    if @message.content_type != 'integrations' || @message.content_attributes['type'] != 'jitsi'
      return render json: {
        error: I18n.t('errors.jitsi.invalid_message_type')
      }, status: :unprocessable_entity
    end

    room_name = @message.content_attributes['data']['room_name']
    Current.user.is_a?(User) # agents are moderators

    render_response(
      jitsi_processor_service.add_participant_to_meeting(room_name)
    )
  end

  private

  def authorize_request
    authorize @conversation.inbox, :show?
  end

  def render_response(response)
    render json: response, status: response[:error].blank? ? :ok : :unprocessable_entity
  end

  def jitsi_processor_service
    Integrations::Jitsi::ProcessorService.new(account: Current.account, conversation: @conversation)
  end

  def permitted_params
    params.permit(:conversation_id, :message_id)
  end

  def fetch_conversation
    @conversation = Current.account.conversations.find_by!(display_id: permitted_params[:conversation_id])
  end

  def fetch_message
    @message = Current.account.messages.find(permitted_params[:message_id])
    @conversation = @message.conversation
  end
end
