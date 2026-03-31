Rails.application.config.middleware.use OmniAuth::Builder do
  Array($OMNIAUTH_PROVIDERS).each do |provider_key, config|
    next unless config[:enable]

    strategy = config[:strategy] || provider_key
    options = { client_options: config[:client_options].to_h }
    options[:name] = config[:name] if config[:name]
    options[:pkce] = config[:pkce] if config[:pkce]
    options[:scope] = config[:scope] if config[:scope]

    provider strategy, config[:client_id], config[:client_secret], **options
  end
end