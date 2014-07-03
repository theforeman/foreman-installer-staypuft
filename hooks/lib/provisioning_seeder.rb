require 'ipaddr'

class ProvisioningSeeder < BaseSeeder
  attr_accessor :domain, :fqdn

  def initialize(kafo)
    super
    @domain = kafo.param('foreman_proxy', 'dns_zone').value
    @environment = kafo.param('foreman', 'environment').value

    @netmask = kafo.param('foreman_plugin_staypuft', 'netmask').value
    @network = kafo.param('foreman_plugin_staypuft', 'network').value
    @ip = kafo.param('foreman_proxy', 'tftp_servername').value
    @from = kafo.param('foreman_plugin_staypuft', 'from').value
    @to = kafo.param('foreman_plugin_staypuft', 'to').value
    @gateway = kafo.param('foreman_proxy', 'dhcp_gateway').value
    @kernel = kafo.param('foreman_plugin_discovery', 'kernel').value
    @initrd = kafo.param('foreman_plugin_discovery', 'initrd').value
    @discovery_env_name = 'discovery'
    @default_root_pass = kafo.param('foreman_plugin_staypuft', 'root_password').instance_variable_get('@value')
    @default_ssh_public_key = kafo.param('foreman_plugin_staypuft', 'ssh_public_key').value
  end

  def seed
    say HighLine.color("Starting to seed provisioning data", :good)
    default_proxy = find_default_proxy
    default_environment = find_default_environment
    foreman_host = find_foreman_host

    default_domain = @foreman.domain.show_or_ensure({'id' => @domain},
                                                    {'name' => @domain,
                                                     'fullname' => 'Default domain used for provisioning',
                                                     'dns_id' => default_proxy['id']})

    default_subnet = @foreman.subnet.show_or_ensure({'id' => 'default'},
                                                    {'name' => 'default',
                                                     'mask' => @netmask,
                                                     'network' => @network,
                                                     'dns_primary' => @ip,
                                                     'from' => @from,
                                                     'to' => @to,
                                                     'gateway' => @gateway,
                                                     'domain_ids' => [default_domain['id']],
                                                     'dns_id' => default_proxy['id'],
                                                     'dhcp_id' => default_proxy['id'],
                                                     'tftp_id' => default_proxy['id']})

    @foreman.config_template.show_or_ensure({'id' => 'redhat_register'},
                                            {'template' => redhat_register_snippet})
    @foreman.config_template.show_or_ensure({'id' => 'Kickstart RHEL default'},
                                            {'template' => kickstart_rhel_default})
    @foreman.config_template.show_or_ensure({'id' => 'Kickstart default'},
                                            {'template' => kickstart_default})
    @foreman.config_template.show_or_ensure({'id' => 'ssh_public_key'},
                                            {'template' => ssh_public_key_snippet, 'snippet' => '1', 'name' => 'ssh_public_key'})

    name = 'PXELinux global default'
    pxe_template = @foreman.config_template.show_or_ensure({'id' => name},
                                                           {'template' => template})

    @foreman.config_template.build_pxe_default

    @hostgroups = []
    oses = find_default_oses(foreman_host)
    oses.each do |os|
      group_id = "base_#{os['name']}_#{os['major']}"

      medium = @foreman.medium.index('search' => "name ~ #{os['name']}").first

      if os['architectures'].nil? || os['architectures'].empty?
        @foreman.operating_system.update 'id' => os['id'],
                                         'operatingsystem' => {'architecture_ids' => [foreman_host['architecture_id']]}
      end

      if os['media'].nil? || os['media'].empty?
        if medium.nil?
          say HighLine.color("Installation medium for #{os['name']} not found, provisioning will not work for hostgroup #{group_id} unless you create it manually", :info)
        else
          @foreman.operating_system.update 'id' => os['id'], 'operatingsystem' => {'medium_ids' => [medium['id']]}
        end
      end

      assign_provisioning_templates(os)
      ptable = assign_partition_table(os)

      hostgroup_attrs = {'name' => group_id,
                         'architecture_id' => foreman_host['architecture_id'],
                         'domain_id' => default_domain['id'],
                         'environment_id' => default_environment['id'],
                         'operatingsystem_id' => os['id'],
                         'ptable_id' => ptable['id'],
                         'puppet_ca_proxy_id' => default_proxy['id'],
                         'puppet_proxy_id' => default_proxy['id'],
                         'subnet_id' => default_subnet['id']}
      hostgroup_attrs['medium_id'] = medium['id'] unless medium.nil?

      hostgroup = @foreman.hostgroup.show_or_ensure({'id' => group_id}, hostgroup_attrs)

      if !@default_ssh_public_key.nil? && !@default_ssh_public_key.empty?
        @foreman.parameter.show_or_ensure({'id' => 'ssh_public_key', 'operatingsystem_id' => os['id']},
                                          {
                                              'name' => 'ssh_public_key',
                                              'value' => @default_ssh_public_key,
                                          })
      end
      @hostgroups.push hostgroup
    end

    default_hostgroup = @hostgroups.last
    setup_setting(default_hostgroup)
    setup_idle_timeout
    setup_default_root_pass
    create_discovery_env(pxe_template)

    say HighLine.color("Use '#{default_hostgroup['name']}' hostgroup for provisioning", :good)
  end

  private

  def create_discovery_env(template)
    env = @foreman.environment.show_or_ensure({'id' => @discovery_env_name},
                                              {'name' => @discovery_env_name})
    # if the template has combination already, we don't update it
    unless template['template_combinations'].any? { |c| c['environment_id'] == env['id'].to_i and c['hostgroup_id'].nil? }
      @foreman.config_template.update 'id' => template['name'],
                                      'config_template' => {'template_combinations_attributes' => [{'environment_id' => env['id']}]}
    end
  end

  def setup_setting(default_hostgroup)
    @foreman.setting.show_or_ensure({'id' => 'base_hostgroup'},
                                    {'value' => default_hostgroup['name'].to_s})
  rescue NoMethodError => e
    @logger.error "Setting with name 'base_hostgroup' not found, you must run 'foreman-rake db:seed' " +
                      "and rerun installer to fix this issue."
  end

  def setup_idle_timeout
    @foreman.setting.show_or_ensure({'id' => 'idle_timeout'},
                                    {'value' => 180})
  rescue NoMethodError => e
    @logger.error "Setting with name 'idle_timeout' not found, you must run 'foreman-rake db:seed' " +
                      "and rerun installer to fix this issue."
  end

  def setup_default_root_pass
    @foreman.setting.show_or_ensure({'id' => 'root_pass'},
                                    {'value' => @default_root_pass.to_s.crypt('$5$fm')})
  rescue NoMethodError => e
    @logger.error "Setting with name 'root_pass' not found, you must run 'foreman-rake db:seed' " +
                      "and rerun installer to fix this issue."
  end

  def assign_partition_table(os)
    if os['family'] == 'Redhat'
      ptable_name = 'Kickstart default'
    elsif os['family'] == 'Debian'
      ptable_name = 'Preseed default'
    end
    ptable = @foreman.partition_table.first! %Q(name ~ "#{ptable_name}*")
    if os['ptables'].nil? || os['ptables'].empty?
      ids = @foreman.partition_table.show!('id' => ptable['id'])['operatingsystems'].map { |o| o['id'] }
      @foreman.partition_table.update 'id' => ptable['id'], 'ptable' => {'operatingsystem_ids' => (ids + [os['id']]).uniq}
    end
    ptable
  end

  def assign_provisioning_templates(os)
    # Default values used for provision template searching, some were renamed after 1.4
    if os['family'] == 'Redhat'
      tmpl_name = 'Kickstart default'
      provision_tmpl_name = os['name'] == 'RedHat' ? 'Kickstart RHEL default' : tmpl_name
      ipxe_tmpl_name = 'Kickstart'
    elsif os['family'] == 'Debian'
      tmpl_name = provision_tmpl_name = 'Preseed'
      ipxe_tmpl_name = nil
    end

    {'provision' => provision_tmpl_name, 'PXELinux' => tmpl_name, 'iPXE' => ipxe_tmpl_name}.each do |kind_name, tmpl_name|
      next if tmpl_name.nil?
      kinds = @foreman.template_kind.index
      kind = kinds.detect { |k| k['name'] == kind_name }

      # we prefer foreman_bootdisk templates
      tmpls = @foreman.config_template.search "name ~ \"#{tmpl_name}*\" and kind = #{kind_name}"
      tmpl = tmpls.detect { |t| t['name'] =~ /.*sboot disk.*s/ } || tmpls.first
      raise StandardError, "no template found by search 'name ~ \"#{tmpl_name}*\"'" if tmpl.nil?

      # if there's no provisioning template for this os family found it means, it's not associated so we add relation
      # otherwise we still must check that it's assigned for right os not just family
      assigned_tmpl = @foreman.config_template.first %Q(name ~ "#{tmpl_name}*" and kind = #{kind_name} and operatingsystem = "#{os['name']}")
      if assigned_tmpl.nil?
        @foreman.config_template.update 'id' => tmpl['id'], 'config_template' => {'operatingsystem_ids' => [os['id']]}
      else
        assigned_os_ids = @foreman.config_template.show!('id' => tmpl['id'])['operatingsystems'].map { |o| o['id'] }
        if !assigned_os_ids.include?(os['id'])
          @foreman.config_template.update 'id' => tmpl['id'], 'config_template' => {'operatingsystem_ids' => assigned_os_ids + [os['id']]}
        end
      end

      # finally we setup default template from possible values we assigned in previous steps
      os_tmpls = @foreman.os_default_template.index 'operatingsystem_id' => os['id']
      os_tmpl = os_tmpls.detect { |t| t['template_kind_name'] == kind_name }
      if os_tmpl.nil?
        @foreman.os_default_template.create 'os_default_template' => {'config_template_id' => tmpl['id'], 'template_kind_id' => kind['id']},
                                            'operatingsystem_id' => os['id']
      end
    end
  end

  def find_default_environment
    @foreman.environment.show! 'id' => @environment,
                               :error_message => "environment #{@environment} not found in foreman, puppet haven't run yet?"
  end

  def find_default_proxy
    @foreman.smart_proxy.show! 'id' => @fqdn,
                               :error_message => "smart proxy #{@fqdn} haven't been registered in foreman yet, installer failure?"
  end

  def kickstart_rhel_default
    <<'EOS'
<%#
kind: provision
name: Kickstart RHEL default
oses:
- RedHat 4
- RedHat 5
- RedHat 6
- RedHat 7
%>
<%
  os_major = @host.operatingsystem.major.to_i
  # safemode renderer does not support unary negation
  pm_set = @host.puppetmaster.empty? ? false : true
  puppet_enabled = pm_set || @host.params['force-puppet']
%>
install
<%= @mediapath %>
lang en_US.UTF-8
selinux --enforcing
keyboard us
skipx
network --bootproto <%= @static ? "static --ip=#{@host.ip} --netmask=#{@host.subnet.mask} --gateway=#{@host.subnet.gateway} --nameserver=#{[@host.subnet.dns_primary, @host.subnet.dns_secondary].reject { |n| n.blank? }.join(',')}" : 'dhcp' %> --hostname <%= @host %>
rootpw --iscrypted <%= root_pass %>
firewall --<%= os_major >= 6 ? 'service=' : '' %>ssh
authconfig --useshadow --passalgo=sha256 --kickstart
timezone --utc <%= @host.params['time-zone'] || 'UTC' %>

<% if os_major >= 7 && @host.info["parameters"]["realm"] && @host.otp && @host.realm -%>
realm join --one-time-password=<%= @host.otp %> <%= @host.realm %>
<% end -%>

<% if os_major > 4 -%>
services --disabled autofs,gpm,sendmail,cups,iptables,ip6tables,auditd,arptables_jf,xfs,pcmcia,isdn,rawdevices,hpoj,bluetooth,openibd,avahi-daemon,avahi-dnsconfd,hidd,hplip,pcscd,restorecond,mcstrans,rhnsd,yum-updatesd

<% if puppet_enabled && @host.params['enable-puppetlabs-repo'] && @host.params['enable-puppetlabs-repo'] == 'true' -%>
repo --name=puppetlabs-products --baseurl=http://yum.puppetlabs.com/el/<%= @host.operatingsystem.major %>/products/<%= @host.architecture %>
repo --name=puppetlabs-deps --baseurl=http://yum.puppetlabs.com/el/<%= @host.operatingsystem.major %>/dependencies/<%= @host.architecture %>
<% end -%>
<% end -%>

bootloader --location=mbr --append="nofb quiet splash=quiet" <%= grub_pass %>
<% if os_major == 5 -%>
key --skip
<% end -%>


<% if @dynamic -%>
%include /tmp/diskpart.cfg
<% else -%>
<%= @host.diskLayout %>
<% end -%>

text
reboot

%packages --ignoremissing
yum
dhclient
ntp
wget
@Core
epel-release
<% if puppet_enabled %>
puppet
<% if @host.params['enable-puppetlabs-repo'] && @host.params['enable-puppetlabs-repo'] == 'true' -%>
puppetlabs-release
<% end -%>
<% end -%>
%end

<% if @dynamic -%>
%pre
<%= @host.diskLayout %>
%end
<% end -%>

%post --nochroot
exec < /dev/tty3 > /dev/tty3
#changing to VT 3 so that we can see whats going on....
/usr/bin/chvt 3
(
cp -va /etc/resolv.conf /mnt/sysimage/etc/resolv.conf
/usr/bin/chvt 1
) 2>&1 | tee /mnt/sysimage/root/install.postnochroot.log
%end

%post
logger "Starting anaconda <%= @host %> postinstall"
exec < /dev/tty3 > /dev/tty3
#changing to VT 3 so that we can see whats going on....
/usr/bin/chvt 3
(
#update local time
echo "updating system time"
/usr/sbin/ntpdate -sub <%= @host.params['ntp-server'] || '0.fedora.pool.ntp.org' %>
/usr/sbin/hwclock --systohc

# setup SSH key for root user
<%= snippet 'ssh_public_key' %>

<%= snippet 'redhat_register' %>

<% if @host.info["parameters"]["realm"] && @host.otp && @host.realm && @host.realm.realm_type == "Red Hat Directory Server" && os_major <= 6 -%>
<%= snippet "freeipa_register" %>
<% end -%>

# update all the base packages from the updates repository
yum -t -y -e 0 update

<% if puppet_enabled %>
# and add the puppet package
yum -t -y -e 0 install puppet

echo "Configuring puppet"
cat > /etc/puppet/puppet.conf << EOF
<%= snippet 'puppet.conf' %>
EOF

# Setup puppet to run on system reboot
/sbin/chkconfig --level 345 puppet on

/usr/bin/puppet agent --config /etc/puppet/puppet.conf -o --tags no_such_tag <%= @host.puppetmaster.blank? ? '' : "--server #{@host.puppetmaster}" %> --no-daemonize

<% end -%>

sync

# Inform the build system that we are done.
echo "Informing Foreman that we are built"
wget -q -O /dev/null --no-check-certificate <%= foreman_url %>
# Sleeping an hour for debug
) 2>&1 | tee /root/install.post.log
exit 0

%end
EOS
  end

  def kickstart_default
    <<'EOS'
<%#
kind: provision
name: Kickstart default
oses:
- CentOS 4
- CentOS 5
- CentOS 6
- CentOS 7
- Fedora 16
- Fedora 17
- Fedora 18
- Fedora 19
- Fedora 20
%>
<%
  rhel_compatible = @host.operatingsystem.family == 'Redhat' && @host.operatingsystem.name != 'Fedora'
  os_major = @host.operatingsystem.major.to_i
  realm_compatible = (@host.operatingsystem.name == "Fedora" && os_major >= 20) || (rhel_compatible && os_major >= 7)
  # safemode renderer does not support unary negation
  realm_incompatible = (@host.operatingsystem.name == "Fedora" && os_major < 20) || (rhel_compatible && os_major < 7)
  pm_set = @host.puppetmaster.empty? ? false : true
  puppet_enabled = pm_set || @host.params['force-puppet']
%>
install
<%= @mediapath %>
lang en_US.UTF-8
selinux --enforcing
keyboard us
skipx
network --bootproto <%= @static ? "static --ip=#{@host.ip} --netmask=#{@host.subnet.mask} --gateway=#{@host.subnet.gateway} --nameserver=#{[@host.subnet.dns_primary, @host.subnet.dns_secondary].reject { |n| n.blank? }.join(',')}" : 'dhcp' %> --hostname <%= @host %>
rootpw --iscrypted <%= root_pass %>
firewall --<%= os_major >= 6 ? 'service=' : '' %>ssh
authconfig --useshadow --passalgo=sha256 --kickstart
timezone --utc <%= @host.params['time-zone'] || 'UTC' %>
<% if rhel_compatible && os_major > 4 -%>
services --disabled autofs,gpm,sendmail,cups,iptables,ip6tables,auditd,arptables_jf,xfs,pcmcia,isdn,rawdevices,hpoj,bluetooth,openibd,avahi-daemon,avahi-dnsconfd,hidd,hplip,pcscd,restorecond,mcstrans,rhnsd,yum-updatesd
<% end -%>

<% if realm_compatible && @host.info["parameters"]["realm"] && @host.otp && @host.realm -%>
realm join --one-time-password='<%= @host.otp %>' <%= @host.realm %>
<% end -%>

<% if @host.operatingsystem.name == 'Fedora' -%>
repo --name=fedora-everything --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=fedora-<%= @host.operatingsystem.major %>&arch=<%= @host.architecture %>
<% if puppet_enabled && @host.params['enable-puppetlabs-repo'] && @host.params['enable-puppetlabs-repo'] == 'true' -%>
repo --name=puppetlabs-products --baseurl=http://yum.puppetlabs.com/fedora/f<%= @host.operatingsystem.major %>/products/<%= @host.architecture %>
repo --name=puppetlabs-deps --baseurl=http://yum.puppetlabs.com/fedora/f<%= @host.operatingsystem.major %>/dependencies/<%= @host.architecture %>
<% end -%>
<% elsif rhel_compatible && os_major > 4 -%>
repo --name="Extra Packages for Enterprise Linux" --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-<%= @host.operatingsystem.major %>&arch=<%= @host.architecture %>
<% if puppet_enabled && @host.params['enable-puppetlabs-repo'] && @host.params['enable-puppetlabs-repo'] == 'true' -%>
repo --name=puppetlabs-products --baseurl=http://yum.puppetlabs.com/el/<%= @host.operatingsystem.major %>/products/<%= @host.architecture %>
repo --name=puppetlabs-deps --baseurl=http://yum.puppetlabs.com/el/<%= @host.operatingsystem.major %>/dependencies/<%= @host.architecture %>
<% end -%>
<% end -%>

<% if @host.operatingsystem.name == 'Fedora' and os_major <= 16 -%>
# Bootloader exception for Fedora 16:
bootloader --append="nofb quiet splash=quiet <%=ks_console%>" <%= grub_pass %>
part biosboot --fstype=biosboot --size=1
<% else -%>
bootloader --location=mbr --append="nofb quiet splash=quiet" <%= grub_pass %>
<% end -%>

<% if @dynamic -%>
%include /tmp/diskpart.cfg
<% else -%>
<%= @host.diskLayout %>
<% end -%>

text
reboot

%packages --ignoremissing
yum
dhclient
ntp
wget
@Core
epel-release
<% if puppet_enabled %>
puppet
<% if @host.params['enable-puppetlabs-repo'] && @host.params['enable-puppetlabs-repo'] == 'true' -%>
puppetlabs-release
<% end -%>
<% end -%>
%end

<% if @dynamic -%>
%pre
<%= @host.diskLayout %>
%end
<% end -%>

%post --nochroot
exec < /dev/tty3 > /dev/tty3
#changing to VT 3 so that we can see whats going on....
/usr/bin/chvt 3
(
cp -va /etc/resolv.conf /mnt/sysimage/etc/resolv.conf
/usr/bin/chvt 1
) 2>&1 | tee /mnt/sysimage/root/install.postnochroot.log
%end

%post
logger "Starting anaconda <%= @host %> postinstall"
exec < /dev/tty3 > /dev/tty3
#changing to VT 3 so that we can see whats going on....
/usr/bin/chvt 3
(
#update local time
echo "updating system time"
/usr/sbin/ntpdate -sub <%= @host.params['ntp-server'] || '0.fedora.pool.ntp.org' %>
/usr/sbin/hwclock --systohc

# setup SSH key for root user
<%= snippet 'ssh_public_key' %>

<% if realm_incompatible && @host.info["parameters"]["realm"] && @host.otp && @host.realm && @host.realm.realm_type == "Red Hat Directory Server" -%>
<%= snippet "freeipa_register" %>
<% end -%>

# update all the base packages from the updates repository
yum -t -y -e 0 update

<% if puppet_enabled %>
echo "Configuring puppet"
cat > /etc/puppet/puppet.conf << EOF
<%= snippet 'puppet.conf' %>
EOF

# Setup puppet to run on system reboot
/sbin/chkconfig --level 345 puppet on

/usr/bin/puppet agent --config /etc/puppet/puppet.conf -o --tags no_such_tag <%= @host.puppetmaster.blank? ? '' : "--server #{@host.puppetmaster}" %> --no-daemonize

<% end -%>

sync

# Inform the build system that we are done.
echo "Informing Foreman that we are built"
wget -q -O /dev/null --no-check-certificate <%= foreman_url %>
# Sleeping an hour for debug
) 2>&1 | tee /root/install.post.log
exit 0

%end
EOS
  end

  def template
    <<EOS
DEFAULT menu
PROMPT 0
MENU TITLE PXE Menu
TIMEOUT 200
TOTALTIMEOUT 6000
ONTIMEOUT discovery

LABEL discovery
MENU LABEL Foreman Discovery
KERNEL boot/#{@kernel}
APPEND rootflags=loop initrd=boot/#{@initrd} root=live:/foreman.iso rootfstype=auto ro rd.live.image rd.live.check rd.lvm=0 rootflags=ro crashkernel=128M elevator=deadline max_loop=256 rd.luks=0 rd.md=0 rd.dm=0 foreman.url=#{@foreman_url} nomodeset selinux=0 stateless
IPAPPEND 2
EOS
  end

  def ssh_public_key_snippet
    <<'EOS'
mkdir --mode=700 /root/.ssh
cat >> /root/.ssh/authorized_keys << PUBLIC_KEY
<%= @host.params['ssh_public_key'] %>
PUBLIC_KEY
chmod 600 /root/.ssh/authorized_keys
EOS
  end

  def redhat_register_snippet
    <<'EOS'
<%#
kind: snippet
name: redhat_register
%>
# Red Hat Registration Snippet
#
# Set these parameters if you're using rhnreg_ks:
#
#   spacewalk_type = 'site'     (local Spacewalk/Satellite server)
#                  = 'hosted'   (RHN hosted)
#   spacewalk_host = <hostname> (hostname of Spacewalk server, optional for
#                                RHN hosted)
#
# Set these parameters if you're using subscription-manager:
#
#   subscription_manager = 'true' (you're going to use subscription-manager)
#
#   subscription_manager_username = <username> (if using hosted RHN)
#
#   subscription_manager_password = <password> (if using hosted RHN)
#
#   subscription_manager_host = <hostname> (hostname of SAM/Katello
#                                           installation, if using SAM)
#
#   subscription_manager_org = <org name> (organization name, if using
#                                          SAM/Katello)
#
#   subscription_manager_repos = <repos> (comma separated list of repos (like
#                                         rhel-6-server-optional-rpms) to
#                                         enable after registration)
#
#   subscription_manager_pool = <pool> (specific pool to be used for
#                                       registration)
#
# Set this parameter regardless of which registration method you're using:
#
#   activation_key = <key>      (activation key string, not needed if using
#                                subscription-manager with hosted RHN)
#

<% unless @host.params['subscription_manager'] %>
  <% type = @host.params['spacewalk_type'] || 'hosted' %>

  <% if @host.params['activation_key'] %>
    # Discovered Activation Key <%= @host.params['activation_key'] %>
    rhn_activation_key="<%= @host.params['activation_key'] -%>"

    <% if type == "site" -%>
    satellite_hostname="<%= @host.params['spacewalk_host'] -%>"
    rhn_cert_file="RHN-ORG-TRUSTED-SSL-CERT"
    <% else -%>
    satellite_hostname="<%= @host.params['spacewalk_host'] || 'xmlrpc.rhn.redhat.com' -%>"
    rhn_cert_file="RHNS-CA-CERT"
    <% end -%>

    echo "Registering to RHN Satellite at [$satellite_hostname]"
    echo "Using Registration Key [$rhn_activation_key]"

    <% if type == 'site' -%>
    # Obtain our RHN Satellite Certificate
    echo "Obtaining RHN SSL certificate"
    wget http://$satellite_hostname/pub/$rhn_cert_file -O /usr/share/rhn/$rhn_cert_file
    <% end -%>

    # Update our up2date configuration file
    echo "Updating SSL CA Certificate to /usr/share/rhn/$rhn_cert_file"
    sed -i -e "s|^sslCACert=.*$|sslCACert=/usr/share/rhn/$rhn_cert_file|" /etc/sysconfig/rhn/up2date

    # Update our Satellite Hostname
    echo "Updating Satellite Hostname to [$satellite_hostname]"
    sed -i -e "s|^serverURL=.*$|serverURL=https://$satellite_hostname/XMLRPC|" /etc/sysconfig/rhn/up2date
    sed -i -e "s|^noSSLServerURL=.*$|noSSLServerURL=https://$satellite_hostname/XMLRPC|" /etc/sysconfig/rhn/up2date

    # Restart messagebus/HAL to try and prevent hardware detection errors in rhnreg_ks
    echo "Restarting services..."
    service messagebus restart
    service hald restart

    # Now, perform our registration
    #  (might get hardware errors here, due to dbus/messagebus lameness. These are safe to ignore.)
    echo -n "Performing RHN Registration... "
    rhnreg_ks --activationkey=$rhn_activation_key
    echo "done."

    # Check we registered
    echo -n "Checking System Registration... "
    if ! rhn_check; then
        echo "FAILED"
        echo " >> RHN Registration FAILED. Please Investigate. <<"
    else
        echo "registration successful."
    fi
  <% else %>
    # Not registering - host.params['activation_key'] not found.
  <% end %>
<% else %>
  echo "Starting the subscription-manager registration process"
  <% if @host.params['subscription_manager_username'] && @host.params['subscription_manager_password'] %>
    subscription-manager register --username="<%= @host.params['subscription_manager_username'] %>" --password="<%= @host.params['subscription_manager_password'] %>" --auto-attach
    <% if @host.params['subscription_manager_pool'] %>
      subscription-manager attach --pool="<%= @host.params['subscription_manager_pool'] %>"
    <% end %>
    # workaround for RHEL 6.4 bug https://bugzilla.redhat.com/show_bug.cgi?id=1008016
    subscription-manager repos --list > /dev/null
    <% (enabled_repos = "subscription-manager repos --enable #{@host.params['subscription_manager_repos'].gsub(',', ' ')}") if @host.params['subscription_manager_repos'] %>
    <%= enabled_repos if enabled_repos %>
  <% elsif @host.params['activation_key'] %>
    rpm -Uvh <%= @host.params['subscription_manager_host'] %>/pub/candlepin-cert-consumer-latest.noarch.rpm
    subscription-manager register --org="<%= @host.params['subscription_manager_org'] %>" --activationkey="<%= @host.params['activation_key'] %>"
    # workaround for RHEL 6.4 bug https://bugzilla.redhat.com/show_bug.cgi?id=1008016
    subscription-manager repos --list > /dev/null
    <% (enabled_repos = "subscription-manager repos --enable #{@host.params['subscription_manager_repos'].gsub(',', ' ')}") if @host.params['subscription_manager_repos'] %>
    <%= enabled_repos if enabled_repos %>
  <% else %>
    # Not registering host.params['activation_key'] not found.
  <% end %>
<% end %>
# End Red Hat Registration Snippet
EOS
  end

end
