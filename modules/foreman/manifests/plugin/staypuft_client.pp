# = Staypuft
#
# Configures host to be ready for use by staypuft
#
# === Parameters:
#
# $puppetmaster::               Puppetmaster url (usually staypuft host fqdn)
#
# $puppetssh_user::             A user to use when connecting using SSH
#
# $staypuft_ssh_public_key::    This key will be added to SSH authorized keys
#
class foreman::plugin::staypuft_client(
  $puppetmaster   = $::fqdn,
  $puppetssh_user = 'root',
  $staypuft_ssh_public_key,
) {
  ssh_authorized_key { 'staypuft public key':
    key  => $staypuft_ssh_public_key,
    user => $puppetssh_user,
    type => 'ssh-rsa'
  }
}
