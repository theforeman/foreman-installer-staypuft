class AuthenticationWizard < BaseWizard
  def self.attrs
    {
        :ssh_public_key => 'SSH public key',
        :root_password => 'Root password',
        :show_password => 'Toggle Root password visibility'
    }
  end

  def self.order
    %w(ssh_public_key root_password show_password)
  end

  def self.custom_labels
    {
        :configure_networking => 'Configure networking',
        :show_password => 'Toggle Root password visibility',
    }
  end

  def initialize(*args)
    super
    self.header = 'Configure client authentication'
    self.help = "Please set a default root password for newly provisioned machines. If you choose not to set a password, it will be generated randomly. The password must be a minimum of 8 characters. You can also set a public ssh key which will be deployed to newly provisioned machines."
    self.ssh_public_key ||= ''
  end

  attr_accessor *attrs.keys

  def get_root_password
    @root_password = ask("new value for root password") { |q| q.echo = '*' }
  end

  def get_ssh_public_key
    say 'You may either use a path to your public key file or enter the whole key (including type and comment)'
    key = ask("file or key")
    key = File.read(key) if File.exists?(key)
    @ssh_public_key = key.chomp
  end

  def get_show_password
    @hide_password = !@hide_password
  end

  def validate_ssh_public_key
    return nil if @ssh_public_key.nil? || @ssh_public_key.empty?
    return nil if @ssh_public_key =~ /\Assh-.* .*( .*)?\Z/
    "SSH key seems invalid, make sure it starts with ssh- and it has no new line characters"
  end

  def validate_root_password
    return "Password must be at least 8 characters long" if @root_password.nil? || @root_password.length < 8
  end

  def print_pair(name, value)
    return true if name == 'Toggle Root password visibility'
    super
  end
end
