require 'foreman_api'
require 'uri'

class BaseSeeder
  def initialize(kafo)
    @foreman_url = kafo.param('foreman_proxy', 'foreman_base_url').value
    param = kafo.param('foreman', 'admin_username')
    @username = param.nil? ? 'admin' : param.value
    param = kafo.param('foreman', 'admin_password')
    @password = param.nil? ? 'changeme' : param.value
    foreman

    @logger = kafo.logger

    @fqdn = URI.parse(@foreman_url).host # TODO rescue error
  end

  def foreman
    @foreman ||= Foreman.new(:base_url => @foreman_url, :username => @username, :password => @password)
  end

  private

  def find_default_oses(foreman_host)
    os = find_default_os(foreman_host)
    ([os] + additional_oses(os)).compact
  end

  def find_default_os(foreman_host)
    @foreman.operating_system.show! 'id' => foreman_host['operatingsystem_id'],
                                    :error_message => "operating system for #{@fqdn} not found, DB inconsitency?"
  end

  def additional_oses(os)
    additional = []
    if os['name'] == 'RedHat' && os['major'] == '6'
      additional << foreman.operating_system.show_or_ensure({'id' => 'RedHat 7.0',
                                                             'name' => 'RedHat', 'major' => '7', 'minor' => '0',
                                                             'family' => 'Redhat'}, {})
    end
    if os['name'] == 'CentOS' && os['major'] == '6'
      additional << foreman.operating_system.show_or_ensure({'id' => 'CentOS 7.0',
                                                             'name' => 'CentOS', 'major' => '7', 'minor' => '0',
                                                             'family' => 'Redhat'}, {})
    end
    additional
  end

  def find_foreman_host
    @foreman.host.show! 'id' => @fqdn,
                        :error_message => "host #{@fqdn} not found in foreman, puppet haven't run yet?"
  end

end
