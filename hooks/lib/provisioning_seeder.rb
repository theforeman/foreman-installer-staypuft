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
    @ntp_host = kafo.param('foreman_plugin_staypuft', 'ntp_host').value
    @timezone = kafo.param('foreman_plugin_staypuft', 'timezone').value
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
                                                     'tftp_id' => default_proxy['id'],
                                                     'boot_mode' => 'DHCP'})

    kinds = @foreman.template_kind.index
    provisioning = kinds.detect { |k| k['name'] == 'provision' }
    pxe_linux = kinds.detect { |k| k['name'] == 'PXELinux' }
    @foreman.config_template.show_or_ensure({'id' => 'redhat_register'},
                                            {'template' => redhat_register_snippet, 'snippet' => '1', 'name' => 'redhat_register'})
    @foreman.config_template.show_or_ensure({'id' => 'custom_deployment_repositories'},
                                            {'template' => custom_deployment_repositories_snippet, 'snippet' => '1', 'name' => 'custom_deployment_repositories'})
    @foreman.config_template.show_or_ensure({'id' => 'Kickstart RHEL default'},
                                            {'template' => kickstart_rhel_default, 'template_kind_id' => provisioning['id'], 'name' => 'Kickstart RHEL default'})
    @foreman.config_template.show_or_ensure({'id' => 'Kickstart default'},
                                            {'template' => kickstart_default, 'template_kind_id' => provisioning['id'], 'name' => 'Kickstart default'})
    @foreman.config_template.show_or_ensure({'id' => 'Kickstart default PXELinux'},
                                            {'template' => kickstart_default_pxelinux, 'template_kind_id' => pxe_linux['id'], 'name' => 'Kickstart default PXELinux'})
    @foreman.config_template.show_or_ensure({'id' => 'ssh_public_key'},
                                            {'template' => ssh_public_key_snippet, 'snippet' => '1', 'name' => 'ssh_public_key'})
    @foreman.config_template.show_or_ensure({'id' => 'kickstart_networking_setup'},
                                            {'template' => kickstart_networking_setup_snippet, 'snippet' => '1', 'name' => 'kickstart_networking_setup'})

    @foreman.partition_table.show_or_ensure({'id' => 'LVM with cinder-volumes',
                                             'name' => 'LVM with cinder-volumes',
                                             'layout' => lvm_w_cinder_volumes,
                                             'os_family' => 'Redhat'}, {})

    @foreman.partition_table.show_or_ensure({'id' => 'OpenStack Default',
                                             'name' => 'OpenStack Default',
                                             'layout' => openstack_lvm,
                                             'os_family' => 'Redhat'}, {})

    name = 'PXELinux global default'
    pxe_template = @foreman.config_template.show_or_ensure({'id' => name},
                                                           {'template' => template})

    @foreman.config_template.build_pxe_default

    @hostgroups = []
    oses = find_default_oses(foreman_host)
    oses.each do |os|
      next if os['name'] == 'RedHat' && os['major'] == '6' # we don's support RHEL6 for provisioning anymore
      next if os['name'] == 'CentOS' && os['major'] == '6' # we don's support CentOS6 for provisioning anymore

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
      ptable = assign_partition_tables(os)

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
      @foreman.parameter.show_or_ensure({'id' => 'ntp-server', 'operatingsystem_id' => os['id']},
                                        {
                                            'name' => 'ntp-server',
                                            'value' => @ntp_host,
                                        })
      @foreman.parameter.show_or_ensure({'id' => 'time-zone', 'operatingsystem_id' => os['id']},
                                        {
                                            'name' => 'time-zone',
                                            'value' => @timezone,
                                        })
      @hostgroups.push hostgroup
    end

    default_hostgroup = @hostgroups.last
    setup_setting(default_hostgroup)
    setup_idle_timeout
    setup_default_root_pass
    setup_ignore_puppet_facts_for_provisioning
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
                                    {'value' => @foreman.version.start_with?('1.6') ? 180 : '180'})
  rescue NoMethodError => e
    @logger.error "Setting with name 'idle_timeout' not found, you must run 'foreman-rake db:seed' " +
                      "and rerun installer to fix this issue."
  end

  def setup_ignore_puppet_facts_for_provisioning
    @foreman.setting.show_or_ensure({'id' => 'ignore_puppet_facts_for_provisioning'},
                                    {'value' => @foreman.version.start_with?('1.6') ? true : 'true'})
  rescue NoMethodError => e
    @logger.error "Setting with name 'ignore_puppet_facts_for_provisioning' not found, you must run 'foreman-rake db:seed' " +
                      "and rerun installer to fix this issue."

  end

  def setup_default_root_pass
    @foreman.setting.show_or_ensure({'id' => 'root_pass'},
                                    {'value' => @default_root_pass.to_s.crypt('$5$fm')})
  rescue NoMethodError => e
    @logger.error "Setting with name 'root_pass' not found, you must run 'foreman-rake db:seed' " +
                      "and rerun installer to fix this issue."
  end

  def assign_partition_tables(os)
    if os['family'] == 'Redhat'
      default_ptable_name = 'OpenStack Default'
      additional_ptables_names = ['LVM with cinder-volumes']
    elsif os['family'] == 'Debian'
      default_ptable_name = 'Preseed default'
      additional_ptable_names = []
    end
    default_ptable = nil
    additional_ptables_names.push(default_ptable_name).each do |ptable_name|
      ptable = @foreman.partition_table.first! %Q(name ~ "#{ptable_name}*")
      default_ptable = ptable if default_ptable_name == ptable['name']
      if os['ptables'].nil? || os['ptables'].empty?
        ids = @foreman.partition_table.show!('id' => ptable['id'])['operatingsystems'].map { |o| o['id'] }
        @foreman.partition_table.update 'id' => ptable['id'], 'ptable' => {'operatingsystem_ids' => (ids + [os['id']]).uniq}
      end
    end
    default_ptable
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

<% subnet = @host.subnet -%>
<% dhcp = subnet.dhcp_boot_mode? -%>
network --bootproto <%= dhcp ? 'dhcp' : "static --ip=#{@host.ip} --netmask=#{subnet.mask} --gateway=#{subnet.gateway} --nameserver=#{[subnet.dns_primary, subnet.dns_secondary].select(&:present?).join(',')}" %> --device=<%= @host.mac -%> --hostname <%= @host %>

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

%include /tmp/diskpart.cfg

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

%pre
cat > /tmp/diskpart.cfg << EOF
<%= @host.diskLayout %>
EOF

# ensures a valid disk is addressed in the partition table layout
# sda is assumed and replaced if it is not correct
sed -i "s/sda/$(cat /proc/partitions | awk '{ print $4 }' | grep -e "^.d.$" | sort | head -1)/" /tmp/diskpart.cfg
%end

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
<%= snippet 'kickstart_networking_setup' %>

#update local time
echo "updating system time"
/usr/sbin/ntpdate -sub <%= @host.params['ntp-server'] || '0.fedora.pool.ntp.org' %>
/usr/sbin/hwclock --systohc

#disable NetworkManager and enable network
chkconfig NetworkManager off
chkconfig network on

# setup SSH key for root user
<%= snippet 'ssh_public_key' %>

<%= snippet 'redhat_register' %>
<%= snippet 'custom_deployment_repositories' %>

<% if @host.info["parameters"]["realm"] && @host.otp && @host.realm && @host.realm.realm_type == "Red Hat Directory Server" && os_major <= 6 -%>
<%= snippet "freeipa_register" %>
<% end -%>

# update all the base packages from the updates repository
yum -t -y -e 0 update

# ensure firewalld is absent (BZ#1125075)
yum -t -y -e 0 remove firewalld

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

<% subnet = @host.subnet -%>
<% dhcp = subnet.dhcp_boot_mode? -%>
network --bootproto <%= dhcp ? 'dhcp' : "static --ip=#{@host.ip} --netmask=#{subnet.mask} --gateway=#{subnet.gateway} --nameserver=#{[subnet.dns_primary, subnet.dns_secondary].select(&:present?).join(',')}" %> --device=<%= @host.mac -%> --hostname <%= @host %>

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
<%= snippet 'kickstart_networking_setup' %>
<%= snippet 'custom_deployment_repositories' %>

# get name of provisioning interface
PROVISION_IFACE=$(ip route  | awk '$1 == "default" {print $5}' | head -1)
echo "found provisioning interface = $PROVISION_IFACE"

<% if @host.hostgroup.to_s.include?("Controller") %>
echo "setting DEFROUTE=no on $PROVISION_IFACE"
sed -i '
    /DEFROUTE/ d
    $ a\DEFROUTE=no
' /etc/sysconfig/network-scripts/ifcfg-$PROVISION_IFACE
<% end -%>

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

# ensure firewalld is absent (BZ#1125075)
yum -t -y -e 0 remove firewalld

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
APPEND rootflags=loop initrd=boot/#{@initrd} root=live:/foreman.iso rootfstype=auto ro rd.live.image rd.live.check rd.lvm=0 rootflags=ro crashkernel=128M elevator=deadline max_loop=256 rd.luks=0 rd.md=0 rd.dm=0 foreman.url=#{@foreman_url} nomodeset selinux=0 stateless biosdevname=0
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

  def custom_deployment_repositories_snippet
    <<'EOS'
# custom deployment repositories
<% if @host.deployment.has_custom_repos? -%>
yum -t -y -e 0 install yum-plugin-priorities
<% i = 0 -%>
<% @host.deployment.custom_repos_paths.each do |path| -%>
<% i +=1 -%>
cat > /etc/yum.repos.d/staypuft_custom_<%= i -%>.repo << EOF
[staypuft_custom_<%= i -%>]
name=Staypuft custom repository <%= i %>
baseurl=<%= path %>
gpgcheck=0
priority=50
enabled=1
EOF
<% end %>
<% end %>
EOS
  end

  def kickstart_networking_setup_snippet
    <<'EOS'
<%#
kind: snippet
name: kickstart_networking_setup
description: this will configure your host networking, it configures your primary interface as well
    as other configures NICs. It supports physical, VLAN and Alias interfaces. It's intended to be
    called from %post in your kickstart template
%>
<% subnet = @host.subnet -%>
<% dhcp = subnet.dhcp_boot_mode? -%>

# primary interface
real=`ip -o link | grep <%= @host.mac -%> | awk '{print $2;}' | sed s/://`
<% if @host.has_primary_interface? %>
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$real
BOOTPROTO="<%= dhcp ? 'dhcp' : 'none' -%>"
<% unless dhcp -%>
IPADDR="<%= @host.ip -%>"
NETMASK="<%= subnet.mask -%>"
GATEWAY="<%= subnet.gateway -%>"
<% end -%>
DEVICE="$real"
HWADDR="<%= @host.mac -%>"
ONBOOT=yes
DEFROUTE=no
EOF
<% end -%>

<% bonded_interfaces = [] %>
<% bonds = @host.bond_interfaces %>
<% bonds.each do |bond| %>
<% subnet = bond.subnet -%>
<% dhcp = subnet.nil? ? false : subnet.dhcp_boot_mode? -%>
# <%= bond.identifier %> interface
real="<%= bond.identifier -%>"
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$real
BOOTPROTO="<%= dhcp ? 'dhcp' : 'none' -%>"
<% unless dhcp || subnet.nil? -%>
IPADDR="<%= bond.ip -%>"
NETMASK="<%= subnet.mask -%>"
GATEWAY="<%= subnet.gateway -%>"
<% end -%>
DEVICE="$real"
ONBOOT=yes
PEERDNS=no
PEERROUTES=no
DEFROUTE=no
TYPE=Bond
BONDING_OPTS="<%= bond.bond_options -%> mode=<%= bond.mode -%>"
BONDING_MASTER=yes
NM_CONTROLLED=no
EOF

<% @host.interfaces_with_identifier(bond.attached_devices_identifiers).each do |interface| -%>
<% next if !interface.managed? -%>

<% subnet = interface.subnet -%>
<% virtual = interface.virtual? -%>
<% vlan = virtual && subnet.has_vlanid? -%>
<% alias_type = virtual && !subnet.nil? && !subnet.has_vlanid? && interface.identifier.include?(':') -%>
<% dhcp = !subnet.nil? && subnet.dhcp_boot_mode? -%>

# <%= interface.identifier %> interface
real=`ip -o link | grep <%= interface.mac -%> | awk '{print $2;}' | sed s/:$//`
<% if virtual -%>
real=`echo <%= interface.identifier -%> | sed s/<%= interface.attached_to -%>/$real/`
<% end -%>

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$real
BOOTPROTO="none"
DEVICE="$real"
<% unless virtual -%>
HWADDR="<%= interface.mac -%>"
<% end -%>
ONBOOT=yes
PEERDNS=no
PEERROUTES=no
<% if vlan -%>
VLAN=yes
<% elsif alias_type -%>
TYPE=Alias
<% end -%>
NM_CONTROLLED=no
MASTER=<%= bond.identifier %>
SLAVE=yes
DEFROUTE=no
EOF

<% bonded_interfaces.push(interface.identifier) -%>
<% end %>
<% end %>

<% @host.managed_interfaces.each do |interface| %>
<% next if !interface.managed? || interface.subnet.nil? -%>
<% next if bonded_interfaces.include?(interface.identifier) -%>

<% subnet = interface.subnet -%>
<% virtual = interface.virtual? -%>
<% vlan = virtual && subnet.has_vlanid? -%>
<% alias_type = virtual && !subnet.has_vlanid? && interface.identifier.include?(':') -%>
<% dhcp = subnet.dhcp_boot_mode? -%>

# <%= interface.identifier %> interface
real=`ip -o link | grep <%= interface.mac -%> | awk '{print $2;}' | sed s/:$//`
<% if virtual -%>
real=`echo <%= interface.identifier -%> | sed s/<%= interface.attached_to -%>/$real/`
<% end -%>

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$real
BOOTPROTO="<%= dhcp ? 'dhcp' : 'none' -%>"
<% unless dhcp -%>
IPADDR="<%= interface.ip -%>"
NETMASK="<%= subnet.mask -%>"
GATEWAY="<%= subnet.gateway -%>"
<% end -%>
DEVICE="$real"
<% unless virtual -%>
HWADDR="<%= interface.mac -%>"
<% end -%>
ONBOOT=yes
PEERDNS=no
PEERROUTES=no
<% if vlan -%>
VLAN=yes
<% elsif alias_type -%>
TYPE=Alias
<% end -%>
NM_CONTROLLED=no
DEFROUTE=no
EOF

<% end %>

# get name of provisioning interface
PROVISION_IFACE=$(ip route  | awk '$1 == "default" {print $5}' | head -1)
echo "found provisioning interface = $PROVISION_IFACE"
DEFROUTE_IFACE=`ip -o link | grep <%= @host.network_query.gateway_interface_mac -%> | awk '{print $2;}' | sed s/:$//`
echo "found interface with default gateway = $DEFROUTE_IFACE"
<% gateway_interface = @host.network_query.gateway_interface
   gateway_is_vlan = @host.network_query.gateway_subnet.has_vlanid?
   bond_gateway_map = @host.bond_interfaces.map { |bond| bond.identifier == gateway_interface }
   gateway_is_bond = false
   bond_gateway_map.each do |is_gateway|
     next if gateway_is_bond
     gateway_is_bond = is_gateway
   end -%>

IFACES=$(ls -d /sys/class/net/* | while read iface; do readlink $iface | grep -q virtual || echo ${iface##*/}; done)
<% if gateway_is_vlan or gateway_is_bond -%>
IFACES="$IFACES <%= gateway_interface %>"
DEFROUTE_IFACE="<%= gateway_interface %>"
echo "gateway interface is a vlan and/or bond = $DEFROUTE_IFACE"
<% end -%>
for i in $IFACES; do
    sed -i 's/ONBOOT.*/ONBOOT=yes/' /etc/sysconfig/network-scripts/ifcfg-$i
    if [ "$i" != "$PROVISION_IFACE" ]; then
        echo "setting PEERDNS=no on $i"
        sed -i '
            /PEERDNS/ d
            $ a\PEERDNS=no
        ' /etc/sysconfig/network-scripts/ifcfg-$i
    fi

    if [ "$i" = "$DEFROUTE_IFACE" ]; then
        echo "setting DEFROUTE=yes on $i"
        sed -i '
            /DEFROUTE/ d
            $ a\DEFROUTE=yes
        ' /etc/sysconfig/network-scripts/ifcfg-$i
    fi
done

EOS
  end

  def lvm_w_cinder_volumes
    <<'EOS'
#Dynamic
zerombr
clearpart --all --initlabel
part biosboot --fstype=biosboot --size=1 --ondisk=sda
part /boot --fstype ext3 --size=500 --ondisk=sda
part swap --size=1024 --ondisk=sda
part pv.01 --size=1024 --grow --maxsize=102400 --ondisk=sda
part pv.02 --size=1024 --grow --ondisk=sda
volgroup vg_root pv.01
volgroup cinder-volumes pv.02
logvol  /  --vgname=vg_root  --size=1 --grow --name=lv_root
EOS
  end

  def openstack_lvm
    <<'EOS'
#Dynamic
zerombr
clearpart --all --initlabel
part biosboot --fstype=biosboot --size=1 --ondisk=sda
part /boot --fstype ext3 --size=500 --ondisk=sda
part swap --size=1024 --ondisk=sda
part pv.01 --size=1024 --grow --ondisk=sda
volgroup vg_root pv.01
logvol  /  --vgname=vg_root  --size=1 --grow --name=lv_root
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
#   http-proxy = <host> (proxy hostname to be used for registration)
#
#   http-proxy-port = <port> (proxy port to be used for registration)
#
#   http-proxy-user = <user> (proxy user to be used for registration)
#
#   http-proxy-password = <password> (proxy password to be
#                                           used for registration)
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
  <% if @host.params['http-proxy'] %>
    subscription-manager config --server.proxy_hostname="<%= @host.params['http-proxy'] %>"
    <% if @host.params['http-proxy-user'] %>
      subscription-manager config --server.proxy_user="<%= @host.params['http-proxy-user'] %>"
    <% end %>
    <% if @host.params['http-proxy-password'] %>
      subscription-manager config --server.proxy_password='<%= @host.params['http-proxy-password'] %>'
    <% end %>
    <% if @host.params['http-proxy-port'] %>
      subscription-manager config --server.proxy_port="<%= @host.params['http-proxy-port'] %>"
    <% end %>
  <% end %>
  <% if @host.params['subscription_manager_username'] && @host.params['subscription_manager_password'] %>
    <% if @host.params['subscription_manager_pool'] %>
      subscription-manager register --username='<%= @host.params['subscription_manager_username'] %>' --password='<%= @host.params['subscription_manager_password'] %>'
      subscription-manager attach --pool="<%= @host.params['subscription_manager_pool'] %>"
    <% else %>
      subscription-manager register --username="<%= @host.params['subscription_manager_username'] %>" --password="<%= @host.params['subscription_manager_password'] %>" --auto-attach
    <% end %>
    # workaround for RHEL 6.4 bug https://bugzilla.redhat.com/show_bug.cgi?id=1008016
    subscription-manager repos --list > /dev/null
    <%= "subscription-manager repos #{@host.params['subscription_manager_repos'].split(',').map { |r| '--enable=' + r.strip }.join(' ')}" if @host.params['subscription_manager_repos'] %>
  <% elsif @host.params['activation_key'] %>
    rpm -Uvh <%= @host.params['subscription_manager_host'] %>/pub/candlepin-cert-consumer-latest.noarch.rpm
    subscription-manager register --org="<%= @host.params['subscription_manager_org'] %>" --activationkey="<%= @host.params['activation_key'] %>"
    # workaround for RHEL 6.4 bug https://bugzilla.redhat.com/show_bug.cgi?id=1008016
    subscription-manager repos --list > /dev/null
    <%= "subscription-manager repos #{@host.params['subscription_manager_repos'].split(',').map { |r| '--enable=' + r.strip }.join(' ')}" if @host.params['subscription_manager_repos'] %>
  <% else %>
    # Not registering host.params['activation_key'] not found.
  <% end %>
<% end %>
# End Red Hat Registration Snippet
EOS
  end

  def kickstart_default_pxelinux
    <<'EOS'
<%#
kind: PXELinux
name: Kickstart default PXELinux
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
- RedHat 4
- RedHat 5
- RedHat 6
- RedHat 7
%>
default linux
label linux
kernel <%= @kernel %>
<% if @host.operatingsystem.name == 'Fedora' and @host.operatingsystem.major.to_i > 16 -%>
append initrd=<%= @initrd %> ks=<%= foreman_url('provision')%> ks.device=bootif network ks.sendmac
<% elsif @host.operatingsystem.name != 'Fedora' and @host.operatingsystem.major.to_i >= 7 -%>
append initrd=<%= @initrd %> ks=<%= foreman_url('provision')%> network ks.sendmac biosdevname=0
<% else -%>
append initrd=<%= @initrd %> ks=<%= foreman_url('provision')%> ksdevice=bootif network kssendmac
<% end -%>
IPAPPEND 2
EOS
  end
end
