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

    if channels.include?('whatsapp') && twilio_whatsapp_configured? && scheduled.customer_phone.present?
      send_twilio_whatsapp(to: scheduled.customer_phone, body: compose_text(scheduled, join_url))
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
end