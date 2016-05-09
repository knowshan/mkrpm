%define debug_package %{nil} 
%define __jar_repack %{nil} 
AutoReqProv: no
Name: 
Summary: 
License: 
Version:
Release: 
Group: Application/Engineering
Source: %{name}-%{version}.tgz

%description

no description stanza

%prep
%setup

%build

%install
if [ ! -d $RPM_BUILD_ROOT  ]; then mkdir $RPM_BUILD_ROOT; fi
mkdir -p $RPM_BUILD_ROOTINSTALLATION_DIRECTORY
rsync -avH --exclude ".git" --exclude ".gitignore" ./ $RPM_BUILD_ROOTINSTALLATION_DIRECTORY

%clean
rm -rf $RPM_BUILD_ROOT

%pre

%post

%preun

%pretrans

%posttrans

%files
%defattr(-,root,root,0755)
/

%changelog

