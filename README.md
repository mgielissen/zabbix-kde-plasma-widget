# Zabbix widget for KDE Plasma 6

A Plasma 6 desktop/panel widget that shows the **active problems (triggers)**
of a Zabbix server, colored with the standard Zabbix severity colors.

## Features

- Live problem list, most severe first, with host name and how long it is active
- Standard Zabbix severity colors (Not classified → Disaster)
- Auto-refresh (interval configurable, default 60 s)
- Click a problem to open it in the Zabbix web UI
- Compact panel mode: warning icon + problem count
- Two authentication modes:
  - **API token** (Zabbix ≥ 5.4): only a token, sent as `Authorization: Bearer`
  - **Username / password**: uses `user.login`; the session token is sent in
    the `Authorization: Bearer` header on Zabbix ≥ 6.4 (the `auth` body
    parameter was removed in 7.0) and in the request body on older versions;
    the server version is detected automatically via `apiinfo.version`
  - Expired sessions re-login automatically; on pre-6.4 the pre-6.4
    `user` login parameter is used automatically
- Zabbix 7.0+ support: the `problem.get` API changed in 7.0 (no more
  `selectHosts`); the widget automatically resolves host names through
  `trigger.get` there and also self-corrects when the server rejects a
  parameter it sends
- Filter on minimum severity, acknowledged problems, maximum list length, and
  (optionally) a maximum problem age in hours — by default the Zabbix API
  also returns problems that are still open but weeks old, unlike the web
  UI's default 24-hour view; resolved problems (`r_eventid` set) are never
  shown

## Requirements

- KDE Plasma 6 (tested on 6.6)
- Zabbix 5.0 or newer (username/password also works on older versions)

## Install

```sh
./install.sh
```

or manually:

```sh
kpackagetool6 --install --type Plasma/Applet .
```

Then right-click the desktop or panel → **Add Widgets…** → search for **Zabbix**.

If the widget does not appear immediately, restart plasmashell:

```sh
systemctl --user restart plasma-plasmashell
# or: kquitapp6 plasmashell && kstart plasmashell
```

## Configure

Right-click the widget → **Configure Zabbix…**:

| Setting | Description |
|---|---|
| Server URL | e.g. `https://zabbix.example.com` (`/api_jsonrpc.php` is appended automatically) |
| Authentication | API token (recommended) or username/password |
| Refresh interval | seconds, min 10 |
| Severity filter | show problems with at least this severity |
| Acknowledged | whether to also show acknowledged problems |
| Maximum problems | cap of the fetched list (1–100) |

**Tip:** create a dedicated read-only Zabbix user or API token for the widget.
The password (username/password mode) is stored unencrypted in the Plasma
widget configuration (`plasma-org.kde.plasma.desktop-appletsrc`).

### Self-signed TLS certificates

The widget uses Qt's network stack, so a self-signed server certificate must
be trusted by the system (`/usr/local/share/ca-certificates/` +
`update-ca-certificates`), otherwise requests fail with a network error.

## Uninstall

```sh
kpackagetool6 --remove com.example.zabbix --type Plasma/Applet
```

## License

GPL-2.0-or-later, the same license used by KDE Plasma and Zabbix — see
`LICENSE`.

Copyright 2026 Mario Gielissen <mario@gielissen.org>

## Layout

```
metadata.json                  Plasma 6 plasmoid manifest
contents/code/zabbix.js        JSON-RPC 2.0 client (XMLHttpRequest)
contents/ui/main.qml           widget: compact + full representation
contents/ui/ProblemList.qml    severity-colored problem list
contents/ui/configGeneral.qml  settings page (KCM.SimpleKCM)
contents/config/main.xml       config schema (KConfig XT)
contents/config/config.qml     config category definition
```
