class Api::V1::Widget::Integrations::DyteController < Api::V1::Widget::BaseController
  before_action :set_message, only: [:add_participant_to_meeting]

  def create_a_meeting
    # Pick an agent to attribute the message/title to; fallback to any account user
    agent = @web_widget.inbox.account.users.first

    unless agent
      return render json: { error: I18n.t('errors.dyte.missing_agent', default: 'Agent not available') }, status: :unprocessable_entity
    end

    @conversation ||= conversation
    unless @conversation
      return render json: { error: I18n.t('errors.dyte.missing_conversation', default: 'Conversation not found') }, status: :unprocessable_entity
    end

    response = dyte_processor_service.create_a_meeting(agent)
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
    response = dyte_processor_service.create_meeting_only(agent)
    if response.is_a?(Hash) && response[:error].present?
      return render json: response, status: :unprocessable_entity
    end

    meeting_id = response['id'] || response[:id]

    auth_resp = dyte_processor_service.add_participant_to_meeting(meeting_id, @conversation.contact)
    customer_auth_token = nil
    if auth_resp.is_a?(Hash)
      customer_auth_token = auth_resp[:auth_token] || auth_resp['auth_token'] || auth_resp[:token] || auth_resp['token']
      if customer_auth_token.blank?
        # Some Dyte responses nest the token under authResponse.authToken
        nested = auth_resp[:authResponse] || auth_resp['authResponse']
        customer_auth_token = nested[:authToken] || nested['authToken'] if nested.is_a?(Hash)
      end
    end

    scheduled = ScheduledVideoCall.create!(
      account_id: @web_widget.inbox.account_id,
      conversation_id: @conversation.id,
      meeting_id: meeting_id,
      scheduled_at: scheduled_time,
      scheduled_tz: scheduled_tz,
      notify_via: notify_via,
      customer_email: customer_email,
      customer_phone: customer_phone,
      customer_auth_token: customer_auth_token
    )

    time_str = scheduled_time.in_time_zone(scheduled_tz || Time.zone.name).strftime('%Y-%m-%d %H:%M %Z')
    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :outgoing,
      content: "Video call scheduled for #{time_str}"
    )

    # Prefer a widget-based join link that auto-opens the call and chat together
    cw_payload = { source_id: @conversation.contact_inbox&.source_id, inbox_id: @conversation.inbox_id }
    cw_token = Widget::TokenService.new(payload: cw_payload).generate_token rescue nil
    widget_join_link = if cw_token.present?
                         "#{request.base_url}/widget?website_token=#{@web_widget.website_token}&locale=#{I18n.locale}&cw_conversation=#{cw_token}&cw_autojoin=1&cw_scheduled_id=#{scheduled.id}"
                       else
                         "#{request.base_url}/widget?website_token=#{@web_widget.website_token}&locale=#{I18n.locale}&cw_autojoin=1&cw_scheduled_id=#{scheduled.id}"
                       end

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

    # Resolve meeting id either from scheduled record or direct param
    meeting_id = permitted_params[:meeting_id]
    if permitted_params[:scheduled_id].present?
      scheduled = ScheduledVideoCall.find_by(id: permitted_params[:scheduled_id])
      return render json: { error: 'Resource could not be found' }, status: :not_found unless scheduled
      # Ensure the scheduled record belongs to the same account
      if scheduled.account_id != @web_widget.inbox.account_id
        return render json: { error: 'Resource could not be found' }, status: :not_found
      end
      meeting_id ||= scheduled.meeting_id
    end

    return render json: { error: 'Missing meeting_id or scheduled_id' }, status: :unprocessable_entity if meeting_id.blank?

    response = dyte_processor_service.add_participant_to_meeting(meeting_id, @conversation.contact)

    if response.is_a?(Hash) && response[:error].blank?
      token = response[:auth_token] || response['auth_token'] || response[:token] || response['token']
      if token.blank?
        nested = response[:authResponse] || response['authResponse']
        token = nested[:authToken] || nested['authToken'] if nested.is_a?(Hash)
      end
      return render json: { token: token, meeting_id: meeting_id }
    end

    render_response(response)
  end

  def add_participant_to_meeting
    if @message.content_type != 'integrations'
      return render json: {
        error: I18n.t('errors.dyte.invalid_message_type')
      }, status: :unprocessable_entity
    end

    response = dyte_processor_service.add_participant_to_meeting(
      @message.content_attributes['data']['meeting_id'],
      @conversation.contact
    )
    render_response(response)
  end

  private

  def render_response(response)
    render json: response, status: response[:error].blank? ? :ok : :unprocessable_entity
  end

  def dyte_processor_service
    Integrations::Dyte::ProcessorService.new(account: @web_widget.inbox.account, conversation: @conversation || conversation)
  end

  def set_message
    @message = @web_widget.inbox.messages.find(permitted_params[:message_id])
    @conversation = @message.conversation
  end

  def permitted_params
    params.permit(:website_token, :message_id, :scheduled_at, :scheduled_tz, :customer_email, :customer_phone, :meeting_id, :scheduled_id, { notify_via: [] }, message: [:referer_url, :timestamp])
  end
end
