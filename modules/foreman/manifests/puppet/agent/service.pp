# = Puppet agent service
# This is a clone of https://github.com/theforeman/puppet-puppet/blob/master/manifests/agent/service.pp
# because we could not use the module itself since openstack modules contains puppet module with same
# name as well.
#
# We have removed anything that we didn't need. For proper puppet management use foreman's puppet module
# if possible.
#
# Set up the puppet client as a service
#
# == Parameters:
#
# $runmode::  either 'service' to enable puppet agent or 'none' to disable it
class foreman::puppet::agent::service($runmode='none') {

  case $runmode {
    'service': {
      service {'puppet':
        ensure    => running,
        hasstatus => true,
        enable    => true,
      }
    }
    'none': {
      service {'puppet':
        ensure    => stopped,
        hasstatus => true,
        enable    => false,
      }
    }
    default: {
      fail("Runmode of ${runmode} not supported by foreman::puppet::agent::config!")
    }
  }
}
