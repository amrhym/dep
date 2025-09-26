class ScheduledVideoCallNotifier
  def initialize(account:)
    @account = account
  end

  def send_initial(scheduled:, conversation:, join_url:)
    notify(scheduled: scheduled, conversation: conversation, join_url: join_url, reminder: false)
  end

  def send_reminder(scheduled:, conversation:, join_url:)
    notify(scheduled: scheduled, conversation: conversation, join_url: join_url, reminder: true)
  end

  private

  def notify(scheduled:, conversation:, join_url:, reminder:)
    channels = Array.wrap(scheduled.notify_via)

    if channels.include?('email') && scheduled.customer_email.present?
      mailer_method = reminder ? :reminder : :scheduled
      CustomerNotifications::VideoCallMailer.with(
        conversation: conversation,
        scheduled: scheduled,
        join_url: join_url
      ).public_send(mailer_method)&.deliver_later
    end

    if channels.include?('sms') && twilio_configured? && scheduled.customer_phone.present?
      send_twilio_sms(to: scheduled.customer_phone, body: compose_text(scheduled, join_url))
    end

    if channels.include?('whatsapp') && scheduled.customer_phone.present?
      # Try to send via Meta WhatsApp if available
      if send_meta_whatsapp(conversation: conversation, to: scheduled.customer_phone, body: compose_text(scheduled, join_url))
        Rails.logger.info "Sent WhatsApp reminder via Meta API to #{scheduled.customer_phone}"
      elsif twilio_whatsapp_configured?
        # Fallback to Twilio if Meta WhatsApp is not available
        send_twilio_whatsapp(to: scheduled.customer_phone, body: compose_text(scheduled, join_url))
      end
    end
  end

  def compose_text(scheduled, join_url)
    time_str = scheduled.scheduled_at.in_time_zone(scheduled.scheduled_tz || Time.zone.name).strftime('%Y-%m-%d %H:%M %Z')
    base = "Your video call is scheduled at #{time_str}."
    join_url.present? ? "#{base} Join: #{join_url}" : base
  end

  def twilio_configured?
    ENV['TWILIO_ACCOUNT_SID'].present? && ENV['TWILIO_AUTH_TOKEN'].present? && ENV['TWILIO_FROM'].present?
  end

  def twilio_whatsapp_configured?
    ENV['TWILIO_ACCOUNT_SID'].present? && ENV['TWILIO_AUTH_TOKEN'].present? && ENV['TWILIO_WHATSAPP_FROM'].present?
  end

  def send_twilio_sms(to:, body:)
    client = twilio_client
    client.messages.create(from: ENV['TWILIO_FROM'], to: to, body: body)
  end

  def send_twilio_whatsapp(to:, body:)
    client = twilio_client
    from = "whatsapp:#{ENV['TWILIO_WHATSAPP_FROM']}"
    to = to.start_with?('whatsapp:') ? to : "whatsapp:#{to}"
    client.messages.create(from: from, to: to, body: body)
  end

  def twilio_client
    @twilio_client ||= Twilio::REST::Client.new(ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN'])
  end

  def send_meta_whatsapp(conversation:, to:, body:)
    # Try to find a WhatsApp channel in the account
    whatsapp_inbox = @account.inboxes.joins(:channel).where(channel: { type: 'Channel::Whatsapp' }).first
    return false unless whatsapp_inbox

    whatsapp_channel = whatsapp_inbox.channel

    # Format phone number for WhatsApp (remove any formatting)
    formatted_phone = to.gsub(/[^\d]/, '')
    formatted_phone = formatted_phone.start_with?('+') ? formatted_phone : "+#{formatted_phone}"

    begin
      # Send message via WhatsApp channel
      if conversation && conversation.contact_inbox&.inbox&.channel.is_a?(Channel::Whatsapp)
        # If conversation already has a WhatsApp contact, use it directly
        message = conversation.messages.create!(
          content: body,
          message_type: :outgoing,
          private: false,
          sender: User.first, # You may want to use a system user here
          inbox: conversation.inbox,
          account: @account
        )
        Whatsapp::SendOnWhatsappService.new(message: message).perform
      else
        # Send as a template or session message via the WhatsApp provider
        whatsapp_channel.send_message(formatted_phone, { text: body })
      end
      true
    rescue => e
      Rails.logger.error "Failed to send WhatsApp message via Meta API: #{e.message}"
      false
    end
  end
end