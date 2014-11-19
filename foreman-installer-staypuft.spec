# We don't want to use SCL since we are missing some dependencies 
# in SCL and we still support 1.8 for installer
%global scl_ruby /usr/bin/ruby

# set and uncomment all three to set alpha tag
#global alphatag RC1
#global dotalphatag .%{alphatag}
#global dashalphatag -%{alphatag}

Name:       foreman-installer-staypuft
Epoch:      1
Version:    0.5.0
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
Requires:   %{name}-client = %{epoch}:%{version}-%{release}

%if 0%{?fedora} > 18 || 0%{?rhel} > 6
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
%if 0%{?fedora} > 18 || 0%{?rhel} > 6
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
install -d -m0755 %{buildroot}%{_bindir}
cp bin/staypuft-register-host %{buildroot}%{_bindir}/staypuft-register-host
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
%{_datadir}/foreman-installer/modules/firewall
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
%{_bindir}/staypuft-register-host

%files client
%doc LICENSE
%{_datadir}/foreman-installer/hooks/boot/10-add_client_options.rb
%{_datadir}/foreman-installer/hooks/post/10-register_in_staypuft.rb
%{_datadir}/foreman-installer/modules/foreman/manifests/plugin/staypuft_client.pp
%config %attr(600, root, root) %{_sysconfdir}/foreman/staypuft-client-installer.yaml
%{_sbindir}/staypuft-client-installer

%changelog
* Tue Nov 18 2014 Brad P. Crochet <brad@redhat.com> 0.5.0-1
- move to OSP 6 (mburns@redhat.com)
- BZ #1162794: Properly configure bond interfaces with vlans (brad@redhat.com)
- Remove EPEL repo from RHEL (jistr@redhat.com)
- BZ #1158680: Let primary interface participate in bonds (brad@redhat.com)
- BZ #1129521: Unconfigured interfaces should be ONBOOT=no (brad@redhat.com)
- Correct the config when a bond and vlan are used together (brad@redhat.com)
- BZ #1157819: Set DEFROUTE=no on all interfaces by default (brad@redhat.com)
- Revert "bz#1152516 don't autostart networking in discovery image"
  (mburns@redhat.com)
- Workaround for http://projects.theforeman.org/issues/7975 (jistr@redhat.com)
- Wait for certificate to allow manual signing (jistr@redhat.com)
- Fail the installer if the registration puppet run fails (jistr@redhat.com)
- Wait for client registration to finish (jistr@redhat.com)
- Remove puppetmaster param from staypuft_client.pp (jistr@redhat.com)
- Set staypuft_ssh_public_key as a host parameter (jistr@redhat.com)
- Rename param to staypuft_ssh_public_key for consistency (jistr@redhat.com)
- Make the RPM installable on RHEL 7 (jistr@redhat.com)
- Pass settings as string when using Foreman > 1.6 (jistr@redhat.com)
- Fix a syntax error (jistr@redhat.com)
- Remove get_ready implementation from ProvisioningWizard (brad@redhat.com)
- no-daemonize puppetssh commmand (mtaylor@redhat.com)
- Add staypuft-client-installer (mhulan@redhat.com)
- bz#1152516 don't autostart networking in discovery image (mburns@redhat.com)

* Wed Oct 15 2014 Brad P. Crochet <brad@redhat.com> 0.4.4-1
- BZ #1148746: Assign DEFROUTE to vlan or bond (brad@redhat.com)

* Thu Oct 09 2014 Brad P. Crochet <brad@redhat.com> 0.4.3-1
- Add staypuft-register-host command (jistr@redhat.com)
- Add custom repositories snippet (mhulan@redhat.com)
- BZ#1147577: Add biosboot partition in case GPT disk label (brad@redhat.com)

* Wed Oct 08 2014 Brad P. Crochet <brad@redhat.com> 0.4.2-1
- Merge pull request #95 from ares/bonding (brad@redhat.com)
- Merge pull request #99 from mburns72h/bz1148435 (ares@igloonet.cz)
- rhbz#1148435 use single quotes for passwords (mburns@redhat.com)
- Remove 'service network restart' from network config snippet
  (brad@redhat.com)
- Update readme (mhulan@redhat.com)
- Configure gateway if bootmode is static (mhulan@redhat.com)
- Install provisioning template that configures bonds (mhulan@redhat.com)
- Add local RPM building instructions to readme (jistr@redhat.com)

* Tue Sep 23 2014 Marek Hulan <mhulan@redhat.com> 0.4.1-1
- Fix whitespace in condition (mhulan@redhat.com)
- BZ#1142182 - provisioned hosts have wrong timezone (jistr@redhat.com)
- Fix possible renaming issue (mhulan@redhat.com)
- Refs BZ#1142295 - Configure DEFROUTE according to subnet assignment
  (mhulan@redhat.com)

* Fri Sep 19 2014 Marek Hulan <mhulan@redhat.com> 0.4.0-1
- Add firewall as hard dependency (mhulan@redhat.com)
- Fix BZ#1142211 - NM changed fqdn in %%post (mhulan@redhat.com)

* Mon Sep 15 2014 Marek Hulan <mhulan@redhat.com> 0.3.5-1
- disable biosdevname for discovery image (mburns@redhat.com)
- rhbz#1140741 sub-man pool is recommended (mburns@redhat.com)
- rhbz#1140057 don't run auto-attach if pool is specified (mburns@redhat.com)
- Update docs regarding discovery images (mhulan@redhat.com)

* Thu Sep 04 2014 Marek Hulan <mhulan@redhat.com> 0.3.4-1
- Primary network is has always DHCP boot mode (mhulan@redhat.com)
- BZ#1134610 - multiple repos in subscription_manager_repos (jistr@redhat.com)
- Install modules from git on CentOS (mhulan@redhat.com)
- Modify kickstart templates to configure networking (mhulan@redhat.com)
- BZ#1127196 - ask for password confirmation (jistr@redhat.com)
- Update readme (mhulan@redhat.com)

* Mon Aug 25 2014 Marek Hulan <mhulan@redhat.com> 0.3.3-1
- fix syntax from last fix (mburns@redhat.com)

* Fri Aug 22 2014 Marek Hulan <mhulan@redhat.com> 0.3.2-1
- Create config templates even if they are missing (mhulan@redhat.com)
- Adds support for CentOS 7 (mhulan@redhat.com)

* Thu Aug 21 2014 Marek Hulan <mhulan@redhat.com> 0.3.1-1
- Default ssh key value is empty string, nil causes problems
  (mhulan@redhat.com)

* Wed Aug 20 2014 Marek Hulan <mhulan@redhat.com> 0.3.0-1
- Print correct admin password on Foreman 1.6+ (mhulan@redhat.com)
- Fix settings values to be strings (mhulan@redhat.com)

* Mon Aug 18 2014 Marek Hulan <mhulan@redhat.com> 0.2.0-1
- bz 1126982, adding biosdevname=0 to kernel params to make sure nics are named
  consistently (dradez@redhat.com)

* Wed Aug 13 2014 Marek Hulan <mhulan@redhat.com> 0.1.10-1
- Fix BZ#1127202 - toggle password visibility (mhulan@redhat.com)
- adding a new default ptable so we do not use autopart (dradez@redhat.com)
- Ref BZ#1127752 - disable IP updating (mhulan@redhat.com)
- Fix BZ#1128679 - do not create empty parameters (mhulan@redhat.com)

* Fri Aug 08 2014 Marek Hulan <mhulan@redhat.com> 0.1.9-1
- Add proxy options for subscription_manager (mburns@redhat.com)
- Fix BZ#1127806 - set ntp-server parameter (mhulan@redhat.com)

* Thu Aug 07 2014 Marek Hulan <mhulan@redhat.com> 0.1.8-1
- Fix BZ#1124850 - accept UDP port 68 (mhulan@redhat.com)
- Fix BZ#1102394 - do not enable RHEL6 (mhulan@redhat.com)
- Fix BZ#1124806 - remove Foreman from provisioning question
  (mhulan@redhat.com)
- Fix BZ#1124810 - sort interfaces by name (mhulan@redhat.com)
- BZ#1124545 - Write the values for skipping repo and subman (brad@redhat.com)
- BZ#1125075 - Ensure firewalld is removed during kickstart
  (jeckersb@redhat.com)
- use correct default gateway on controller (lars@redhat.com)
- BZ#1124598 - provisioning+external network default gateway conflict
  (jeckersb@redhat.com)
- add dhcp port to the default firewall (mburns@redhat.com)
- ensure we only get one interface name for PROVISION_IFACE (lars@redhat.com)
- set PEERDNS=no on all but provision iface (lars@redhat.com)
- disable NetworkManager and enable network by default (mburns@redhat.com)

* Fri Jul 25 2014 Marek Hulan <mhulan@redhat.com> 0.1.7-1
- don't require 100GB for root filesystem (lars@redhat.com)

* Thu Jul 24 2014 Marek Hulan <mhulan@redhat.com> 0.1.6-1
- removing the dependancy on #Dynamic from the ptable. (dradez@redhat.com)

* Thu Jul 24 2014 Marek Hulan <mhulan@redhat.com> 0.1.5-1
- Fixes BZ#1121411 - use correct NIC names (mhulan@redhat.com)
- Support random generated password (mhulan@redhat.com)

* Tue Jul 22 2014 Marek Hulan <mhulan@redhat.com> 0.1.4-1
- set ONBOOT=yes for all nics in the default kickstart template
  (dradez@redhat.com)
- dynamically update the partition table that created the cinder volumes vg
  (dradez@redhat.com)

* Wed Jul 16 2014 Marek Hulan <mhulan@redhat.com> 0.1.2-1
- Add non-interactive mode to provisioning wizard (mhulan@redhat.com)

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


