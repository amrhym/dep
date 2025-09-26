class ChangeCustomerAuthTokenType < ActiveRecord::Migration[7.1]
  def change
    change_column :scheduled_video_calls, :customer_auth_token, :text
  end
end