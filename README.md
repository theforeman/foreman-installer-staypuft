# Foreman Installer - Staypuft plugin

This is a plugin for foreman-installer to help with Staypuft installation.
[Staypuft](https://github.com/theforeman/staypuft) is a Foreman plugin which allows user to install OpenStack.

## How do I use it?

You just install RPM package named foreman-installer-staypuft and run 
`staypuft-installer`. It will automatically run the wizard that asks few questions
specific to your environment. The result is Foreman with provisioning correctly
configured and Staypuft plugin enabled. Without any further effort you should 
be able to create your OpenStack deployment.

To provision on baremetals we use [foreman_discovery](https://github.com/theforeman/foreman_discovery) plugin which requires 
you to download images used to discover all machines. If you want installer to dowload 
images for you (recommended), you can run it like this

```
staypuft-installer --foreman-plugin-discovery-install-images=true
```

Note that downloading will take some time, images are ~200MB. You can download images manually
from [here](http://downloads.theforeman.org/discovery/), but you have to copy and name them correctly yourself.

## Where can I download RPMs?

We publish this in official Foreman repositories. Visit [yum.theforeman.org](http://yum.theforeman.org/) for more details.
All staypuft packages are in plugin repo. For installing client you need
foreman-installer-staypuft for client (optional, only if you can't use provisioning)
you want foreman-installer-staypuft-client.

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
