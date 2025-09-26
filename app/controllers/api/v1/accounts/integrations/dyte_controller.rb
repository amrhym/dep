class Api::V1::Accounts::Integrations::DyteController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation, only: [:create_a_meeting]
  before_action :fetch_message, only: [:add_participant_to_meeting]
  before_action :authorize_request

  def create_a_meeting
    render_response(dyte_processor_service.create_a_meeting(Current.user))
  end

  def add_participant_to_meeting
    if @message.content_type != 'integrations'
      return render json: {
        error: I18n.t('errors.dyte.invalid_message_type')
      }, status: :unprocessable_entity
    end

    render_response(
      dyte_processor_service.add_participant_to_meeting(@message.content_attributes['data']['meeting_id'], Current.user)
    )
  end

  def reschedule
    authorize_request
    scheduled = ScheduledVideoCall.find_by!(conversation_id: @conversation.id)

    scheduled_time = Time.zone.parse(permitted_params[:scheduled_at]) rescue nil
    scheduled_time ||= Time.at(permitted_params[:scheduled_at].to_i) rescue nil
    raise ActionController::ParameterMissing, 'scheduled_at' unless scheduled_time

    scheduled.update!(
      scheduled_at: scheduled_time,
      scheduled_tz: permitted_params[:scheduled_tz].presence || scheduled.scheduled_tz,
      notify_via: Array.wrap(permitted_params[:notify_via]).presence || scheduled.notify_via,
      customer_email: permitted_params[:customer_email].presence || scheduled.customer_email,
      customer_phone: permitted_params[:customer_phone].presence || scheduled.customer_phone
    )

    if (scheduled_time - 15.minutes) > Time.current
      ScheduledVideoCallReminderJob.set(wait_until: scheduled_time - 15.minutes).perform_later(scheduled.id)
    end

    join_url = scheduled.customer_auth_token.present? ? "https://app.dyte.io/v2/meeting?authToken=#{scheduled.customer_auth_token}" : nil

    # Create a message in the conversation with the updated schedule and join link
    time_str = scheduled_time.in_time_zone(scheduled.scheduled_tz || Time.zone.name).strftime('%Y-%m-%d %H:%M %Z')
    message_content = "🔄 Video call rescheduled to #{time_str}\n\n"
    if join_url.present?
      message_content += "👤 Customer join link:\n#{join_url}\n\n"
    end

    # Generate agent dashboard link to this conversation
    agent_conversation_url = "#{request.protocol}#{request.host_with_port}/app/accounts/#{@conversation.account_id}/conversations/#{@conversation.display_id}"
    message_content += "👨‍💼 For agents:\n"
    message_content += "1. Open conversation: #{agent_conversation_url}\n"
    message_content += "2. Click the 'Start Video Call' button when ready to join\n\n"
    message_content += "Note: Agent must use the 'Start Video Call' button in the conversation toolbar to properly join the meeting."

    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :activity,
      content: message_content,
      sender: Current.user
    )

    ScheduledVideoCallNotifier.new(account: Current.account).send_initial(
      scheduled: scheduled,
      conversation: @conversation,
      join_url: join_url
    )

    render json: { ok: true, scheduled_at: scheduled_time }
  end

  private

  def authorize_request
    authorize @conversation.inbox, :show?
  end

  def render_response(response)
    render json: response, status: response[:error].blank? ? :ok : :unprocessable_entity
  end

  def dyte_processor_service
    Integrations::Dyte::ProcessorService.new(account: Current.account, conversation: @conversation)
  end

  def permitted_params
    params.permit(:conversation_id, :message_id, :scheduled_at, :scheduled_tz, :customer_email, :customer_phone, notify_via: [])
  end

  def fetch_conversation
    @conversation = Current.account.conversations.find_by!(display_id: permitted_params[:conversation_id])
  end

  def fetch_message
    @message = Current.account.messages.find(permitted_params[:message_id])
    @conversation = @message.conversation
  end
end
