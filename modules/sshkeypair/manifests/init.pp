# Create ssh keypair for foreman-proxy user
#
# This class creates an SSH keypair for the foreman-proxy user
#
# === Parameters:
#
# $user::            Name of the foreman-proxy user
#
# $group::           Group of the foreman-proxy user
#
# $home::            Home directory of the foreman-proxy user
class sshkeypair($user='foreman-proxy', $group='foreman-proxy', $home='/etc/foreman-proxy/') {

  # Create User .ssh Directory
  file { "${home}/.ssh":
    ensure => 'directory',
    owner  => $user,
    group  => $group,
    mode   => '0600',
    require => Package['foreman-proxy'],
  } ->
  # Generate SSH keypair for foreman-proxy user
  ssh_keygen { $user:
    home => $home,
  }
}
include 'sshkeypair'
