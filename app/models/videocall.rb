# == Schema Information
#
# Table name: videocalls
#
#  id              :bigint           not null, primary key
#  contact_name    :string
#  name            :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_user_id :bigint           not null
#  conversation_id :bigint           not null
#
# Indexes
#
#  index_videocalls_on_account_user_id  (account_user_id)
#  index_videocalls_on_conversation_id  (conversation_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_user_id => account_users.id)
#  fk_rails_...  (conversation_id => conversations.id)
#
class Videocall < ApplicationRecord
  belongs_to :conversation
  belongs_to :account_user
end
