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
Version:    0.0.1
Release:    0%{?dotalphatag}%{?dist}
Summary:    Foreman-installer plugin that allows you to install staypuft
Group:      Applications/System
License:    GPLv3+ and ASL 2.0
URL:        http://theforeman.org
Source0:    %{name}-%{version}%{?dashalphatag}.tar.gz

BuildArch:  noarch

Requires:   %{?scl_prefix}foreman-installer >= 1.5.0
Requires:   %{?scl_prefix}rubygem-kafo >= 0.5.4

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

%install
install -d -m0755 %{buildroot}%{_datadir}/foreman-installer
cp -R hooks modules %{buildroot}%{_datadir}/foreman-installer

%files
%defattr(-,root,root,-)
%doc LICENSE
%{_datadir}/foreman-installer/hooks/boot/10-add_options.rb
%{_datadir}/foreman-installer/hooks/lib/foreman.rb
%{_datadir}/foreman-installer/hooks/lib/provisioning_seeder.rb
%{_datadir}/foreman-installer/hooks/lib/provisioning_wizard.rb
%{_datadir}/foreman-installer/hooks/post/10-setup_provisioning.rb
%{_datadir}/foreman-installer/hooks/pre_values/10-gather_information.rb
%{_datadir}/foreman-installer/modules/network
%{_datadir}/foreman-installer/modules/foreman/manifests/plugin/staypuft.pp

%changelog

