#!/bin/bash

TARGET=/etc/puppet/environments/production/modules
OFI_MODULES=/usr/share/openstack-foreman-installer/puppet/modules
OS_MODULES=/usr/share/openstack-puppet/modules
INSTALLER_MODULES=/usr/share/foreman-installer/modules

if [ -d $OFI_MODULES -a -d $OS_MODULES ]; then
  # copy modules from packages
  ofi_mods="$OFI_MODULES/*"
  os_mods="$OS_MODULES/*"
  all_mods=( "${ofi_mods[@]}" "${os_mods[@]}" )
  for mod_path in ${all_mods[@]}; do
      mod_name=$(basename "$mod_path")
      # rm to make sure the modules are identical (no files left over)
      rm -rf "$TARGET/$mod_name"
      echo "$mod_path to $TARGET/$mod_name"
      cp -r "$mod_path" "$TARGET/"
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

  mv modules/* $TARGET/
fi

# make a copy of installer modules (installer update should not change anything in master)
mod_name="foreman"
mod="$INSTALLER_MODULES/$mod_name"
if [ ! -d $TARGET/$mod_name ]; then
  cp -r $mod $TARGET/
fi
