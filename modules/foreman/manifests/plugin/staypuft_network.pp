# = Staypuft Network
#
# Configures networking according to values gathered by wizard, it does following actions
#   * configures gateway
#   * configures interface's IP address, netmask and DNS servers
#   * adds hosts record if missing
#   * configures firewall in a non-destructive way (leaves all existing rules untouched)
#
# === Parameters:
#
# $interface::            Which interface should this class configure
#
# $ip::                   What IP address should be set
#
# $netmask::              What netmask should be set
#
# $gateway::              What is the gateway for this machine
#
# $dns::                  DNS forwarder to use as secondary nameserver
#
# $configure_networking:: Should we modify networking?
#                         type:boolean
#
# $configure_firewall::   Should we modify firewall?
#                         type:boolean
#
class foreman::plugin::staypuft_network(
    $interface,
    $ip,
    $netmask,
    $gateway,
    $dns,
    $configure_networking,
    $configure_firewall,
) {

  if ($configure_networking) {
    class { 'network::global':
      gateway => $gateway,
    }

    network::if::static { $interface:
      ensure    => 'up',
      ipaddress => $ip,
      netmask   => $netmask,
      dns1      => $ip,
      dns2      => $dns,
      peerdns   => true,
    }

    host { $fqdn:
      comment      => 'created by puppet class foreman::plugin::staypuft_network',
      ip           => $ip,
      host_aliases => $hostname
    }
  }

  if ($configure_firewall) {
    # We don't want to purge rules other than we specify below (could disable ssh etc)
    resources { "firewall":
      purge => false
    } ->
    # The Foreman server should accept ssh connections for management.
    firewall { '22 accept - ssh':
      port   => '22',
      proto  => 'tcp',
      action => 'accept',
    } ->
    # The Foreman server needs to accept DNS requests on this port for tcp and udp when provisioning systems.
    firewall { '53 accept - dns tcp':
      port   => '53',
      proto  => 'tcp',
      action => 'accept',
    } ->
    firewall { '53 accept - dns udp':
      port   => '53',
      proto  => 'udp',
      action => 'accept',
    } ->
    # The Foreman server needs to accept DHCP requests on this port when provisioning systems.
    firewall { '67 accept - dhcp':
      port   => '67',
      proto  => 'udp',
      action => 'accept',
    } ->
    # The Foreman server needs to accept BOOTP requests on this port when provisioning systems.
    firewall { '68 accept - bootp':
      port   => '68',
      proto  => 'udp',
      action => 'accept',
    } ->
    # The Foreman server needs to accept TFTP requests on this port when provisioning systems.
    firewall { '69 accept - tftp':
      port   => '69',
      proto  => 'udp',
      action => 'accept',
    } ->
    # The Foreman web user interface accepts connections on these ports.
    firewall { '80 accept - apache':
      port   => '80',
      proto  => 'tcp',
      action => 'accept',
    } ->
    firewall { '443 accept - apache':
      port   => '443',
      proto  => 'tcp',
      action => 'accept',
    } ->
    # The Foreman server accepts connections to Puppet on this port.
    firewall { '8140 accept - puppetmaster':
      port   => '8140',
      proto  => 'tcp',
      action => 'accept',
    }
  }
}
