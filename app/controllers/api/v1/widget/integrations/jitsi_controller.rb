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

  def schedule
    # Ensure required params for conversation creation to satisfy BaseController
    if conversation.nil?
      params[:message] ||= {}
      params[:message][:referer_url] ||= request.referer
      params[:message][:timestamp] ||= Time.zone.now.to_s
    end
    @conversation ||= conversation || create_conversation

    scheduled_time = Time.zone.parse(permitted_params[:scheduled_at]) rescue nil
    scheduled_time ||= Time.at(permitted_params[:scheduled_at].to_i) rescue nil
    raise ActionController::ParameterMissing, 'scheduled_at' unless scheduled_time

    notify_via = Array.wrap(permitted_params[:notify_via]).presence || ['email']
    customer_email = permitted_params[:customer_email]
    customer_phone = permitted_params[:customer_phone]
    scheduled_tz = permitted_params[:scheduled_tz]

    agent = @web_widget.inbox.account.users.first
    unless agent
      return render json: { error: I18n.t('errors.jitsi.missing_agent', default: 'Agent not available') }, status: :unprocessable_entity
    end

    # Create a Jitsi room and an integration message (same structure as instant call)
    response = jitsi_processor_service.create_a_meeting(agent)
    return render_response(response) if response.is_a?(Hash) && response[:error].present?

    room_name = response.dig(:data, :room_name)
    message_id = response.dig(:data, :id)

    # Create scheduled record storing room name in meeting_id
    scheduled = ScheduledVideoCall.create!(
      account_id: @web_widget.inbox.account_id,
      conversation_id: @conversation.id,
      meeting_id: room_name,
      scheduled_at: scheduled_time,
      scheduled_tz: scheduled_tz,
      notify_via: notify_via,
      customer_email: customer_email,
      customer_phone: customer_phone,
      customer_auth_token: nil
    )

    time_str = scheduled_time.in_time_zone(scheduled_tz || Time.zone.name).strftime('%Y-%m-%d %H:%M %Z')

    # Prefer a widget-based join link that auto-opens the call and chat together
    cw_payload = { source_id: @conversation.contact_inbox&.source_id, inbox_id: @conversation.inbox_id }
    cw_token = Widget::TokenService.new(payload: cw_payload).generate_token rescue nil
    widget_join_link = if cw_token.present?
                         "#{request.base_url}/widget?website_token=#{@web_widget.website_token}&locale=#{I18n.locale}&cw_conversation=#{cw_token}&cw_autojoin=1&cw_scheduled_id=#{scheduled.id}"
                       else
                         "#{request.base_url}/widget?website_token=#{@web_widget.website_token}&locale=#{I18n.locale}&cw_autojoin=1&cw_scheduled_id=#{scheduled.id}"
                       end

    # Update the integration message to reflect it is scheduled
    if message_id && (integration_message = @conversation.messages.find_by(id: message_id))
      integration_message.update(
        content: "\u{1F4C5} Video call scheduled for #{time_str}",
        content_attributes: {
          type: 'jitsi',
          data: {
            room_name: room_name
          }
        }
      )
    else
      # If for some reason message missing, create one
      @conversation.messages.create!(
        account_id: @conversation.account_id,
        inbox_id: @conversation.inbox_id,
        message_type: :outgoing,
        content_type: :integrations,
        content: "\u{1F4C5} Video call scheduled for #{time_str}",
        content_attributes: { type: 'jitsi', data: { room_name: room_name } },
        sender: agent
      )
    end

    # Also create an info message with customer details
    info_message = "\u{1F464} Customer: #{customer_email || 'Not provided'}\n"
    info_message += "\u{1F4F1} Phone: #{customer_phone || 'Not provided'}\n"
    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :outgoing,
      content: info_message
    )

    ScheduledVideoCallNotifier.new(account: @web_widget.inbox.account).send_initial(
      scheduled: scheduled,
      conversation: @conversation,
      join_url: widget_join_link
    )

    if (scheduled_time - 15.minutes) > Time.current
      ScheduledVideoCallReminderJob.set(wait_until: scheduled_time - 15.minutes).perform_later(scheduled.id)
    end

    render json: { ok: true, scheduled_id: scheduled.id, scheduled_at: scheduled_time, widget_join_link: widget_join_link }
  end

  def join
    # Ensure a conversation exists for the current visitor
    if conversation.nil?
      params[:message] ||= {}
      params[:message][:referer_url] ||= request.referer
      params[:message][:timestamp] ||= Time.zone.now.to_s
    end
    @conversation ||= conversation || create_conversation

    # Resolve room name either from scheduled record or direct param
    room_name = nil
    if permitted_params[:scheduled_id].present?
      scheduled = ScheduledVideoCall.find_by(id: permitted_params[:scheduled_id])
      return render json: { error: 'Resource could not be found' }, status: :not_found unless scheduled
      if scheduled.account_id != @web_widget.inbox.account_id
        return render json: { error: 'Resource could not be found' }, status: :not_found
      end
      room_name = scheduled.meeting_id
    end
    room_name ||= permitted_params[:room_name]

    return render json: { error: 'Missing room_name or scheduled_id' }, status: :unprocessable_entity if room_name.blank?

    response = jitsi_processor_service.add_participant_to_meeting(room_name)
    return render_response(response) if response.is_a?(Hash) && response[:error].present?

    render json: { room_name: room_name, meeting_url: response[:meeting_url] }, status: :ok
  end

  def add_participant_to_meeting
    if @message.content_type != 'integrations' || @message.content_attributes['type'] != 'jitsi'
      return render json: {
        error: I18n.t('errors.jitsi.invalid_message_type')
      }, status: :unprocessable_entity
    end

    room_name = @message.content_attributes['data']['room_name']

    response = jitsi_processor_service.add_participant_to_meeting(room_name)
    if response.is_a?(Hash) && response[:error].present?
      return render_response(response)
    end
    render json: response.merge(room_name: room_name), status: :ok
  end

  private

  def render_response(response)
    render json: response, status: response[:error].blank? ? :ok : :unprocessable_entity
  end

  def jitsi_processor_service
    Integrations::JitsiService.new(account: @web_widget.inbox.account, conversation: @conversation || conversation)
  end

  def permitted_params
    params.permit(
      :website_token,
      :conversation_id,
      :message_id,
      :room_name,
      :scheduled_id,
      :scheduled_at,
      :scheduled_tz,
      :customer_email,
      :customer_phone,
      { notify_via: [] },
      message: [:referer_url, :timestamp]
    )
  end

  def set_message
    @message = @web_widget.inbox.messages.find(permitted_params[:message_id])
    @conversation = @message.conversation
  end
end