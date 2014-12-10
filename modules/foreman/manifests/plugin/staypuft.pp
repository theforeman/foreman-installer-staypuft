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
# $gateway::              What is the gateway for machines using managed DHCP
#
# $ntp_host::             NTP sync host
#
# $timezone::             Timezone (IANA identifier)
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
    $ntp_host,
    $timezone,
    $root_password,
    $ssh_public_key
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
    notify  => Class['foreman::service'],
    require => Exec['NTP sync'],
  }

  exec { 'NTP sync':
    command => "/sbin/service ntpd stop; /usr/sbin/ntpdate $ntp_host",
    notify  => Service['ntpd'],
    require => [Package['ntp'], Package['ntpdate']],
  }

  package { ['ntp', 'ntpdate']: }

  service { 'ntpd':
    name   => 'ntpd',
    ensure => 'running',
    enable => true,
  }

  if $timezone {
    case $::osfamily {
      'RedHat': {
        if ($::operatingsystem == 'Fedora' or
           ($::operatingsystem != 'Fedora' and $::operatingsystemmajrelease > 6)) {
          # EL 7 variants and Fedora
          exec { 'set timezone':
            command => "/bin/timedatectl set-timezone $timezone",
          }
        } else {
          # EL 6 variants
          exec { 'ensure selected timezone exists':
            command => "/usr/bin/test -e /usr/share/zoneinfo/$timezone",
          }

          file { '/etc/localtime':
            ensure  => 'file',
            source  => "/usr/share/zoneinfo/$timezone",
            replace => true,
            require => Exec['ensure selected timezone exists'],
          }

          exec { 'set timezone in /etc/sysconfig/clock':
            command => "/bin/sed -ie 's|^ZONE=.*$|ZONE=\"$timezone\"|' /etc/sysconfig/clock",
            require => Exec['ensure selected timezone exists'],
          }
        }
      }
      default: {
        fail("${::hostname}: Setting timezone not supported on osfamily ${::osfamily}")
      }
    }
  }
}
