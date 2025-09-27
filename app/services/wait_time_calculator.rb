class WaitTimeCalculator
  def initialize(inbox)
    @inbox = inbox
  end

  def calculate
    queued_conversations = unassigned_conversations_count
    available_agents = online_agents_count

    return no_agents_response(queued_conversations) if available_agents == 0

    calculate_wait_time_with_agents(queued_conversations, available_agents)
  end

  def position_in_queue(conversation)
    return nil if conversation.assignee_id.present?

    @inbox.conversations
          .where(status: :open, assignee_id: nil)
          .where('created_at < ?', conversation.created_at)
          .count + 1
  end

  private

  def unassigned_conversations_count
    @inbox.conversations
          .where(status: :open, assignee_id: nil)
          .count
  end

  def online_agents_count
    @inbox.members
          .joins('LEFT JOIN account_users ON account_users.user_id = inbox_members.user_id')
          .joins('LEFT JOIN users ON users.id = inbox_members.user_id')
          .where(account_users: {
                   account_id: @inbox.account_id,
                   availability: [User::AVAILABILITY_STATUS[:online], User::AVAILABILITY_STATUS[:busy]]
                 })
          .count
  end

  def no_agents_response(queue_size)
    {
      wait_time_minutes: nil,
      message: "No agents currently online. We'll notify you when available.",
      position: queue_size,
      status: 'offline'
    }
  end

  def calculate_wait_time_with_agents(queued_conversations, available_agents)
    avg_handle_time = calculate_average_handle_time
    conversations_per_agent = queued_conversations.to_f / available_agents
    estimated_minutes = (conversations_per_agent * avg_handle_time).round

    {
      wait_time_minutes: estimated_minutes,
      message: format_wait_message(estimated_minutes),
      position: queued_conversations,
      status: 'online',
      available_agents: available_agents
    }
  end

  def calculate_average_handle_time
    # Get average resolution time from last 7 days
    recent_conversations = @inbox.conversations
                                 .where(status: :resolved)
                                 .where.not(first_reply_created_at: nil)
                                 .where('created_at > ?', 7.days.ago)
                                 .limit(50)

    return 5.0 if recent_conversations.empty? # Default 5 minutes

    total_time = recent_conversations.sum do |conv|
      (conv.first_reply_created_at - conv.created_at) / 60.0 # Convert to minutes
    end

    avg_time = total_time / recent_conversations.count
    [avg_time, 2.0].max # Minimum 2 minutes
  end

  def format_wait_message(minutes)
    case minutes
    when 0..1
      'An agent will be with you shortly'
    when 2..3
      'Estimated wait: Less than 5 minutes'
    when 4..10
      "Estimated wait: About #{minutes} minutes"
    when 11..30
      "Estimated wait: About #{(minutes / 5.0).round * 5} minutes"
    else
      'Current wait time is longer than usual (30+ minutes)'
    end
  end
end
