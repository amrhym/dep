class Integrations::Jitsi::ProcessorService
  pattr_initialize [:account!, :conversation!]

  def create_a_meeting(agent)
    room_name = generate_room_name
    title = I18n.t('integration_apps.jitsi.meeting_name', agent_name: agent.available_name)

    meeting_data = {
      room_name: room_name,
      created_by: agent.id,
      created_at: Time.current.iso8601
    }

    message = create_a_jitsi_integration_message(meeting_data, title, agent)
    message.push_event_data

    { success: true, data: meeting_data }
  rescue StandardError => e
    { error: { message: e.message }, error_code: 500 }
  end

  def add_participant_to_meeting(room_name) # , user, is_moderator = false # Uncomment user and is_moderator when JWT is to be used
    # jwt_token = jitsi_client.generate_jwt_token(
    #   room_name,
    #   user.id,
    #   user.name,
    #   avatar_url(user),
    #   is_moderator
    # )

    meeting_url = jitsi_client.build_meeting_url(room_name) #, jwt_token # Uncomment jwt_token when JWT is to be used

    {  meeting_url: meeting_url } #, jwt_token: jwt_token } # Uncomment jwt_token when JWT is to be used
  rescue StandardError => e
    { error: { message: e.message }, error_code: 500 }
  end

  private

  def generate_room_name
    "DEP-#{conversation.account_id}-#{conversation.id}-#{SecureRandom.hex(4)}"
  end

  def create_a_jitsi_integration_message(meeting_data, title, agent)
    @conversation.messages.create!(
      {
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :outgoing,
        content_type: :integrations,
        content: title,
        content_attributes: {
          type: 'jitsi',
          data: meeting_data
        },
        sender: agent
      }
    )
  end

  def avatar_url(user)
    return user.avatar_url if user.avatar_url.present?

    "#{ENV.fetch('FRONTEND_URL', nil)}/integrations/slack/user.png"
  end

  def jitsi_hook
    @jitsi_hook ||= account.hooks.find_by!(app_id: 'jitsi')
  end

  def jitsi_client
    credentials = jitsi_hook.settings
    @jitsi_client ||= Jitsi.new(
      credentials['app_id'],
      credentials['secret_key'],
      credentials['base_url']
    )
  end
end
