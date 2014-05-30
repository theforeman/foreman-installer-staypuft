# We don't want to use SCL since we are missing some dependencies 
# in SCL and we still support 1.8 for installer
%global scl_ruby /usr/bin/ruby

# set and uncomment all three to set alpha tag
#global alphatag RC1
#global dotalphatag .%{alphatag}
#global dashalphatag -%{alphatag}

Name:       foreman-installer-staypuft
Epoch:      1
Version:    0.1.1
Release:    1%{?dotalphatag}%{?dist}
Summary:    Foreman-installer plugin that allows you to install staypuft
Group:      Applications/System
License:    GPLv3+ and ASL 2.0
URL:        http://theforeman.org
Source0:    %{name}-%{version}%{?dashalphatag}.tar.gz

BuildArch:  noarch

Requires:   foreman-installer >= 1.5.0
Requires:   ntp
Requires:   rubygem-kafo >= 0.6.4
Requires:   rubygem-foreman_api >= 0.1.4
Requires:   git

%if 0%{?fedora} > 18
Requires:   %{?scl_prefix}ruby(release)
%else
Requires:   %{?scl_prefix}ruby(abi)
%endif

%description
This is a Foreman-installer plugins that allows you to install and configure
staypuft foreman plugin

%package client
Summary:    A staypuft client installer which registers a host in staypuft
BuildArch:  noarch
Requires:   foreman-installer >= 1.5.0
Requires:   rubygem-kafo >= 0.6.0
%if 0%{?fedora} > 18
Requires:   %{?scl_prefix}ruby(release)
%else
Requires:   %{?scl_prefix}ruby(abi)
%endif

%description client
This package installs subset of foreman-installer-staypuft files so it can
be used only for registering a new client to staypuft instance.

%prep
%setup -q -n %{name}-%{version}%{?dashalphatag}

%build
#replace shebangs for SCL
%if %{?scl:1}%{!?scl:0}
  sed -ri '1sX(/usr/bin/ruby|/usr/bin/env ruby)X%{scl_ruby}X' bin/staypuft-installer
%endif

%install
install -d -m0755 %{buildroot}%{_datadir}/foreman-installer
cp -R hooks modules %{buildroot}%{_datadir}/foreman-installer
install -d -m0755 %{buildroot}%{_sbindir}
cp bin/staypuft-installer %{buildroot}%{_sbindir}/staypuft-installer
cp bin/staypuft-client-installer %{buildroot}%{_sbindir}/staypuft-client-installer
install -d -m0755 %{buildroot}%{_sysconfdir}/foreman/
cp config/staypuft-client-installer.yaml %{buildroot}%{_sysconfdir}/foreman/staypuft-client-installer.yaml
cp config/staypuft-installer.yaml %{buildroot}%{_sysconfdir}/foreman/staypuft-installer.yaml
cp config/staypuft-installer.answers.yaml %{buildroot}%{_sysconfdir}/foreman/staypuft-installer.answers.yaml


%files
%defattr(-,root,root,-)
%doc LICENSE
%{_datadir}/foreman-installer/hooks/boot/10-add_options.rb
%{_datadir}/foreman-installer/hooks/lib/base_seeder.rb
%{_datadir}/foreman-installer/hooks/lib/foreman.rb
%attr(755, root, root) %{_datadir}/foreman-installer/hooks/lib/install_modules.sh
%{_datadir}/foreman-installer/hooks/lib/authentication_wizard.rb
%{_datadir}/foreman-installer/hooks/lib/base_wizard.rb
%{_datadir}/foreman-installer/hooks/lib/provisioning_seeder.rb
%{_datadir}/foreman-installer/hooks/lib/provisioning_wizard.rb
%{_datadir}/foreman-installer/hooks/lib/subscription_seeder.rb
%{_datadir}/foreman-installer/hooks/post/10-setup_provisioning.rb
%{_datadir}/foreman-installer/hooks/pre_validations/10-gather_and_set_staypuft_values.rb
%{_datadir}/foreman-installer/hooks/pre_values/10-register_staypuft_modules.rb
%{_datadir}/foreman-installer/modules/network
%{_datadir}/foreman-installer/modules/ssh_keygen
%{_datadir}/foreman-installer/modules/sshkeypair
%{_datadir}/foreman-installer/modules/foreman/manifests/plugin/staypuft.pp
%{_datadir}/foreman-installer/modules/foreman/manifests/plugin/staypuft_client.pp
%{_datadir}/foreman-installer/modules/foreman/manifests/plugin/staypuft_network.pp
%{_datadir}/foreman-installer/modules/foreman/manifests/puppet/agent/service.pp

%config %attr(600, root, root) %{_sysconfdir}/foreman/staypuft-installer.yaml
%config(noreplace) %attr(600, root, root) %{_sysconfdir}/foreman/staypuft-installer.answers.yaml
%{_sbindir}/staypuft-installer

%files client
%doc LICENSE
%{_datadir}/foreman-installer/hooks/boot/10-add_client_options.rb
%{_datadir}/foreman-installer/hooks/post/10-register_in_staypuft.rb
%{_datadir}/foreman-installer/modules/foreman/manifests/plugin/staypuft_client.pp
%config %attr(600, root, root) %{_sysconfdir}/foreman/staypuft-client-installer.yaml
%{_sbindir}/staypuft-client-installer

%changelog
* Fri Jul 11 2014 Marek Hulan <mhulan@redhat.com> 0.1.1-1
- adding lvm with cinder volumes ptable (dradez@redhat.com)
- adding ntp package dependancies (dradez@redhat.com)

* Thu Jul 03 2014 Marek Hulan <mhulan@redhat.com> 0.1.0-1
- Remove EPEL repo from RHEL KS template (mhulan@redhat.com)
- We need latest kafo to fix password default values (mhulan@redhat.com)
- Fix BZ#1109432 - random root password (mhulan@redhat.com)
- Fix BZ#1114693 - don't crash on missing installation medium
  (mhulan@redhat.com)
- use subscription-manager instead of yum-config-manager (dradez@redhat.com)
- Fixing typos (yanis.guenane@enovance.com)
- add explicit ntp requirement to spec file (mburns@redhat.com)
- some more re-wording changes (mburns@redhat.com)
- bz#1113748 reword the help text for password/ssh key (mburns@redhat.com)
- adding service resources for ntpd (dradez@redhat.com)
- Fix BZ#1113537 - allow empty ssh keys (mhulan@redhat.com)
- moving the repo enable for redhat_register (dradez@redhat.com)

* Wed Jun 25 2014 Marek Hulan <mhulan@redhat.com> 0.0.25-1
- Crypts root password using sha256 (mhulan@redhat.com)

* Wed Jun 25 2014 Marek Hulan <mhulan@redhat.com> 0.0.24-1
- Fix BZ#1103151 (mhulan@redhat.com)

* Tue Jun 24 2014 Marek Hulan <mhulan@redhat.com> 0.0.23-1
- Fix missing resolv (mhulan@redhat.com)

* Tue Jun 24 2014 Marek Hulan <mhulan@redhat.com> 0.0.22-1
- Fix BZ#1110438 (mhulan@redhat.com)
- Fix BZ#1112179 (mhulan@redhat.com)
- Fix BZ#1105312 (mhulan@redhat.com)
- Fix rhel kickstart template (mhulan@redhat.com)

* Mon Jun 23 2014 Marek Hulan <mhulan@redhat.com> 0.0.21-1
- Add root password and ssh key wizard (mhulan@redhat.com)
- Fix output during interupt or cancel (mhulan@redhat.com)
- adding ntp sync to installation tasks (dradez@redhat.com)

* Thu Jun 19 2014 Marek Hulan <mhulan@redhat.com> 0.0.20-1
- Disable SCL for installer packages (mhulan@redhat.com)
- Fix BZ#1102952 (mhulan@redhat.com)
- adding firewall rules for udp dns and ssh (dradez@redhat.com)

* Tue Jun 17 2014 Marek Hulan <mhulan@redhat.com> 0.0.19-1
- Fix BZ#1108906 (mhulan@redhat.com)
- Fix network interface wizard (mhulan@redhat.com)

* Mon Jun 16 2014 Marek Hulan <mhulan@redhat.com> 0.0.18-1
- Fix puppetmaster firewall port (mhulan@redhat.com)
- NFS is not supported (mhulan@redhat.com)
- Fix BZ#1103151 (mhulan@redhat.com)
- Fix BZ#1102706 (mhulan@redhat.com)
- Fix BZ#1105328 (mhulan@redhat.com)
- Fix BZ#1102394 (mhulan@redhat.com)

* Fri Jun 13 2014 Marek Hulan <mhulan@redhat.com> 0.0.17-1
- Fix netmask for nil values (mhulan@redhat.com)

* Thu Jun 12 2014 Marek Hulan <mhulan@redhat.com> 0.0.16-1
- Don't start configuration if installation fails (mhulan@redhat.com)
- Accept CIDR for netmask and convert it (mhulan@redhat.com)
- Ensure required ports are open (mhulan@redhat.com)

* Thu Jun 05 2014 Marek Hulan <mhulan@redhat.com> 0.0.15-1
- Fix RHEL7 default repo (mhulan@redhat.com)

* Wed Jun 04 2014 Marek Hulan <mhulan@redhat.com> 0.0.14-1
- On RHEL setup both 6 and 7 (mhulan@redhat.com)
- Support RHEL7 as a default OS for provisioning (mhulan@redhat.com)
- Update README.md (mhulan@redhat.com)
- Split logic among more hooks (mhulan@redhat.com)

* Tue May 20 2014 Marek Hulan <mhulan@redhat.com> 0.0.13-2
- Fixes gh#4 - nonscl rpm dependencies (mhulan@redhat.com)
- Fix release configuration (mhulan@redhat.com)

* Fri May 16 2014 Marek Hulan <mhulan@redhat.com> 0.0.13-1
- Fix docs (mhulan@redhat.com)
- Enable user authentication (mhulan@redhat.com)
- Add foreman_api dependency (mhulan@redhat.com)
- Change default koji tags (mhulan@redhat.com)

* Wed May 07 2014 Marek Hulan <mhulan@redhat.com> 0.0.12-1
- Configure host nameservers during installation (mhulan@redhat.com)

* Wed May 07 2014 Marek Hulan <mhulan@redhat.com> 0.0.11-1
- Minor fixes (mhulan@redhat.com)

* Tue May 06 2014 Marek Hulan <mhulan@redhat.com> 0.0.10-1
- Fix staypuft installation (mhulan@redhat.com)

* Tue May 06 2014 Marek Hulan <mhulan@redhat.com> 0.0.9-1
- Install staypuft package (mhulan@redhat.com)
- run db:seed at the end to resolve puppet import issues (mburns@redhat.com)

* Mon May 05 2014 Marek Hulan <mhulan@redhat.com> 0.0.8-1
- Provisioning changes (mhulan@redhat.com)
- Add foreman tasks mapping (mhulan@redhat.com)
- Change proceed string (mhulan@redhat.com)
- Add own installer script with own config files (mhulan@redhat.com)
- Do not enforce downloading discovery images (mhulan@redhat.com)

* Mon May 05 2014 Marek Hulan <mhulan@redhat.com> 0.0.7-1
- Update redhat_register snippet template (mhulan@redhat.com)

* Fri May 02 2014 Marek Hulan <mhulan@redhat.com> 0.0.6-1
- Better user experience (mhulan@redhat.com)

* Fri May 02 2014 Marek Hulan <mhulan@redhat.com> 0.0.5-1
- Puppet modules installation (mhulan@redhat.com)

* Fri May 02 2014 Marek Hulan <mhulan@redhat.com> 0.0.4-1
- Adds RHEL support (mhulan@redhat.com)

* Wed Apr 30 2014 Marek Hulan <mhulan@redhat.com> 0.0.3-1
- Fix pxe_template discovery env issue (mhulan@redhat.com)

* Wed Apr 30 2014 Marek Hulan <mhulan@redhat.com> 0.0.2-1
- Fix seeding and download discovery images (mhulan@redhat.com)

* Wed Apr 30 2014 Marek Hulan <mhulan@redhat.com> 0.0.1-0
- new package built with tito


