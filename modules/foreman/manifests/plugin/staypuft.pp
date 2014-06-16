# = Staypuft
#
# Configures networking according to values gathered by wizard but only if enabled
#
# === Parameters:
#
# $configure_networking:: Should local networking be configured by installer?
#                         type:boolean
#
# $interface::            Which interface should this class configure
#
# $ip::                   What IP address should be set
#
# $netmask::              What netmask should be set
#
# $own_gateway::          What is the gateway for this machine
#
# $dns::                  DNS forwarder to use as secondary nameserver
#
# === Extra parameters:
#
# These parameters are not used for this class. They are placeholders for the installer
# so it can store values in answer file
#
# $network::              Network address used when seeding subnet in Foreman
#
# $from::                 DHCP range first address, used for DHCP configuration and
#                         during Foreman subnet seeding
#
# $to::                   DHCP range last address, used for DHCP configuration and
#                         during Foreman subned seeding
#
# $domain::               DNZ zone, used for DNS server configuration and during Foreman
#                         Domain seeding
#
# $base_url::             URL of Foreman instance used for smart proxy configuration
#
# $gateway::              What is the gateway for machines using managed DHCP
#
class foreman::plugin::staypuft(
    $configure_networking = true,
    $interface,
    $ip,
    $netmask,
    $own_gateway,
    $gateway,
    $dns,
    $network,
    $from,
    $to,
    $domain,
    $base_url
) {
  validate_bool($configure_networking)

  case $::operatingsystem {
    'fedora': {
      $staypuft_name = 'rubygem-staypuft'
    }
    default: {
      $staypuft_name = 'ruby193-rubygem-staypuft'
    }
  }

  package { $staypuft_name:
    ensure => installed,
    notify => Class['foreman::service'],
  }

  if ($configure_networking) {
    class { 'network::global':
      gateway => $own_gateway,
    }

    network::if::static { $interface:
      ensure    => 'up',
      ipaddress => $ip,
      netmask   => $netmask,
      dns1      => $ip,
      dns2      => $dns,
      peerdns   => true,
    }

    # We don't want to purge rules other than we specify below (could disable ssh etc)
    resources { "firewall":
      purge => false
    } ->
    # The Foreman server needs to accept DNS requests on this port when provisioning systems.
    firewall { '53 accept - dns':
      port   => '53',
      proto  => 'tcp',
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
