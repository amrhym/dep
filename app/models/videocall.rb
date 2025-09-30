class Videocall < ApplicationRecord
  belongs_to :conversation
  belongs_to :account_user
end
