wizard = kafo.config.app.has_key?(:provisioning_wizard) ? kafo.config.app[:provisioning_wizard] : true
app_option '--[no-]provisioning-wizard', :flag, 'Should the interactive wizard ask for provisioning information and prepare foreman to provision machines accordingly?', :default => wizard

client = kafo.config.app.has_key?(:staypuft_client_installer) ? kafo.config.app[:staypuft_client_installer] : false
app_option '--[no-]staypuft-client-installer', :flag, 'Is this staypuft client registeration mode?', :default => client
