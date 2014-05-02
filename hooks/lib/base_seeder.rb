require 'foreman_api'
require 'uri'

class BaseSeeder
  def initialize(kafo)
    @foreman_url = kafo.param('foreman_proxy', 'foreman_base_url').value
    @username = 'admin'
    @password = 'changeme'
    foreman

    @logger = kafo.logger

    @fqdn = URI.parse(@foreman_url).host # TODO rescue error
  end

  def foreman
    @foreman ||= Foreman.new(:base_url => @foreman_url, :username => @username, :password => @password)
  end

  private


  def find_default_os(foreman_host)
    @foreman.operating_system.show! 'id' => foreman_host['operatingsystem_id'],
                                    :error_message => "operating system for #{@fqdn} not found, DB inconsitency?"
  end

  def find_foreman_host
    @foreman.host.show! 'id' => @fqdn,
                        :error_message => "host #{@fqdn} not found in foreman, puppet haven't run yet?"
  end

end
