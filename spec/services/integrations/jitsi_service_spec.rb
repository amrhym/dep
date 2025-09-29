require 'rails_helper'

describe Integrations::JitsiService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:hook) { create(:integrations_hook, account: account, app_id: 'jitsi', settings: { 'app_id' => 'test', 'secret_key' => 'test' }) }

  before do
    # Mock the jitsi client to avoid external dependencies
    allow_any_instance_of(Jitsi).to receive(:build_meeting_url).and_return('https://jitsi.xdec.io/test-room')
  end

  describe '#create_a_meeting' do
    it 'creates an integration message with jitsi room' do
      hook # Ensure hook is created
      service = described_class.new(account: account, conversation: conversation)
      result = service.create_a_meeting(agent)

      expect(result[:success]).to be true
      room = result.dig(:data, :room_name)
      expect(room).to match(/^chatwoot-#{conversation.id}-[a-f0-9]{12}$/)

      message = conversation.messages.last
      expect(message.content_type).to eq('integrations')
      expect(message.content_attributes['type']).to eq('jitsi')
      expect(message.content_attributes['data']['room_name']).to eq(room)
      expect(message.sender).to eq(agent)
    end
  end

  describe '#add_participant_to_meeting' do
    it 'returns meeting URL for a room' do
      hook # Ensure hook is created
      service = described_class.new(account: account, conversation: conversation)
      room_name = 'test-room'

      result = service.add_participant_to_meeting(room_name)

      expect(result[:meeting_url]).to eq('https://jitsi.xdec.io/test-room')
    end
  end
end
