#!/usr/bin/env bash
# Install (or update) the Zabbix widget for KDE Plasma 6.
set -euo pipefail

cd "$(dirname "$0")"

if command -v kpackagetool6 >/dev/null 2>&1; then
    KPKG="kpackagetool6"
elif command -v kpackagetool5 >/dev/null 2>&1; then
    KPKG="kpackagetool5"
else
    echo "kpackagetool6 not found. Is Plasma 6 installed?" >&2
    exit 1
fi

$KPKG --type Plasma/Applet --install "$PWD" || $KPKG --type Plasma/Applet --upgrade "$PWD"

echo
echo "Installed. Add the widget via the desktop/panel context menu:"
echo "  'Add Widgets...' -> search for 'Zabbix'"
echo
echo "To remove again:"
echo "  $KPKG --remove com.example.zabbix --type Plasma/Applet"
