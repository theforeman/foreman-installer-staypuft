# Create ssh keypair for foreman-proxy user
#
# This class creates an SSH keypair for the foreman-proxy user
#
# === Parameters:
#
# $foreman_proxy_user::        Name of the foreman-proxy user
#
# $foreman_proxy_group::       Group of the foreman-proxy user
#
# $foreman_proxy_home::        Home directory of the foreman-proxy user
#
# $foreman_user::              Name of the foreman user
#
# $foreman_group::             Group of the foreman user
#
# $foreman_home::              Home directory of the foreman user
#
# $strict_host_checking::      Disable/Enable StrictHostKeyChecking for foreman-proxy user
class sshkeypair($foreman_proxy_user='foreman-proxy',
                 $foreman_proxy_group='foreman-proxy',
                 $foreman_proxy_home='/usr/share/foreman-proxy',
                 $foreman_user='foreman',
                 $foreman_group='foreman',
                 $foreman_home='/usr/share/foreman',
                 $strict_host_checking='no'
) {

  # Create foreman-proxy user .ssh Directory
  file { "${foreman_proxy_home}/.ssh":
    ensure => 'directory',
    owner  => $foreman_proxy_user,
    group  => $foreman_proxy_group,
    mode   => '0600',
    require => Package['foreman-proxy'],
  } ->
  # Create foreman user .ssh Directory
  file { "${foreman_home}/.ssh":
    ensure => 'directory',
    owner  => $foreman_user,
    group  => $foreman_group,
    mode   => '0600',
    require => Package['foreman-proxy'],
  } ->
 
  file { "${foreman_proxy_home}/.ssh/config":
    ensure  => file,
    owner  => $foreman_proxy_user,
    group  => $foreman_proxy_group,
    mode   => '0600',
    content => template('sshkeypair/ssh_config.erb'),
  } ->
  # Generate SSH keypair for foreman-proxy user
  ssh_keygen { $foreman_proxy_user:
    home => $foreman_proxy_home,
  } ->
  # Copy foreman-proxy private key
  file { "${foreman_home}/.ssh/proxy_rsa":
    ensure  => file,
    owner  => $foreman_user,
    group  => $foreman_group,
    mode   => '0600',
    source => "${foreman_proxy_home}/.ssh/id_rsa"
  }
}
include 'sshkeypair'
