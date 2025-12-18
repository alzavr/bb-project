Name:           cache-api
Version:        1.0
Release:        1%{?dist}
Summary:        Simple Flask cache API service

License:        MIT
URL:            https://example.com/cache-api
BuildArch:      noarch

Source0:        cache-api.py
Source1:        requirements.txt
Source2:        config.yaml
Source3:        cache-api.service

Requires:       python3
Requires:       python3-pip
Requires:       systemd

%description
Simple service written in Python using Flask and Redis.
Provides HTTP API with Redis-backed caching layer.

%prep
# nothing to prepare

%build
# nothing to build

%install
rm -rf %{buildroot}

install -d %{buildroot}/opt/cache-api
install -d %{buildroot}/etc/cache-api
install -d %{buildroot}/usr/lib/systemd/system

install -m 0755 %{SOURCE0} %{buildroot}/opt/cache-api/cache-api.py
install -m 0644 %{SOURCE1} %{buildroot}/opt/cache-api/requirements.txt
install -m 0644 %{SOURCE2} %{buildroot}/etc/cache-api/config.yaml
install -m 0644 %{SOURCE3} %{buildroot}/usr/lib/systemd/system/cache-api.service

%pre
getent group cacheapi >/dev/null || groupadd -r cacheapi
getent passwd cacheapi >/dev/null || \
    useradd -r -g cacheapi -s /sbin/nologin -d /opt/cache-api cacheapi

%post
%systemd_post cache-api.service

if [ ! -d /opt/cache-api/venv ]; then
    python3 -m venv /opt/cache-api/venv
fi

/opt/cache-api/venv/bin/pip install --no-cache-dir \
    -r /opt/cache-api/requirements.txt || :

systemctl enable --now cache-api.service >/dev/null 2>&1 || :

%preun
if [ "$1" -eq 0 ]; then
    systemctl stop cache-api.service >/dev/null 2>&1 || :
    systemctl disable cache-api.service >/dev/null 2>&1 || :
fi

%systemd_preun cache-api.service

%postun
%systemd_postun cache-api.service

%files
/opt/cache-api
/etc/cache-api
/usr/lib/systemd/system/cache-api.service

%changelog
* Tue Dec 16 2025 Your Name <you@example.com> - 1.0-1
- Initial RPM spec
