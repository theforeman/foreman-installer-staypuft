if app_value(:staypuft_client_installer)
  # Register in staypuft by triggering puppet.

  # --usecacheonfailure because on registration the host will not be
  # able to fetch its yaml (Foreman doesn't know about the host yet).
  command = 'puppet agent --onetime --no-daemonize -l console --usecacheonfailure --waitforcert 15 --tags no_such_tag 2>&1'
  say "Registering with puppetmaster and waiting for certificate."
  say "If you didn't enable autosign, please sign the certificate request manually."
  logger.debug "Starting registration process by #{command}"
  logger.debug `#{command}`
  unless [0,2].include? $?
    logger.error "Error while trying to register the client in Staypuft."
    kafo.class.exit(102)
  end
end
