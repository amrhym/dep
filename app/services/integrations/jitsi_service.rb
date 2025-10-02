class Integrations::JitsiService
  pattr_initialize [:account!, :conversation!]

  def create_a_meeting(agent)
    room_name = generate_room_name(agent)
    title = I18n.t('integration_apps.jitsi.meeting_name', agent_name: agent.available_name)

    meeting_data = {
      room_name: room_name,
      created_by: agent.id,
      created_at: Time.current.iso8601
    }
    # Try to generate a moderator token and meeting URL for the creating agent
    begin
      jwt_token = jitsi_client.generate_jwt_token(
        room_name,
        agent.respond_to?(:id) ? agent.id : 'agent',
        agent.respond_to?(:available_name) ? agent.available_name : 'Agent',
        avatar_url(agent),
        true,
        (agent.respond_to?(:email) ? agent.email : nil)
      )

    rescue StandardError
      jwt_token = nil
    end

    meeting_url = jitsi_client.build_meeting_url(room_name, jwt_token)
    meeting_data[:meeting_url] = meeting_url
    meeting_data[:jwt_token] = jwt_token if jwt_token.present?

    message = create_a_jitsi_integration_message(meeting_data, title, agent)
    message.push_event_data

    # Create video call record
    create_video_call_record(agent, room_name)

    # Frontend expects the integration message id in response.data.id
    meeting_data[:id] = message.id
    { success: true, data: meeting_data }
  rescue StandardError => e
    { error: { message: e.message }, error_code: 500 }
  end

  def add_participant_to_meeting(room_name, user = nil, is_moderator = false)
    jwt_token = nil

    if user.present?
      user_id, user_name = extract_user_info(user)
      begin
        jwt_token = jitsi_client.generate_jwt_token(
          room_name,
          user_id || 'guest',
          user_name || 'Guest',
          avatar_url(user),
          is_moderator,
          (user.respond_to?(:email) ? user.email : nil)
        )
      rescue StandardError
        # If JWT config is missing or invalid, silently fallback to unauthenticated URL
        jwt_token = nil
      end
    else
      # Generate a guest token for the contact if JWT is configured
      contact = begin
        conversation.contact
      rescue StandardError
        nil
      end
      if contact.present?
        begin
          guest_id = contact.respond_to?(:id) ? contact.id : SecureRandom.uuid
          guest_name = contact.respond_to?(:name) ? (contact.name.presence || 'Guest') : 'Guest'
          guest_avatar = if contact.respond_to?(:avatar_url) && contact.avatar_url.present?
                           contact.avatar_url
                         else
                           "#{ENV.fetch('FRONTEND_URL', nil)}/integrations/slack/user.png"
                         end
          jwt_token = jitsi_client.generate_jwt_token(
            room_name,
            guest_id,
            guest_name,
            guest_avatar,
            false,
            (contact.respond_to?(:email) ? contact.email : nil)
          )
        rescue StandardError
          jwt_token = nil
        end
      end
    end

    meeting_url = jitsi_client.build_meeting_url(room_name, jwt_token)

    { meeting_url: meeting_url, jwt_token: jwt_token }
  rescue StandardError => e
    { error: { message: e.message }, error_code: 500 }
  end

  private

  def generate_room_name(agent)
    contact_name = conversation.contact.name&.parameterize || 'guest'
    agent_name = agent.available_name&.parameterize || 'agent'

    "#{conversation.id}___#{ENV.fetch('APP_NAME', 'DEP')}-#{contact_name}-#{agent_name}-#{SecureRandom.hex(6)}"
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
        sender: nil
      }
    )
  end

  def create_video_call_record(agent, room_name)
    # Find the AccountUser record for this agent in the current account
    account_user = account.account_users.find_by(user: agent)

    return unless account_user # Skip if agent is not part of this account

    contact_name = conversation.contact.name || 'Unknown'

    Videocall.create!(
      name: room_name,
      contact_name: contact_name,
      conversation: conversation,
      account_user: account_user
    )
  end

  def avatar_url(user)
    return user.avatar_url if user.respond_to?(:avatar_url) && user.avatar_url.present?

    "#{ENV.fetch('FRONTEND_URL', nil)}/integrations/slack/user.png"
  end

  def extract_user_info(user)
    name = if user.respond_to?(:available_name)
             user.available_name
           elsif user.respond_to?(:name)
             user.name
           end
    [user.respond_to?(:id) ? user.id : nil, name]
  end

  def jitsi_hook
    @jitsi_hook ||= account.hooks.find_by(app_id: 'jitsi')
  end

  def jitsi_client
    if jitsi_hook&.settings
      credentials = jitsi_hook.settings
      @jitsi_client ||= Jitsi.new(
        credentials['app_id'].presence || ENV.fetch('JWT_APP_ID', ENV.fetch('JITSI_APP_ID', nil)),
        credentials['secret_key'].presence || ENV.fetch('JWT_APP_SECRET', ENV.fetch('JITSI_SECRET_KEY', nil))
      )
    else
      # Use ENV fallback when no hook is configured
      @jitsi_client ||= Jitsi.new(
        ENV.fetch('JWT_APP_ID', ENV.fetch('JITSI_APP_ID', nil)),
        ENV.fetch('JWT_APP_SECRET', ENV.fetch('JITSI_SECRET_KEY', nil))
      )
    end
  end
end
