# = Staypuft
#
# Installs staypuft package
#
# === Extra parameters:
#
# These parameters are not used for this class. They are placeholders for the installer
# so it can store values in answer file
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
}
