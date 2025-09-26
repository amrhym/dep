class ScheduledVideoCall < ApplicationRecord
  belongs_to :account
  belongs_to :conversation

  enum status: { scheduled: 'scheduled', sent: 'sent', cancelled: 'cancelled', completed: 'completed' }

  validates :meeting_id, :scheduled_at, presence: true

  def reminder_time
    scheduled_at - 15.minutes
  end
end