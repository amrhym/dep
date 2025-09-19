module Enterprise::Internal::CheckNewVersionsJob
  def perform
    super
    # Bypass: Force enterprise plan configuration
    force_enterprise_plan
    # Skip reconciliation that would disable features
  end

  private

  def force_enterprise_plan
    # Bypass: Set enterprise plan with unlimited users
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN', value: 'enterprise')
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN_QUANTITY', value: 999999)
    update_installation_config(key: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN', value: 'enterprise_bypass')
    update_installation_config(key: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH', value: 'enterprise_bypass')
    update_installation_config(key: 'CHATWOOT_SUPPORT_SCRIPT_URL', value: 'enterprise_bypass')
  end

  def update_plan_info
    # Original method kept but not called
    return if @instance_info.blank?

    update_installation_config(key: 'INSTALLATION_PRICING_PLAN', value: @instance_info['plan'])
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN_QUANTITY', value: @instance_info['plan_quantity'])
    update_installation_config(key: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN', value: @instance_info['chatwoot_support_website_token'])
    update_installation_config(key: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH', value: @instance_info['chatwoot_support_identifier_hash'])
    update_installation_config(key: 'CHATWOOT_SUPPORT_SCRIPT_URL', value: @instance_info['chatwoot_support_script_url'])
  end

  def update_installation_config(key:, value:)
    config = InstallationConfig.find_or_initialize_by(name: key)
    config.value = value
    config.locked = true
    config.save!
  end

  def reconcile_premium_config_and_features
    Internal::ReconcilePlanConfigService.new.perform
  end
end
