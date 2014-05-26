if app_value(:provisioning_wizard)
  # we register staypuft module and its mapping
  add_module('foreman::plugin::staypuft',
             {:manifest_name => 'plugin/staypuft',  :dir_name => 'foreman'})

  # make sure discovery and foreman-tasks are enabled
  kafo.module('foreman_plugin_discovery').enable
  kafo.module('foreman_plugin_tasks').enable
end
