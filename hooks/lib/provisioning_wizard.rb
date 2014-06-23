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
        :configure_networking => 'Configure networking on this machine'
    }
  end

  def self.order
    %w(interface ip netmask network own_gateway from to gateway dns domain base_url ntp_host configure_networking)
  end

  def self.custom_labels
    {
        :configure_networking => 'Configure networking'
    }
  end

  attr_accessor *attrs.keys

  def initialize(*args)
    super
    self.header = 'Networking setup:'
    self.help = "Staypuft can configure the networking and firewall rules on this machine with the above configuration. Defaults are populated from the this machine's existing networking configuration.\n\nIf you DO NOT want Staypuft Installer to configure networking please set 'Configure networking on this machine' to No before proceeding. Do this by selecting option 'Do not configure networking' from the list below."
    self.allow_cancellation = true
  end

  def start
    get_interface if @interface.nil? || !interfaces.has_key?(@interface)
    super
  end

  def get_configure_networking
    self.configure_networking = !configure_networking
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
    @gateway ||= @own_gateway
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
          menu.header = HighLine.color("\nPlease select NIC on which you want Foreman provisioning enabled", :important)
          interfaces.keys.each do |nic|
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

      ifaces[i] = {:ip => ip, :netmask => netmask, :network => network, :cidr => cidr, :from => from, :to => to, :gateway => gateway}
      ifaces
    end
  end
end
