# Enterprise Edition Bypass Initializer
# This initializer enables all enterprise and premium features

if ENV['SKIP_DB_INITIALIZERS'] != '1'
Rails.application.config.after_initialize do
  # Ensure enterprise mode is enabled
  ENV['CW_EDITION'] = 'ee'
  ENV['DEPLOYMENT_ENV'] = 'self-hosted'

  if defined?(InstallationConfig) && ActiveRecord::Base.connection.table_exists?('installation_configs')
    begin
      # Plan and user quantity
      InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN').update!(value: 'enterprise', locked: true)
      InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').update!(value: 999_999, locked: true)

      # Load features.yml and mark all features enabled
      features_def = YAML.safe_load(File.read(Rails.root.join('config/features.yml')))
      enabled_features = features_def.map { |f| f.merge('enabled' => true) }

      # Persist installation-level default feature flags in expected format (array of hashes)
      InstallationConfig.find_or_create_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').update!(
        value: enabled_features,
        locked: true
      )

      # Optional plan limits structure (keep as Ruby hashes, not JSON strings)
      InstallationConfig.find_or_create_by(name: 'CAPTAIN_CLOUD_PLAN_LIMITS').update!(
        value: {
          'document_limit' => 999_999,
          'response_limit' => 999_999,
          'reset_period' => 'never'
        },
        locked: true
      )

      InstallationConfig.find_or_create_by(name: 'CHATWOOT_CLOUD_PLAN_FEATURES').update!(
        value: {
          'plans' => {
            'enterprise' => {
              'name' => 'Enterprise',
              'features' => enabled_features.map { |f| f['name'] }
            }
          }
        },
        locked: true
      )

      # Enable features on all existing accounts via bit flags
      if defined?(Account) && ActiveRecord::Base.connection.table_exists?('accounts')
        names = enabled_features.map { |f| f['name'] }
        Account.find_each do |account|
          account.enable_features!(*names)
          account.update_columns(
            custom_attributes: (account.custom_attributes || {}).merge(
              'features' => names.index_with { true },
              'plan_name' => 'enterprise',
              'subscribed_quantity' => 999_999
            )
          )
        end
      end

      GlobalConfig.clear_cache if defined?(GlobalConfig)
      Rails.logger.info 'Enterprise bypass activated - All premium features enabled'
    rescue => e
      Rails.logger.error "Failed to apply enterprise bypass: #{e.message}"
    end
  end
end
end
