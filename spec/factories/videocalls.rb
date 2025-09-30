FactoryBot.define do
  factory :videocall do
    name { 'MyString' }
    contact_name { 'MyString' }
    conversation { nil }
    account_user { nil }
  end
end
