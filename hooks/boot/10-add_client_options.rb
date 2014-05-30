client = kafo.config.app.has_key?(:staypuft_client_installer) ? kafo.config.app[:staypuft_client_installer] : false
app_option '--[no-]staypuft-client-installer', :flag, 'Is this staypuft client registeration mode?', :default => client
