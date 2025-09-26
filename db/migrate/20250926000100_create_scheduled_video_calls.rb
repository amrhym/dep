class CreateScheduledVideoCalls < ActiveRecord::Migration[7.1]
  def change
    create_table :scheduled_video_calls do |t|
      t.bigint :account_id, null: false
      t.bigint :conversation_id, null: false
      t.string :meeting_id, null: false
      t.datetime :scheduled_at, null: false
      t.string :scheduled_tz, null: true
      t.string :status, null: false, default: 'scheduled'
      t.string :notify_via, array: true, default: []
      t.string :customer_email
      t.string :customer_phone
      t.string :customer_auth_token
      t.timestamps
    end

    add_index :scheduled_video_calls, :account_id
    add_index :scheduled_video_calls, :conversation_id
    add_index :scheduled_video_calls, :meeting_id
    add_index :scheduled_video_calls, :scheduled_at
  end
end