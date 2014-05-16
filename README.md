# Foreman Installer - Staypuft plugin

This is a plugin for foreman-installer to help with Staypuft installation.
[Staypuft](https://github.com/theforeman/staypuft Staypuft) is a Foreman plugin which allows user to install OpenStack.

## How do I use it?

You just install RPM package and run foreman-installer. It will automatically
run the wizard that asks few questions specific to your environment. The result
is Foreman with provisioning correctly configured and Staypuft plugin enabled.
Without any further effort you should be able to create your OpenStack deployment.

## Where can I download RPMs?

We publish this in official Foreman repositories. Visit [yum.theforeman.org](http://yum.theforeman.org/) for more details.

## How do I build RPM myself?

We use tito for building the package in our koji instance. Once you tag your changes
you can trigger the build by running ```tito release koji```.

## What platforms are supported

Currently we support only CentOS. RHEL using subscription-manager is being worked on.
