#!/bin/bash

TARGET=/etc/puppet/environments/production/modules/
OFI_MODULES=/usr/share/openstack-foreman-installer/puppet/modules
OS_MODULES=/usr/share/openstack-puppet/modules

if [ -d $OFI_MODULES -a -d $OS_MODULES ]; then
  # copy modules from packages
  for mod in "$OFI_MODULES/*"; do
    ln -nfs $mod $TARGET
  done

  for mod in "$OS_MODULES/*"; do
    ln -nfs $mod $TARGET
  done
else
  # get stable modules for git repositories
  ASTAPOR_VERSION="origin/1_0_stable"
  OPENSTACK_MODULES_VERSION="origin/havana"
  
  mkdir -p /tmp/foreman_installer_staypuft
  cd /tmp/foreman_installer_staypuft
  rm -rf /tmp/astapor /tmp/openstack-puppet-modules modules
  mkdir modules
  
  echo "Cloning repositories"
  git clone https://github.com/redhat-openstack/astapor
  git clone --recursive https://github.com/redhat-openstack/openstack-puppet-modules
  
  pushd astapor
  git reset --hard $ASTAPOR_VERSION
  popd
  pushd openstack-puppet-modules
  git reset --hard $OPENSTACK_MODULES_VERSION
  popd
  
  mv astapor/puppet/modules/* modules
  mv openstack-puppet-modules/* modules
  rm -rf astapor openstack-puppet-modules

  mv modules/* $TARGET
fi
