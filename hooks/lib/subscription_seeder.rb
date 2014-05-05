class SubscriptionSeeder < BaseSeeder
  def initialize(kafo)
    super

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
    @sm_username = ''
    @sm_password = ''
    @repositories = 'rhel-6-server-openstack-4.0-rpms'
    @repo_path = 'http://'
    @sm_pool = ''
    @skip = false
  end

  def seed
    if subscription_seed?
      get = get_credentials
      while get || (invalid && !@skip)
        puts HighLine.color('Credentials can not be empty', :bad) if !get && invalid
        get = get_credentials
      end
    else
      @skip = true
    end

    @foreman.medium.show_or_ensure({'id' => 'RedHat mirror'},
                                                {'name' => 'RedHat mirror',
                                                 'path' => @repo_path,
                                                 'os_family' => 'Redhat'})

    unless @skip
      @foreman.parameter.show_or_ensure({'id' => 'subscription_manager', 'operatingsystem_id' => @os['id']},
                                        {
                                            'name' => 'subscription_manager',
                                            'value' => 'true',
                                        })
      @foreman.parameter.show_or_ensure({'id' => 'subscription_manager_username', 'operatingsystem_id' => @os['id']},
                                        {
                                            'name' => 'subscription_manager_username',
                                            'value' => @sm_username,
                                        })
      @foreman.parameter.show_or_ensure({'id' => 'subscription_manager_password', 'operatingsystem_id' => @os['id']},
                                        {
                                            'name' => 'subscription_manager_password',
                                            'value' => @sm_password,
                                        })
      @foreman.parameter.show_or_ensure({'id' => 'subscription_manager_repos', 'operatingsystem_id' => @os['id']},
                                        {
                                            'name' => 'subscription_manager_repos',
                                            'value' => @repositories,
                                        })
      if !@sm_pool.empty? && !@sm_pool.nil?
        @foreman.parameter.show_or_ensure({'id' => 'subscription_manager_pool', 'operatingsystem_id' => @os['id']},
                                          {
                                              'name' => 'subscription_manager_pool',
                                              'value' => @sm_pool,
                                          })
      end
    end
  end

  private

  def invalid
    @sm_username.empty? || @sm_password.empty?
  end

  def get_credentials
    choose do |menu|
      menu.header = HighLine.color("\nEnter your subscription manager credentials?", :important)
      menu.prompt = ''
      menu.choice('Subscription manager username: '.ljust(37) + HighLine.color(@sm_username, :info)) { print 'value: '; @sm_username = gets.chomp }
      menu.choice('Subscription manager password: '.ljust(37) + HighLine.color('*' * @sm_password.size, :info)) { print 'value: '; @sm_password = gets.chomp }
      menu.choice('Comma separated repositories: '.ljust(37) + HighLine.color(@repositories, :info)) { print 'value: '; @repositories = gets.chomp }
      menu.choice('RHEL repo path (http(s) or nfs URL): '.ljust(37) + HighLine.color(@repo_path, :info)) { print 'value: '; @repo_path = gets.chomp }
      menu.choice('Subscription manager pool (optional): '.ljust(37) + HighLine.color(@sm_pool, :info)) { print 'value: '; @sm_pool = gets.chomp }
      menu.choice(HighLine.color('Proceed with configuration', :run)) { false }
      menu.choice(HighLine.color("Skip this step (provisioning won't subscribe your machines)", :cancel)) {
        @skip = true; false
      }
    end
  end

  def subscription_seed?
    @os['name'] == 'RedHat'
  end

end
