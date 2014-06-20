class AuthenticationWizard < BaseWizard
  def self.attrs
    {
        :ssh_public_key => 'SSH public key',
        :root_password => 'Root Password',
    }
  end

  def self.order
    %w(ssh_public_key root_password)
  end

  def self.custom_labels
    {
        :configure_networking => 'Configure networking'
    }
  end

  def initialize(*args)
    super
    self.header = 'Configure client authentication'
    self.help = "You can configure default root password and public ssh key for root account which will be used fr machines provisioned by Staypuft. You can leave default password which is '<%= HighLine.color('spengler', :info) %>' or set your own. The minimal password length is 8 characters. You can optionally set SSH public key. You can combine both methods."
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

  def validate_ssh_public_key
    return nil if @ssh_public_key.nil? || @ssh_public_key.empty?
    return nil if @ssh_public_key =~ /\Assh-.* .*( .*)?\Z/
    "SSH key seems invalid, make sure it starts with ssh- and it has no new line characters"
  end

  def validate_root_password
    return "Password must be at least 8 characters long" if @root_password.nil? || @root_password.length < 8
  end
end
