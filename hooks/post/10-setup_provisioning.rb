if app_value(:provisioning_wizard)
  require 'tmpdir'
  require File.join(KafoConfigure.root_dir, 'hooks', 'lib', 'foreman.rb')
  require File.join(KafoConfigure.root_dir, 'hooks', 'lib', 'base_seeder.rb')
  require File.join(KafoConfigure.root_dir, 'hooks', 'lib', 'provisioning_seeder.rb')
  require File.join(KafoConfigure.root_dir, 'hooks', 'lib', 'subscription_seeder.rb')

  say "Starting configuration..."

  # we must enforce at least one puppet run
  logger.debug 'Running puppet agent to seed foreman data'
  `service puppet stop`
  `puppet agent -t`
  `service puppet start`
  logger.debug 'Puppet agent run finished'

  logger.debug 'Installing puppet modules'
  `/usr/share/foreman-installer/hooks/lib/install_modules.sh`
  `foreman-rake 'puppet:import:puppet_classes[batch]'`
  # run import
  logger.debug 'Puppet modules installed'

  # first, create RedHat installation media and subscription info
  sub_seeder = SubscriptionSeeder.new(kafo)
  sub_seeder.seed

  # add other provisioning data
  pro_seeder = ProvisioningSeeder.new(kafo)
  pro_seeder.seed
  `foreman-rake db:seed`

  say "Generating answer file for client installers..."
  dump_file = Dir.tmpdir + '/staypuft-client-installer.answers.yaml'
  begin
    pub_key_path = param('sshkeypair', 'home').value + '/.ssh/id_rsa.pub'
    pub_key = File.read(pub_key_path).split(' ')[1]
  rescue => e
    say "Could not read SSH public key from #{pub_key_path} - #{e.message}, answer file will be <%= color('broken', :bad) %>"
    pub_key = 'broken'
  end

  answers = {
      'puppet' => {
          'server' => false,
          'runmode' => 'none',
          'puppetmaster' => pro_seeder.fqdn,
      },
      'foreman::plugin::staypuft_client' => {
          'staypuft_public_ssh_key' => pub_key,
      }
  }
  File.open(dump_file, 'w') { |file| file.write(YAML.dump(answers)) }


  say "  To register existing machine to staypuft, perform following actions on that host"
  say "    1. Install foreman-installer-staypuft"
  say "    2. Copy local <%= color('#{dump_file}', :info) %> file to /etc/foreman/staypuft-client-installer.answers.yaml on target host"
  say "    3. Run staypuft-client-installer"
end
