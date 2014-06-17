class ProvisioningWizard
  NIC_ATTRS = {
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
    :configure_networking => 'Set this host networking'
  }
  ORDER = %w(interface ip netmask network own_gateway from to gateway dns domain base_url configure_networking)
  attr_accessor *NIC_ATTRS.keys

  def initialize(kafo)
    @logger = kafo.logger
    # set default value according to parameter value
    NIC_ATTRS.each_pair do |attr, name|
      param = kafo.param('foreman_plugin_staypuft', attr.to_s)
      send "#{attr}=", param && param.value
    end

    say HighLine.color('Provisioning setup', :headline)
    say '' 
  end

  def start
    get_interface if @interface.nil? || !interfaces.has_key?(@interface)
    configure = true
    while configure
      send("get_#{configure}") if configure.is_a?(Symbol)
      print_configuration
      configure = get_ready
    end
  end

  def get_configure_networking
    self.configure_networking = !configure_networking
  end

  def method_missing(name, *args, &block)
    if name.to_s =~ /^get_(.*)/ && NIC_ATTRS.keys.include?(attr = $1.to_sym)
      send "#{$1}=", ask("new value for #{NIC_ATTRS[attr]}")
    else
      super
    end
  end

  def respond_to?(name)
    if name.to_s =~ /^get_(.*)/ && NIC_ATTRS.keys.include?($1.to_sym)
      true 
    else
      super
    end
  end

  def base_url
    @base_url ||= "https://#{Facter.value :fqdn}"
  end

  def domain
    @domain ||= Facter.value :domain
  end

  def dns
    @dns ||= begin
      line = File.read('/etc/resolv.conf').split("\n").detect { |line| line =~ /nameserver\s+.*/}
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

  private

  def print_configuration
    say HighLine.color("\nCurrent networking setup:", :headline)
    ORDER.each do |attr|
      name = NIC_ATTRS[attr.to_sym]
      print_pair name, send(attr) 
    end
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
      menu.choice(HighLine.color('No, cancel installation', :cancel)) { exit 0 }
    end
  rescue Interrupt
    @logger.debug "Got interrupt, exiting"
    exit(0)
  end

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
    @ip      = interfaces[@interface][:ip]
    @network = interfaces[@interface][:network]
    @netmask = interfaces[@interface][:netmask]
    @cidr    = interfaces[@interface][:cidr]
    @from    = interfaces[@interface][:from]
    @to      = interfaces[@interface][:to]
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
