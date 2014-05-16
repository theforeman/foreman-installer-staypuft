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
# $gateway::              What is the gateway for this machine
#
# $dns::                  DNS forwarder to use as secondary nameserver
class foreman::plugin::staypuft($configure_networking = true, $interface, $ip, $netmask, $gateway, $dns) {
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
  }
}
