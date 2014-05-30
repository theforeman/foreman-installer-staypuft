require 'resolv'

class ProvisioningWizard < BaseWizard
  def self.attrs
    {
        :interface => 'Network interface',
        :ip => 'IP address',
        :netmask => 'Network mask',
        :network => 'Network address',
        :own_gateway => 'Host Gateway',
        :from => 'DHCP range start',
        :to => 'DHCP range end',
        :gateway => 'DHCP Gateway',
        :dns => 'DNS forwarder',
        :domain => 'Domain',
        :base_url => 'Foreman URL',
        :ntp_host => 'NTP sync host',
        :timezone => 'Timezone',
        :configure_networking => 'Configure networking on this machine',
        :configure_firewall => 'Configure firewall on this machine'
    }
  end

  def self.order
    %w(interface ip netmask network own_gateway from to gateway dns domain base_url ntp_host timezone configure_networking configure_firewall)
  end

  def self.custom_labels
    {
        :configure_networking => 'Configure networking',
        :configure_firewall => 'Configure firewall'
    }
  end

  attr_accessor *attrs.keys

  def initialize(*args)
    super
    self.header = 'Networking setup:'
    self.help = "The installer can configure the networking and firewall rules on this machine with the above configuration. Default values are populated from the this machine's existing networking configuration.\n\nIf you DO NOT want to configure networking please set 'Configure networking on this machine' to No before proceeding. Do this by selecting option 'Do not configure networking' from the list below."
    self.allow_cancellation = true
  end

  def start
    get_interface if @interface.nil? || !interfaces.has_key?(@interface)
    super
  end

  def get_configure_networking
    self.configure_networking = !configure_networking
  end

  def get_configure_firewall
    self.configure_firewall = !configure_firewall
  end

  def get_timezone
    @timezone = ask('Enter an IANA timezone identifier (e.g. America/New_York, Pacific/Auckland, UTC)')
  end

  def base_url
    @base_url ||= "https://#{Facter.value :fqdn}"
  end

  def domain
    @domain ||= Facter.value :domain
  end

  def dns
    @dns ||= begin
      line = File.read('/etc/resolv.conf').split("\n").detect { |line| line =~ /nameserver\s+.*/ }
      line.split(' ').last || ''
    rescue
      ''
    end
  end

  def own_gateway
    @own_gateway ||= `ip route | awk '/default/{print $3}'`.chomp
  end

  def gateway
    @gateway ||= @ip
  end

  def netmask=(mask)
    if mask.to_s.include?('/')
      mask_len = mask.split('/').last.to_i
      mask = IPAddr.new('255.255.255.255').mask(mask_len).to_s
    end
    @netmask = mask
  end

  def ntp_host
    @ntp_host ||= '1.centos.pool.ntp.org'
  end

  def timezone
    @timezone ||= current_system_timezone
  end

  def validate_interface
    'Interface must be present' if @interface.nil? || @interface.empty?
  end

  def print_pair(name, value)
    value = case
              when value.is_a?(TrueClass)
                HighLine.color(Kafo::Wizard::OK, :run)
              when value.is_a?(FalseClass)
                HighLine.color(Kafo::Wizard::NO, :cancel)
              else
                "'#{HighLine.color(value.to_s, :info)}'"
            end

    say "#{name}:".rjust(25) + " #{value}"
  end

  def get_ready
    choose do |menu|
      menu.header = HighLine.color("\nIs the networking correct?", :important)
      menu.prompt = ''
      menu.select_by = :index
      menu.choice(HighLine.color('Yes, move on!', :run)) { false }
      ORDER.each do |attr|
        name = NIC_ATTRS[attr.to_sym]
        menu.choice("No, change #{name}") { attr.to_sym }
      end
      menu.choice(HighLine.color('No, cancel installation', :cancel)) { @kafo.class.exit(100) }
    end
  rescue Interrupt
    @logger.debug "Got interrupt, exiting"
    @kafo.class.exit(100)
  end

  def validate_ip
    'IP address is invalid' unless valid_ip?(@ip)
  end

  def validate_netmask
    'Network mask is invalid' unless valid_ip?(@netmask)
  end

  def validate_network
    'Network address is invalid' unless valid_ip?(@network)
  end

  def validate_own_gateway
    'Host Gateway is invalid' unless valid_ip?(@own_gateway)
  end

  def validate_from
    'DHCP range start is invalid' unless valid_ip?(@from)
  end

  def validate_to
    'DHCP range end is invalid' unless valid_ip?(@to)
  end

  def validate_gateway
    'DHCP Gateway is invalid' unless valid_ip?(@gateway)
  end

  def validate_dns
    'DNS forwarder is invalid' unless valid_ip?(@dns)
  end

  def validate_domain
    'Domain must be present' if @domain.nil? || @domain.empty?
  end

  def validate_base_url
    'Foreman URL must be present' if @base_url.nil? || @base_url.empty?
  end

  def validate_ntp_host
    'NTP sync host' if @ntp_host.nil? || @ntp_host.empty?
  end

  def validate_timezone
    'Timezone is not a valid IANA timezone identifier' unless valid_timezone?(@timezone)
  end

  private

  def get_interface
    case interfaces.size
      when 0
        HighLine.color("\nFacter didn't find any NIC, can not continue", :bad)
        raise StandardError
      when 1
        @interface = interfaces.keys.first
      else
        @interface = choose do |menu|
          menu.header = HighLine.color("\nPlease select NIC on which you want provisioning enabled", :important)
          interfaces.keys.sort.each do |nic|
            menu.choice nic
          end
        end
    end

    setup_networking
  end

  def setup_networking
    @ip = interfaces[@interface][:ip]
    @network = interfaces[@interface][:network]
    @netmask = interfaces[@interface][:netmask]
    @cidr = interfaces[@interface][:cidr]
    @from = interfaces[@interface][:from]
    @to = interfaces[@interface][:to]
  end

  def interfaces
    @interfaces ||= (Facter.value :interfaces || '').split(',').reject { |i| i == 'lo' }.inject({}) do |ifaces, i|
      ip = Facter.value "ipaddress_#{i}"
      network = Facter.value "network_#{i}"
      netmask = Facter.value "netmask_#{i}"

      cidr, from, to = nil, nil, nil
      if ip && network && netmask
        cidr = "#{network}/#{IPAddr.new(netmask).to_i.to_s(2).count('1')}"
        from = IPAddr.new(ip).succ.to_s
        to = IPAddr.new(cidr).to_range.entries[-2].to_s
      end

      ifaces[fix_interface_name(i)] = {:ip => ip, :netmask => netmask, :network => network, :cidr => cidr, :from => from, :to => to, :gateway => gateway}
      ifaces
    end
  end

  # facter can't distinguish between alias and vlan interface so we have to check and fix the eth0_0 name accordingly
  # if it's a vlan, the name should be eth0.0, otherwise it's alias and the name is eth0:0
  # if both are present (unlikly) facter overwrites attriutes and we can't fix it
  def fix_interface_name(facter_name)
    if facter_name.include?('_')
      ['.', ':'].each do |separator|
        new_facter_name = facter_name.tr('_', separator)
        return new_facter_name if system("ifconfig #{new_facter_name} &> /dev/null")
      end

      # if ifconfig failed, we fallback to /sys/class/net detection, aliases are not listed there
      new_facter_name = facter_name.tr('_', '.')
      return new_facter_name if File.exists?("/sys/class/net/#{new_facter_name}")
    end
    facter_name
  end

  def valid_ip?(ip)
    !!(ip =~ Resolv::IPv4::Regex)
  end

  # NOTE(jistr): currently we only have tzinfo for ruby193 scl and
  # this needs to run on system ruby, so i implemented a custom
  # timezone validation (not extremely strict - it's not filtering
  # zoneinfo subdirectories etc., but it should catch typos well,
  # which is what we care about)
  def valid_timezone?(timezone)
    zoneinfo_file_names = %x(/bin/find /usr/share/zoneinfo -type f).lines
    zones = zoneinfo_file_names.map { |name| name.strip.sub('/usr/share/zoneinfo/', '') }
    zones.include? timezone
  end

  def current_system_timezone
    if File.exists?('/usr/bin/timedatectl')  # systems with systemd
      # timezone_line will be like 'Timezone: Europe/Prague (CEST, +0200)'
      timezone_line = %x(/usr/bin/timedatectl status | grep "Timezone: ").strip
      return timezone_line.match(/Timezone: ([^ ]*) /)[1]
    else  # systems without systemd
      # timezone_line will be like 'ZONE="Europe/Prague"'
      timezone_line = %x(/bin/cat /etc/sysconfig/clock | /bin/grep '^ZONE=').strip
      # don't rely on single/double quotes being present
      return timezone_line.gsub('ZONE=', '').gsub('"','').gsub("'",'')
    end
  rescue StandardError => e
    # Don't allow this function to crash the installer.
    # Worst case we'll just return UTC.
    @logger.debug("Exception when getting system time zone: #{e.message}")
    return 'UTC'
  end
end
