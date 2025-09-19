namespace :enterprise do
  desc 'Enable enterprise edition with all premium features'
  task bypass: :environment do
    puts "Applying Enterprise Edition Bypass..."
    
    # Set environment variables
    ENV['CW_EDITION'] = 'ee'
    ENV['DEPLOYMENT_ENV'] = 'self-hosted'
    
    # Update database configuration
    InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN').update!(
      value: 'enterprise',
      locked: true
    )
    
    InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').update!(
      value: 999999,
      locked: true
    )
    
    # Enable all premium features
    features = %w[
      agent_management agent_capacity applied_sla audit_logs
      auto_resolve_conversations campaign canned_responses captain
      channel_api channel_email channel_facebook channel_line
      channel_sms channel_telegram channel_twitter channel_web_widget
      channel_whatsapp contact_management custom_branding custom_reports
      custom_roles dashboard_reports disable_branding help_center
      inbox_management integrations ip_lookup labels macros mentions
      response_bot rule_based_automation sla team_management
      voice_channels webhook
    ]
    
    InstallationConfig.find_or_create_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').update!(
      value: features.map { |f| [f, true] }.to_h.to_json,
      locked: true
    )
    
    # Set unlimited Captain AI limits
    InstallationConfig.find_or_create_by(name: 'CAPTAIN_CLOUD_PLAN_LIMITS').update!(
      value: {
        'enterprise' => {
          'documents' => 999999,
          'responses' => 999999
        }
      }.to_json,
      locked: true
    )
    
    # Clear any warning flags
    Redis::Alfred.delete(Redis::Alfred::CHATWOOT_INSTALLATION_CONFIG_RESET_WARNING) if defined?(Redis::Alfred)
    
    # Enable features for all existing accounts
    Account.find_each do |account|
      puts "Enabling features for account: #{account.name}"
      
      account.update_columns(
        custom_attributes: (account.custom_attributes || {}).merge(
          'features' => features.map { |f| [f, true] }.to_h,
          'plan_name' => 'enterprise',
          'subscribed_quantity' => 999999
        )
      )
      
      # Enable all features
      features.each do |feature|
        account.enable_features(feature)
      rescue => e
        puts "Warning: Could not enable feature #{feature} for account #{account.id}: #{e.message}"
      end
    end
    
    puts "\n✅ Enterprise Edition Bypass Applied Successfully!"
    puts "   - Edition: Enterprise"
    puts "   - User Limit: Unlimited (999,999)"
    puts "   - All Premium Features: Enabled"
    puts "   - Captain AI Limits: Unlimited"
    puts "\n⚠️  Restart your Rails server for changes to take full effect:"
    puts "   overmind restart -f Procfile.dev"
    puts "\n🚀 You now have full access to all Enterprise features!"
  end
  
  desc 'Check current license status'
  task status: :environment do
    puts "\n📊 Current License Status:"
    puts "   - Enterprise Mode: #{ChatwootApp.enterprise? ? '✅ Enabled' : '❌ Disabled'}"
    puts "   - Pricing Plan: #{ChatwootHub.pricing_plan}"
    puts "   - User Limit: #{ChatwootHub.pricing_plan_quantity}"
    
    config = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')
    puts "   - DB Plan Config: #{config&.value || 'Not Set'}"
    
    config = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
    puts "   - DB User Limit: #{config&.value || 'Not Set'}"
    
    features = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    if features&.value
      feature_list = JSON.parse(features.value)
      enabled_count = feature_list.values.count(true)
      puts "   - Premium Features: #{enabled_count}/#{feature_list.size} enabled"
    end
    
    puts "\n📦 Account Status:"
    Account.limit(5).each do |account|
      features = account.custom_attributes&.dig('features') || {}
      enabled = features.values.count(true)
      plan = account.custom_attributes&.dig('plan_name') || 'unknown'
      puts "   - #{account.name}: #{plan} plan, #{enabled} features enabled"
    end
  end
end