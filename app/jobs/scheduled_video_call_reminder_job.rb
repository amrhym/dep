class ScheduledVideoCallReminderJob < ApplicationJob
  queue_as :default

  def perform(scheduled_video_call_id)
    scheduled = ScheduledVideoCall.find_by(id: scheduled_video_call_id)
    return unless scheduled&.scheduled?

    conversation = scheduled.conversation
    account = scheduled.account

    # Build a widget deep link so the user joins inside the chat widget
    base = ENV['FRONTEND_URL'].presence || ENV['CHATWOOT_BASE_URL'].presence || 'http://localhost:3000'
    website_token = conversation.inbox.channel.try(:website_token)
    locale = I18n.locale

    cw_payload = { source_id: conversation.contact_inbox&.source_id, inbox_id: conversation.inbox_id }
    cw_token = Widget::TokenService.new(payload: cw_payload).generate_token rescue nil

    join_url = if website_token.present?
                 if cw_token.present?
                   "#{base}/widget?website_token=#{website_token}&locale=#{locale}&cw_conversation=#{cw_token}&cw_autojoin=1&cw_scheduled_id=#{scheduled.id}"
                 else
                   "#{base}/widget?website_token=#{website_token}&locale=#{locale}&cw_autojoin=1&cw_scheduled_id=#{scheduled.id}"
                 end
               else
                 nil
               end

    ScheduledVideoCallNotifier.new(account: account).send_reminder(
      scheduled: scheduled,
      conversation: conversation,
      join_url: join_url
    )
  end
end