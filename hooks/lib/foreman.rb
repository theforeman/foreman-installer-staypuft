class Foreman
  RESOURCES = {
      :subnet => 'Subnet',
      :domain => 'Domain',
      :smart_proxy => 'SmartProxy',
      :host => 'Host',
      :config_template => 'ConfigTemplate',
      :operating_system => 'OperatingSystem',
      :medium => 'Medium',
      :template_kind => 'TemplateKind',
      :os_default_template => 'OsDefaultTemplate',
      :partition_table => 'Ptable',
      :parameter => 'Parameter',
      :hostgroup => 'Hostgroup',
      :environment => 'Environment',
      :setting => 'Setting',
      :template_combination => 'TemplateCombination',
  }

  def initialize(options)
    @options = options
    @resource = Hash.new { |h, k| h[k] = Resource.new(ForemanApi::Resources.const_get(RESOURCES[k]).new(@options), k) }
  end

  def method_missing(name, *args, &block)
    name = name.to_sym
    if RESOURCES.keys.include?(name)
      @resource[name]
    else
      super
    end
  end

  def respond_to?(name)
    if RESOURCES.keys.include?(name)
      true
    else
      super
    end
  end

  def version
    version, _ = ForemanApi::Base.new(@options).http_call 'get', '/api/status'
    version['version']
  end

  class Resource
    def initialize(api_resource, name)
      @api_resource = api_resource
      @name = name
    end

    def method_missing(name, *args, &block)
      if @api_resource.respond_to?(name)
        @api_resource.send name, *args, &block
      else
        super
      end
    end

    def respond_to?(name)
      @api_resource.respond_to?(name) || super
    end

    def show_or_ensure(identifier, attributes)
      begin
        object, _ = @api_resource.show(identifier)
        if should_update?(object, attributes)
          object, _ = @api_resource.update(identifier.merge({@name.to_s => attributes}))
          object, _ = @api_resource.show(identifier)
        end
      rescue RestClient::ResourceNotFound
        object, _ = @api_resource.create({@name.to_s => attributes}.merge(identifier.tap {|h| h.delete('id')}))
      end
      object
    end

    def show!(*args)
      error_message = args.delete(:error_message) || 'unknown error'
      begin
        object, _ = @api_resource.show(*args)
      rescue RestClient::ResourceNotFound
        raise StandardError, error_message
      end
      object
    end

    def index(*args)
      object, _ = @api_resource.index(*args)
      object['results']
    end

    def search(condition)
      index('search' => condition)
    end

    def first(condition)
      search(condition).first
    end

    def first!(condition)
      first(condition) or raise StandardError, "no #{@name} found by searching '#{condition}'"
    end

    private

    def should_update?(original, desired)
      desired.any? { |attribute, value| original[attribute] != value }
    end
  end
end
