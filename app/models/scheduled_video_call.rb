# == Schema Information
#
# Table name: scheduled_video_calls
#
#  id                  :bigint           not null, primary key
#  customer_auth_token :text
#  customer_email      :string
#  customer_phone      :string
#  notify_via          :string           default([]), is an Array
#  scheduled_at        :datetime         not null
#  scheduled_tz        :string
#  status              :string           default("scheduled"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  conversation_id     :bigint           not null
#  meeting_id          :string           not null
#
# Indexes
#
#  index_scheduled_video_calls_on_account_id       (account_id)
#  index_scheduled_video_calls_on_conversation_id  (conversation_id)
#  index_scheduled_video_calls_on_meeting_id       (meeting_id)
#  index_scheduled_video_calls_on_scheduled_at     (scheduled_at)
#
class ScheduledVideoCall < ApplicationRecord
  belongs_to :account
  belongs_to :conversation

  enum status: { scheduled: 'scheduled', sent: 'sent', cancelled: 'cancelled', completed: 'completed' }

  validates :meeting_id, :scheduled_at, presence: true

  def reminder_time
    scheduled_at - 15.minutes
  end
end
