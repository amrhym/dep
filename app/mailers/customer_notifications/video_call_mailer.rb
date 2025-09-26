class CustomerNotifications::VideoCallMailer < ApplicationMailer
  def scheduled
    @conversation = params[:conversation]
    @scheduled = params[:scheduled]
    @join_url = params[:join_url]
    @scheduled_time = @scheduled.scheduled_at
    mail(to: @scheduled.customer_email, subject: 'xCAI - Your video call is scheduled')
  end

  def reminder
    @conversation = params[:conversation]
    @scheduled = params[:scheduled]
    @join_url = params[:join_url]
    @scheduled_time = @scheduled.scheduled_at
    mail(to: @scheduled.customer_email, subject: 'xCAI - Reminder: Your video call starts in 15 minutes')
  end
end