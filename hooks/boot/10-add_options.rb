wizard = if kafo.config.app.has_key?(:provisioning_wizard)
           kafo.config.app[:provisioning_wizard]
         else
           'interactive'
         end
app_option '--provisioning-wizard',
           'MODE',
           'Should the interactive wizard ask for provisioning information and prepare foreman ' +
               'to provision machines accordingly?' +
               'Supported modes are: interactive, non-interactive, none.',
           :default => wizard
