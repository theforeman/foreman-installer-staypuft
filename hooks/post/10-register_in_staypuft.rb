if app_value(:staypuft_client_installer)
  # register in staypuft by triggering puppet
  command = 'puppet agent --onetime --no-daemonize -l console --tags no_such_tag'
  logger.debug "starting registration process by #{command}"
  logger.debug `#{command}`
end
