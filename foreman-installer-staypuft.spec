%if "%{?scl}" == "ruby193"
    %global scl_prefix %{scl}-
    %global scl_ruby /usr/bin/ruby193-ruby
%else
    %global scl_ruby /usr/bin/ruby
%endif

# set and uncomment all three to set alpha tag
#global alphatag RC1
#global dotalphatag .%{alphatag}
#global dashalphatag -%{alphatag}

Name:       foreman-installer-staypuft
Epoch:      1
Version:    0.0.14
Release:    1%{?dotalphatag}%{?dist}
Summary:    Foreman-installer plugin that allows you to install staypuft
Group:      Applications/System
License:    GPLv3+ and ASL 2.0
URL:        http://theforeman.org
Source0:    %{name}-%{version}%{?dashalphatag}.tar.gz

BuildArch:  noarch

Requires:   foreman-installer >= 1.5.0
Requires:   rubygem-kafo >= 0.6.0
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
%{_datadir}/foreman-installer/hooks/lib/provisioning_seeder.rb
%{_datadir}/foreman-installer/hooks/lib/provisioning_wizard.rb
%{_datadir}/foreman-installer/hooks/lib/subscription_seeder.rb
%{_datadir}/foreman-installer/hooks/post/10-register_in_staypuft.rb
%{_datadir}/foreman-installer/hooks/post/10-setup_provisioning.rb
%{_datadir}/foreman-installer/hooks/pre_validations/10-gather_and_set_staypuft_values.rb
%{_datadir}/foreman-installer/hooks/pre_values/10-register_staypuft_modules.rb
%{_datadir}/foreman-installer/modules/network
%{_datadir}/foreman-installer/modules/ssh_keygen
%{_datadir}/foreman-installer/modules/sshkeypair
%{_datadir}/foreman-installer/modules/foreman/manifests/plugin/staypuft.pp
%{_datadir}/foreman-installer/modules/foreman/manifests/plugin/staypuft_client.pp
%{_datadir}/foreman-installer/modules/foreman/manifests/puppet/agent/service.pp

%config %attr(600, root, root) %{_sysconfdir}/foreman/staypuft-installer.yaml
%config %attr(600, root, root) %{_sysconfdir}/foreman/staypuft-client-installer.yaml
%config(noreplace) %attr(600, root, root) %{_sysconfdir}/foreman/staypuft-installer.answers.yaml
%{_sbindir}/staypuft-installer
%{_sbindir}/staypuft-client-installer

%changelog
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


