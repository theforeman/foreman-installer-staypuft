class SubscriptionSeeder < BaseSeeder
  def initialize(kafo)
    super
    @config = kafo.config

    max_tries = 5
    current = 0
    begin
      current += 1
      foreman_host = find_foreman_host
    rescue => e
      @logger.debug "Host was not found, retrying in 5 seconds (#{current}/#{max_tries})"
      sleep 5
      retry if current < max_tries
    end

    @os = find_default_os(foreman_host)
    @oses = find_default_oses(foreman_host)

    @sm_username = @config.get_custom(:sm_username) || ''
    @sm_password = @config.get_custom(:sm_password) || ''
    @repositories = @config.get_custom(:repositories) || 'rhel-7-server-openstack-5.0-rpms'
    @sm_proxy_user = @config.get_custom(:sm_proxy_user) || ''
    @sm_proxy_password = @config.get_custom(:sm_proxy_password) || ''
    @sm_proxy_host = @config.get_custom(:sm_proxy_host) || ''
    @sm_proxy_port = @config.get_custom(:sm_proxy_port) || ''
    @repo_path = @config.get_custom(:repo_path) || 'http://'
    @sm_pool = @config.get_custom(:sm_pool) ||''
    @skip = @config.get_custom(:skip_subscription_seeding) || false
    @skip_repo_path = @config.get_custom(:skip_repo_path) || false
    @interactive = kafo.config.app[:provisioning_wizard] != 'non-interactive'
  end

  def seed
    if subscription_seed?
      if @interactive
        say "\nNow you should configure installation media which will be used for provisioning."
        say "Note that if you don't configure it properly, host provisioning won't work until you configure installation media manually."
        get = get_repo_path
        while get || (invalid_repo_path && !@skip_repo_path)
          puts HighLine.color(invalid_repo_path, :bad) if !get && invalid_repo_path
          get = get_repo_path
        end
      end
      @config.set_custom(:repo_path, @repo_path)

      if @interactive
        get = get_credentials
         while get || (invalid && !@skip)
          puts HighLine.color(invalid, :bad) if !get && invalid
          get = get_credentials
        end
      end

      @config.set_custom(:sm_username, @sm_username)
      @config.set_custom(:sm_password, @sm_password)
      @config.set_custom(:repositories, @repositories)
      @config.set_custom(:sm_proxy_user, @sm_proxy_user)
      @config.set_custom(:sm_proxy_password, @sm_proxy_password)
      @config.set_custom(:sm_proxy_host, @sm_proxy_host)
      @config.set_custom(:sm_proxy_port, @sm_proxy_port)
      @config.set_custom(:sm_pool, @sm_pool)
      @config.set_custom(:skip_repo_path, @skip_repo_path)
      @config.set_custom(:skip_subscription_seeding, @skip)
      @config.save_configuration(@config.app)
    else
      @skip = true
      @skip_repo_path = true
    end

    unless @skip_repo_path
      @foreman.medium.show_or_ensure({'id' => 'RedHat mirror'},
                                     {'name' => 'RedHat mirror',
                                      'path' => @repo_path,
                                      'os_family' => 'Redhat'})
    end

    unless @skip
      @oses.each do |os|
        @foreman.parameter.show_or_ensure({'id' => 'subscription_manager', 'operatingsystem_id' => os['id']},
                                          {
                                              'name' => 'subscription_manager',
                                              'value' => 'true',
                                          })
        @foreman.parameter.show_or_ensure({'id' => 'subscription_manager_username', 'operatingsystem_id' => os['id']},
                                          {
                                              'name' => 'subscription_manager_username',
                                              'value' => @sm_username,
                                          })
        @foreman.parameter.show_or_ensure({'id' => 'subscription_manager_password', 'operatingsystem_id' => os['id']},
                                          {
                                              'name' => 'subscription_manager_password',
                                              'value' => @sm_password,
                                          })

        respositories = @repositories
        repositories = respositories.gsub('rhel-7-', 'rhel-6-') if os['major'].to_s == '6'
        repositories = respositories.gsub('rhel-6-', 'rhel-7-') if os['major'].to_s == '7'
        @foreman.parameter.show_or_ensure({'id' => 'subscription_manager_repos', 'operatingsystem_id' => os['id']},
                                          {
                                              'name' => 'subscription_manager_repos',
                                              'value' => repositories,
                                          })
        if !@sm_pool.empty? && !@sm_pool.nil?
          @foreman.parameter.show_or_ensure({'id' => 'subscription_manager_pool', 'operatingsystem_id' => os['id']},
                                            {
                                                'name' => 'subscription_manager_pool',
                                                'value' => @sm_pool,
                                            })
        end
        if !@sm_proxy_host.empty? && !@sm_proxy_host.nil?
          @foreman.parameter.show_or_ensure({'id' => 'http-proxy', 'operatingsystem_id' => os['id']},
                                            {
                                                'name' => 'http-proxy',
                                                'value' => @sm_proxy_host,
                                            })
        end
        if !@sm_proxy_port.empty? && !@sm_proxy_port.nil?
          @foreman.parameter.show_or_ensure({'id' => 'http-proxy-port', 'operatingsystem_id' => os['id']},
                                            {
                                                'name' => 'http-proxy-port',
                                                'value' => @sm_proxy_port,
                                            })
        end
        if !@sm_proxy_user.empty? && !@sm_proxy_user.nil?
          @foreman.parameter.show_or_ensure({'id' => 'http-proxy-user', 'operatingsystem_id' => os['id']},
                                            {
                                                'name' => 'http-proxy-user',
                                                'value' => @sm_proxy_user,
                                            })
        end
        if !@sm_proxy_password.empty? && !@sm_proxy_password.nil?
          @foreman.parameter.show_or_ensure({'id' => 'http-proxy-password', 'operatingsystem_id' => os['id']},
                                            {
                                                'name' => 'http-proxy-password',
                                                'value' => @sm_proxy_password,
                                            })
        end
      end
    end
  end

  private

  def invalid_repo_path
    message = "\n"
    message += "Repository path can't be empty\n" if @repo_path.empty?
    message += "Repository path is not valid\n" if repo_path_invalid?
    message += "Repository path protocol is not supported, use http or https\n" unless repo_path_supported_scheme?
    message == "\n" ? false : message
  end

  def invalid
    message = "\n"
    message += "Subscription manager username can't be empty\n" if @sm_username.empty?
    message += "Subscription manager password can't be empty\n" if @sm_password.empty?
    message == "\n" ? false : message
  end

  def repo_path_invalid?
    @parsed_uri = URI.parse(@repo_path)
    return false
  rescue URI::InvalidURIError => e
    @logger.debug "User tried to use invalid repo path: #{e.message}"
    return true
  end

  def repo_path_supported_scheme?
    if @parsed_uri
      return %w(http https).include?(@parsed_uri.scheme)
    else
      return true # don't print error for this check, it was catched sooner
    end
  end

  def get_repo_path
    choose do |menu|
      menu.header = HighLine.color("\nEnter RHEL repo path", :important)
      menu.select_by = :index
      menu.prompt = ''
      menu.choice('Set RHEL repo path (http or https URL): '.ljust(37) + HighLine.color(@repo_path, :info)) { @repo_path = ask("Path: ") }
      menu.choice(HighLine.color('Proceed with configuration', :run)) {
        @skip_repo_path = false; false
      }
      menu.choice(HighLine.color("Skip this step (provisioning won't work)", :cancel)) {
        @skip_repo_path = true; false
      }
    end
  end

  def get_credentials
    choose do |menu|
      menu.header = HighLine.color("\nEnter your subscription manager credentials", :important)
      menu.select_by = :index
      menu.prompt = ''
      menu.choice('Subscription manager username: '.ljust(37) + HighLine.color(@sm_username, :info)) { @sm_username = ask("Username: ") }
      menu.choice('Subscription manager password: '.ljust(37) + HighLine.color('*' * @sm_password.size, :info)) { @sm_password = ask("Password: ") { |q| q.echo = "*" } }
      menu.choice('Comma separated repositories: '.ljust(37) + HighLine.color(@repositories, :info)) { @repositories = ask("Repositories: ") }
      menu.choice('Subscription manager pool (recommended): '.ljust(37) + HighLine.color(@sm_pool, :info)) { @sm_pool = ask("Pool: ") }
      menu.choice('Subscription manager proxy hostname: '.ljust(37) + HighLine.color(@sm_proxy_host, :info)) { @sm_proxy_host = ask("Proxy Host: ") }
      menu.choice('Subscription manager proxy port: '.ljust(37) + HighLine.color(@sm_proxy_port, :info)) { @sm_proxy_port = ask("Proxy Port: ") }
      menu.choice('Subscription manager proxy username: '.ljust(37) + HighLine.color(@sm_proxy_user, :info)) { @sm_proxy_user = ask("Proxy User: ") }
      menu.choice('Subscription manager proxy password: '.ljust(37) + HighLine.color(@sm_proxy_password, :info)) { @sm_proxy_password = ask("Proxy Password: ") }
      menu.choice(HighLine.color('Proceed with configuration', :run)) {
        @skip = false; false
      }
      menu.choice(HighLine.color("Skip this step (provisioning won't subscribe your machines)", :cancel)) {
        @skip = true; false
      }
    end
  end

  def subscription_seed?
    @os['name'] == 'RedHat'
  end

end
