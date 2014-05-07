require 'ipaddr'

class ProvisioningSeeder < BaseSeeder
  attr_accessor :domain, :fqdn

  def initialize(kafo)
    super
    @domain = kafo.param('foreman_proxy', 'dns_zone').value
    @environment = kafo.param('foreman', 'environment').value

    wizard = kafo.config.app[:wizard]
    @netmask = wizard.netmask
    @network = wizard.network
    @ip = kafo.param('foreman_proxy', 'tftp_servername').value
    @from = wizard.from
    @to = wizard.to
    @gateway = kafo.param('foreman_proxy', 'dhcp_gateway').value
    @kernel = kafo.param('foreman_plugin_discovery', 'kernel').value
    @initrd = kafo.param('foreman_plugin_discovery', 'initrd').value
    @discovery_env_name = 'discovery'
    @default_root_pass = 'spengler'
  end

  def seed
    say HighLine.color("Starting to seed provisioning data", :good)
    default_proxy = find_default_proxy
    default_environment = find_default_environment
    foreman_host = find_foreman_host
    os = find_default_os(foreman_host)
    medium = @foreman.medium.index('search' => "name ~ #{os['name']}").first

    if os['architectures'].nil? || os['architectures'].empty?
      @foreman.operating_system.update 'id' => os['id'],
                                       'operatingsystem' => {'architecture_ids' => [foreman_host['architecture_id']]}
    end

    if os['media'].nil? || os['media'].empty?
      @foreman.operating_system.update 'id' => os['id'], 'operatingsystem' => {'medium_ids' => [medium['id']]}
    end

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

    name = 'PXELinux global default'
    pxe_template = @foreman.config_template.show_or_ensure({'id' => name},
                                                           {'template' => template})

    @foreman.config_template.build_pxe_default

    assign_provisioning_templates(os)
    ptable = assign_partition_table(os)

    default_hostgroup = @foreman.hostgroup.show_or_ensure({'id' => 'base'},
                                                          {'name' => 'base',
                                                           'architecture_id' => foreman_host['architecture_id'],
                                                           'domain_id' => default_domain['id'],
                                                           'environment_id' => default_environment['id'],
                                                           'medium_id' => medium['id'],
                                                           'operatingsystem_id' => os['id'],
                                                           'ptable_id' => ptable['id'],
                                                           'puppet_ca_proxy_id' => default_proxy['id'],
                                                           'puppet_proxy_id' => default_proxy['id'],
                                                           'subnet_id' => default_subnet['id']})

    setup_setting(default_hostgroup)
    setup_default_root_pass
    create_discovery_env(pxe_template)

    say HighLine.color("Use '#{default_hostgroup['name']}' hostgroup for provisioning", :good)
  end

  private

  def create_discovery_env(template)
    env = @foreman.environment.show_or_ensure({'id' => @discovery_env_name},
                                              {'name' => @discovery_env_name})
    # if the template has combination already, we don't update it
    unless template['template_combinations'].any? {|c| c['environment_id'] == env['id'].to_i and c['hostgroup_id'].nil? }
      @foreman.config_template.update 'id' => template['name'],
                                      'config_template' => { 'template_combinations_attributes' => [ {'environment_id' => env['id']} ] }
    end
  end

  def setup_setting(default_hostgroup)
    @foreman.setting.show_or_ensure({'id' => 'base_hostgroup'},
                                    {'value' => default_hostgroup['name'].to_s})
  rescue NoMethodError => e
    @logger.error "Setting with name 'base_hostgroup' not found, you must run 'foreman-rake db:seed' " +
                      "and rerun installer to fix this issue."
  end

  def setup_default_root_pass
    @foreman.setting.show_or_ensure({'id' => 'root_pass'},
                                    {'value' => @default_root_pass})
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
      @foreman.partition_table.update 'id' => ptable['id'], 'ptable' => {'operatingsystem_ids' => [os['id']]}
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

      # if there's no provisioning template for this os found it means, it's not associated so we add relation
      assigned_tmpl = @foreman.config_template.first %Q(name ~ "#{tmpl_name}*" and kind = #{kind_name} and operatingsystem = "#{os['name']}")
      if assigned_tmpl.nil?
        @foreman.config_template.update 'id' => tmpl['id'], 'config_template' => {'operatingsystem_ids' => [os['id']]}
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
  yum -t -y -e 0 install subscription-manager yum-utils
  <% (enabled_repos = "yum-config-manager --enable #{@host.params['subscription_manager_repos'].gsub(',', ' ')}") if @host.params['subscription_manager_repos'] %>
  <% if @host.params['subscription_manager_username'] && @host.params['subscription_manager_password'] %>
    subscription-manager register --username="<%= @host.params['subscription_manager_username'] %>" --password="<%= @host.params['subscription_manager_password'] %>" --auto-attach
    <% if @host.params['subscription_manager_pool'] %>
      subscription-manager attach --pool="<%= @host.params['subscription_manager_pool'] %>"
    <% end %>
    # workaround for RHEL 6.4 bug https://bugzilla.redhat.com/show_bug.cgi?id=1008016
    subscription-manager repos --list > /dev/null
    <%= enabled_repos if enabled_repos %>
  <% elsif @host.params['activation_key'] %>
    rpm -Uvh <%= @host.params['subscription_manager_host'] %>/pub/candlepin-cert-consumer-latest.noarch.rpm
    subscription-manager register --org="<%= @host.params['subscription_manager_org'] %>" --activationkey="<%= @host.params['activation_key'] %>"
    # workaround for RHEL 6.4 bug https://bugzilla.redhat.com/show_bug.cgi?id=1008016
    subscription-manager repos --list > /dev/null
    <%= enabled_repos if enabled_repos %>
  <% else %>
    # Not registering host.params['activation_key'] not found.
  <% end %>
<% end %>
# End Red Hat Registration Snippet
EOS
  end

end
