# Foreman Installer - Staypuft plugin

This is a plugin for foreman-installer to help with Staypuft installation.
[Staypuft](https://github.com/theforeman/staypuft) is a Foreman plugin which allows user to install OpenStack.

## How do I use it?

You just install RPM package named foreman-installer-staypuft and run 
staypuft-installer. It will automatically run the wizard that asks few questions
specific to your environment. The result is Foreman with provisioning correctly
configured and Staypuft plugin enabled. Without any further effort you should 
be able to create your OpenStack deployment.

There are two ways of adding client machines to staypuft (openstack will be
installed onto those machines). You can either let staypuft provision them
using TFTP (you must have control over DHCP, so isolated network would be
good option) or you can register already running machines by running 
staypuft-client installer on them.

## Where can I download RPMs?

We publish this in official Foreman repositories. Visit [yum.theforeman.org](http://yum.theforeman.org/) for more details.
All staypuft packages are in plugin repo. For installing client you need
foreman-installer-staypuft for client (optional, only if you can't use provisioning)
you want foreman-installer-staypuft-client.

## How do I build RPM myself?

We use tito for building the package in our koji instance. Once you tag your changes
you can trigger the build by running ```tito release koji```.

## What platforms are supported

Currently we support only CentOS and RHEL using subscription-manager. On CentOS
you may want to run staypuft-installer with discovery image installation enabled,
otherwise provisioning won't work. You can run it like this

    staypuft-installer --foreman-plugin-discovery-install-images=true

Note that downloading discovery images can take long time (depending on your connectivity)
