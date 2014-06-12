if app_value(:provisioning_wizard) && [0,2].include?(kafo.exit_code)
  require File.join(KafoConfigure.root_dir, 'hooks', 'lib', 'foreman.rb')
  require File.join(KafoConfigure.root_dir, 'hooks', 'lib', 'base_seeder.rb')
  require File.join(KafoConfigure.root_dir, 'hooks', 'lib', 'provisioning_seeder.rb')
  require File.join(KafoConfigure.root_dir, 'hooks', 'lib', 'subscription_seeder.rb')

  puts "Starting configuration..."

  # we must enforce at least one puppet run
  logger.debug 'Running puppet agent to seed foreman data'
  `service puppet stop`
  `puppet agent -t`
  `service puppet start`
  logger.debug 'Puppet agent run finished'

  logger.debug 'Installing puppet modules'
  `/usr/share/foreman-installer/hooks/lib/install_modules.sh`
  `foreman-rake puppet:import:puppet_classes[batch]`
  # run import
  logger.debug 'Puppet modules installed'


  # first, create RedHat installation media and subscription info
  sub_seeder = SubscriptionSeeder.new(kafo)
  sub_seeder.seed

  # add other provisioning data
  pro_seeder = ProvisioningSeeder.new(kafo)
  pro_seeder.seed
  `foreman-rake db:seed`
else
  say "Not running provisioning configuration since installation encountered errors, exit code was <%= color('#{kafo.exit_code}', :bad) %>"
  false
end
