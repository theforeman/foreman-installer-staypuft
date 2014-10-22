# Foreman Installer - Staypuft plugin

This is a plugin for foreman-installer to help with Staypuft installation.
[Staypuft](https://github.com/theforeman/staypuft) is a Foreman plugin which allows user to install OpenStack.

## How do I use it?

First you must install RPM package named foreman-installer-staypuft. It can be
downloaded from [foreman plugin repositores](http://yum.theforeman.org/plugins/),
currently only from nightlies. You should add the whole repository because of 
other dependencies. You easily do this by installing repo rpm by running

```
yum install http://yum.theforeman.org/releases/latest/el6/x86_64/foreman-release.rpm
yum install foreman-installer-staypuft
```

Now you can run `staypuft-installer`. It will automatically run the wizard 
that asks few questions specific to your environment. The result is Foreman 
with provisioning correctly configured and Staypuft plugin enabled. 
Without any further effort you should be able to create your OpenStack 
deployment.

To provision on baremetals we use [foreman_discovery](https://github.com/theforeman/foreman_discovery) plugin which requires 
you to download images used to discover all machines. If you want installer to 
download images for you (recommended), you can run it like this

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

You can also build the RPM locally by running ```tito build --test
--rpm```. You'll find the built RPMs in ```/tmp/tito```.

## Contributing

If you found an issue, you can report it in [Bugzilla](https://bugzilla.redhat.com/buglist.cgi?component=rhel-osp-installer&list_id=2872876&product=Red%20Hat%20OpenStack).
If you want to chat about the issue or staypuft in general, we are on freenode
irc server on channel #staypuft. We also have mailing list to which you can
subscribe [here](https://www.redhat.com/mailman/listinfo/rdo-list). For staypuft
related questions please add [Installer] tag in subject.

If you want to send a patch, fork the projects and send a Pull Request. Thanks!

## What platforms are supported

Currently it's supposed to run only on CentOS and RHEL (using subscription-manager). 
For staypuft host you should use version 6. Other hosts that are provisioned by 
staypuft CentOS or RHEL 7 will be used (based on what is your staypuft machine). 
There is a workaround required for CentOS. You have to modify installation media 
in foreman to http://mirror.centos.org/centos/$major/os/$arch otherwise provisioning will 
not work. It's tracked in http://projects.theforeman.org/issues/6884
