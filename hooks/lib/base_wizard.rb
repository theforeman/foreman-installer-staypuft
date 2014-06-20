class BaseWizard
  def self.attrs
    raise NotImplementedError
  end

  def self.order
    raise NotImplementedError
  end

  def self.custom_labels
    raise NotImplementedError
  end

  attr_accessor :header, :help, :allow_cancellation

  def initialize(kafo)
    @kafo   = kafo
    @logger = kafo.logger
    # set default value according to parameter value
    self.class.attrs.each_pair do |attr, name|
      param = kafo_param(attr)
      value = param && param.value
      if param.is_a?(Kafo::Params::Password) # for password we need decrypted but hidden value
        param.value = param.default if param.value.nil?
        param.send(:decrypt) if param.send(:encrypted?)
        value = send(attr) || param.instance_variable_get('@value')
      end
      send "#{attr}=", value
    end
  end

  def start
    configure = true
    while configure
      send("get_#{configure}") if configure.is_a?(Symbol)
      print_configuration
      configure = get_ready
      configure = true if !configure && !validate
    end
  end

  def method_missing(name, *args, &block)
    if name.to_s =~ /^get_(.*)/ && self.class.attrs.keys.include?(attr = $1.to_sym)
      send "#{$1}=", ask("new value for #{self.class.attrs[attr]}")
    else
      super
    end
  end

  def respond_to?(name)
    if name.to_s =~ /^get_(.*)/ && self.class.attrs.keys.include?($1.to_sym)
      true
    else
      super
    end
  end

  private

  def validate
    errors = self.class.attrs.keys.map do |attr|
      method_name = "validate_#{attr}"
      send(method_name) if respond_to?(method_name)
    end.compact

    errors.each { |error| say HighLine.color(error, :bad) }
    errors.empty?
  end

  def kafo_param(attr)
    @kafo.param('foreman_plugin_staypuft', attr.to_s)
  end

  def print_configuration
    say HighLine.color(header, :headline) unless header.nil?
    self.class.order.each do |attr|
      name = self.class.attrs[attr.to_sym]
      value = kafo_param(attr).is_a?(Kafo::Params::Password) ? '*' * send(attr).size : send(attr)
      print_pair name, value
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
      say "\n#{self.help}"
      menu.header = HighLine.color("\nHow would you like to proceed?", :important)
      menu.prompt = ''
      menu.select_by = :index
      menu.choice(HighLine.color('Proceed with the above values', :run)) { false }
      self.class.order.each do |attr|
        name = self.class.attrs[attr.to_sym]
        label = self.class.custom_labels[attr.to_sym] || "Change #{name}"
        label = "Do not " + label.downcase if send(attr).is_a?(TrueClass)
        label = label
        menu.choice(label) { attr.to_sym }
      end
      menu.choice(HighLine.color('Cancel Installation', :cancel)) { @kafo.class.exit(100) } if self.allow_cancellation
    end
  rescue Interrupt
    @logger.debug "Got interrupt, exiting"
    @kafo.class.exit(100)
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
