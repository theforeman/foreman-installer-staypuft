if app_value(:provisioning_wizard)
  require File.join(KafoConfigure.root_dir, 'hooks', 'lib', 'provisioning_seeder.rb')
  require File.join(KafoConfigure.root_dir, 'hooks', 'lib', 'foreman.rb')

  # we must enforce at least one puppet run
  logger.debug 'Running puppet agent to seed foreman data'
  `service puppet stop`
  `puppet agent -t`
  `service puppet start`
  logger.debug 'Puppet agent run finished'

  seeder = ProvisioningSeeder.new(kafo)
  seeder.seed
end
