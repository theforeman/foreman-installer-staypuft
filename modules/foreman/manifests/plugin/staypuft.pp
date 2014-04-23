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
class foreman::plugin::staypuft($configure_networking = true, $interface, $ip, $netmask, $gateway) {
  validate_bool($configure_networking)

  if ($configure_networking) {
    class { 'network::global':
      gateway => $gateway,
    }

    network::if::static { $interface:
      ensure    => 'up',
      ipaddress => $ip,
      netmask   => $netmask,
    }
  }
}
