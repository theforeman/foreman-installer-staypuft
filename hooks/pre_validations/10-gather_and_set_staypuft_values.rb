if app_value(:provisioning_wizard)
  require File.join(KafoConfigure.root_dir, 'hooks', 'lib', 'provisioning_wizard.rb')
  wizard = ProvisioningWizard.new(kafo)
  wizard.start

  param('foreman_proxy', 'tftp_servername').value = wizard.ip
  param('foreman_proxy', 'dhcp_interface').value = wizard.interface
  param('foreman_proxy', 'dhcp_gateway').value = wizard.gateway
  param('foreman_proxy', 'dhcp_range').value = "#{wizard.from} #{wizard.to}"
  param('foreman_proxy', 'dhcp_nameservers').value = wizard.ip
  param('foreman_proxy', 'dns_interface').value = wizard.interface
  param('foreman_proxy', 'dns_zone').value = wizard.domain
  param('foreman_proxy', 'dns_reverse').value = wizard.ip.split('.')[0..2].reverse.join('.') + '.in-addr.arpa'
  param('foreman_proxy', 'dns_forwarders').value = wizard.dns
  param('foreman_proxy', 'foreman_base_url').value = wizard.base_url

  param('foreman_plugin_staypuft', 'configure_networking').value = wizard.configure_networking
  param('foreman_plugin_staypuft', 'interface').value = wizard.interface
  param('foreman_plugin_staypuft', 'ip').value = wizard.ip
  param('foreman_plugin_staypuft', 'netmask').value = wizard.netmask
  param('foreman_plugin_staypuft', 'gateway').value = wizard.gateway
  param('foreman_plugin_staypuft', 'dns').value = wizard.dns
  param('foreman_plugin_staypuft', 'network').value = wizard.network
  param('foreman_plugin_staypuft', 'from').value = wizard.from
  param('foreman_plugin_staypuft', 'to').value = wizard.to
  param('foreman_plugin_staypuft', 'domain').value = wizard.domain
  param('foreman_plugin_staypuft', 'base_url').value = wizard.base_url

  # some enforced values for foreman-installer
  param('foreman_proxy', 'tftp').value = true
  param('foreman_proxy', 'dhcp').value = true
  param('foreman_proxy', 'dns').value = true
  param('foreman_proxy', 'repo').value = 'nightly'
  param('foreman', 'repo').value = 'nightly'

  param('puppet', 'server').value = true
end
