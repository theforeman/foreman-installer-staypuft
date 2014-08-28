# Foreman Installer - Staypuft plugin

This is a plugin for foreman-installer to help with Staypuft installation.
[Staypuft](https://github.com/theforeman/staypuft) is a Foreman plugin which allows user to install OpenStack.

## How do I use it?

You just install RPM package named foreman-installer-staypuft and run 
staypuft-installer. It will automatically run the wizard that asks few questions
specific to your environment. The result is Foreman with provisioning correctly
configured and Staypuft plugin enabled. Without any further effort you should 
be able to create your OpenStack deployment.

## Where can I download RPMs?

We publish this in official Foreman repositories. Visit [yum.theforeman.org](http://yum.theforeman.org/) for more details.

## How do I build RPM myself?

We use tito for building the package in our koji instance. Once you tag your changes
you can trigger the build by running ```tito release koji```.

## What platforms are supported

Currently it's supposed to run only on CentOS and RHEL (using subscription-manager). 
For staypuft host you should use version 6. Other hosts that are provisioned by 
staypuft CentOS or RHEL 7 will be used (based on what is your staypuft machine). 
There is a workaround required for CentOS. You have to modify installation media 
in foreman to http://mirror.centos.org/centos/$major/os/$arch otherwise provisioning will 
not work. It's tracked in http://projects.theforeman.org/issues/6884
