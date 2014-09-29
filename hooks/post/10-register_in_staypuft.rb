if app_value(:staypuft_client_installer)
  # Register in staypuft by triggering puppet.

  # --usecacheonfailure because on registration the host will not be
  # able to fetch its yaml (Foreman doesn't know about the host yet).
  command = 'puppet agent --onetime --no-daemonize -l console --usecacheonfailure --tags no_such_tag 2>&1'
  logger.debug "Starting registration process by #{command}"
  logger.debug `#{command}`
  unless [0,2].include? $?
    logger.error "Error while trying to register the client in Staypuft."
    kafo.class.exit(102)
  end
end
