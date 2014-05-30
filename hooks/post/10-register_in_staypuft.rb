if app_value(:staypuft_client_installer)
  # register in staypuft by triggering puppet in noop mode
  logger.debug 'starting registration process by puppet agent --test'
  logger.debug `puppet agent --test`
end
