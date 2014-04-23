require 'foreman_api'
require 'ipaddr'
require 'uri'

class ProvisioningSeeder
  attr_accessor :domain, :fqdn

  def initialize(kafo)
    @domain = kafo.param('foreman_proxy', 'dns_zone').value
    @foreman_url = kafo.param('foreman_proxy', 'foreman_base_url').value
    @fqdn = URI.parse(@foreman_url).host # TODO rescue error
    @environment = kafo.param('foreman', 'environment').value
    @username = 'admin'
    @password = 'changeme'
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

    @logger = kafo.logger

    # Foreman singleton instance
    @foreman = Foreman.new(:base_url => @foreman_url, :username => @username, :password => @password)
  end

  def seed
    # setup part
    default_proxy = find_default_proxy
    default_environment = find_default_environment
    foreman_host = find_foreman_host
    os = find_default_os(foreman_host)
    medium = @foreman.installation_medium.index('search' => "name ~ #{os['name']}").first

    if os['architectures'].nil?
      @foreman.operating_system.update 'id' => os['id'],
                                       'operatingsystem' => {'architecture_ids' => [foreman_host['architecture_id']]}
    end

    if os['media'].nil?
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

    name = 'PXELinux global default'
    pxe_template = @foreman.config_template.show_or_ensure({'id' => name},
                                                           {'template' => template})

    @foreman.config_template.build_pxe_default

    ptable = assign_provisioning_templates(os)
    assign_partition_table(os)

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
    create_discovery_env(pxe_template)

    say HighLine.color("Your system is ready to provision using '#{default_hostgroup['name']}' hostgroup", :good)
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

  def assign_partition_table(os)
    if os['family'] == 'Redhat'
      ptable_name = 'Kickstart default'
    elsif os['family'] == 'Debian'
      ptable_name = 'Preseed default'
    end
    ptable = @foreman.partition_table.first! %Q(name ~ "#{ptable_name}*")
    if os['ptables'].nil?
      @foreman.partition_table.update 'id' => ptable['id'], 'ptable' => {'operatingsystem_ids' => [os['id']]}
    end
    ptable
  end

  def assign_provisioning_templates(os)
    # Default values used for provision template searching, some were renamed after 1.4
    if os['family'] == 'Redhat'
      tmpl_name = 'Kickstart default'
      provision_tmpl_name = os['name'] == 'Redhat' ? 'Kickstart RHEL default' : tmpl_name
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

  def find_default_os(foreman_host)
    @foreman.operating_system.show! 'id' => foreman_host['operatingsystem_id'],
                                    :error_message => "operating system for #{@fqdn} not found, DB inconsitency?"
  end

  def find_foreman_host
    @foreman.host.show! 'id' => @fqdn,
                        :error_message => "host #{@fqdn} not found in foreman, puppet haven't run yet?"
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
APPEND rootflags=loop initrd=boot/#{@initrd} root=live:/@foreman.iso rootfstype=auto ro rd.live.image rd.live.check rd.lvm=0 rootflags=ro crashkernel=128M elevator=deadline max_loop=256 rd.luks=0 rd.md=0 rd.dm=0 foreman.url=#{@foreman_url} nomodeset selinux=0 stateless
EOS
  end

end
