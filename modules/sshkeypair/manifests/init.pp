# Create ssh keypair for foreman-proxy user
#
# This class creates an SSH keypair for the foreman-proxy user
#
# === Parameters:
#
# $user::                   Name of the foreman-proxy user
#
# $group::                  Group of the foreman-proxy user
#
# $home::                   Home directory of the foreman-proxy user
#
# $strict_host_checking::   Disable/Enable StrictHostKeyChecking for foreman-proxy user
class sshkeypair($user='foreman-proxy',
                 $group='foreman-proxy',
                 $home='/usr/share/foreman-proxy',
                 $strict_host_checking='no'
) {

  # Create User .ssh Directory
  file { "${home}/.ssh":
    ensure => 'directory',
    owner  => $user,
    group  => $group,
    mode   => '0600',
    require => Package['foreman-proxy'],
  } ->
  # TODO Remove this once we have the ability to add clients to the known hosts as and when they are registed via
  # Override global StrictHostChecking for foreman-proxy user. 
  file { "${home}/.ssh/config":
    ensure  => file,
    owner  => $user,
    group  => $group,
    mode   => '0600',
    content => template('sshkeypair/ssh_config.erb'),
  } ->
  # Generate SSH keypair for foreman-proxy user
  ssh_keygen { $user:
    home => $home,
  }
}
include 'sshkeypair'
