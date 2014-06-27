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
# $configure_firewall::   Should local firewall be configured by installer?
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
# $ntp_host::             NTP sync host
#
# $root_password::        Default root password for provisioned machines
#                         type:password
#
# $ssh_public_key::       SSH public key installed on provisioned machines during provisioning
#
class foreman::plugin::staypuft(
    $configure_networking = true,
    $configure_firewall = true,
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
    $base_url,
    $ntp_host,
    $root_password = 'spengler',
    $ssh_public_key
) {
  validate_bool($configure_networking)

  $required_packages = ['ntpdate']
  package {$required_packages :
    ensure => installed,
  }

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
    require => Exec['NTP sync'],
  }

  exec { 'NTP sync':
    command => "/usr/sbin/ntpdate $ntp_host",
    require => Package['ntpdate'],
  }
}
