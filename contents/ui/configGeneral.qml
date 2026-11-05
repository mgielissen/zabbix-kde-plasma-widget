/*
 * SPDX-FileCopyrightText: 2026 Mario Gielissen <mario@gielissen.org>
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * General settings page for the Zabbix widget.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_serverUrl: serverUrl.text
    property string cfg_authMode
    property alias cfg_apiToken: apiToken.text
    property alias cfg_username: username.text
    property alias cfg_password: password.text
    property alias cfg_refreshInterval: refreshInterval.value
    property alias cfg_severityThreshold: severityThreshold.currentIndex
    property alias cfg_includeAcknowledged: includeAcknowledged.checked
    property alias cfg_maxProblems: maxProblems.value
    property alias cfg_maxProblemAgeHours: maxProblemAgeHours.value
    property alias cfg_openWebUi: openWebUi.checked

    readonly property bool useUserPassword: cfg_authMode === "userpass"

    contentItem: Kirigami.FormLayout {
        QQC2.TextField {
            id: serverUrl
            Kirigami.FormData.label: i18n("Server URL:")
            placeholderText: "https://zabbix.example.com"
            Layout.fillWidth: true
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            opacity: 0.7
            wrapMode: Text.WordWrap
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            text: i18n("The API endpoint /api_jsonrpc.php is appended automatically.")
            Kirigami.FormData.isSection: false
        }

        QQC2.ComboBox {
            id: authMethod
            Kirigami.FormData.label: i18n("Authentication:")
            model: [i18n("API token (Zabbix 5.4 or newer)"), i18n("Username / password")]
            currentIndex: page.useUserPassword ? 1 : 0
            onActivated: cfg_authMode = currentIndex === 1 ? "userpass" : "token"
        }

        QQC2.TextField {
            id: apiToken
            visible: !page.useUserPassword
            Kirigami.FormData.label: i18n("API token:")
            echoMode: TextInput.Password
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: username
            visible: page.useUserPassword
            Kirigami.FormData.label: i18n("Username:")
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: password
            visible: page.useUserPassword
            Kirigami.FormData.label: i18n("Password:")
            echoMode: TextInput.Password
            Layout.fillWidth: true
        }

        QQC2.SpinBox {
            id: refreshInterval
            Kirigami.FormData.label: i18n("Refresh interval (seconds):")
            from: 10
            to: 86400
            stepSize: 10
        }

        QQC2.ComboBox {
            id: severityThreshold
            Kirigami.FormData.label: i18n("Show problems with severity at least:")
            model: [
                i18n("Not classified"),
                i18n("Information"),
                i18n("Warning"),
                i18n("Average"),
                i18n("High"),
                i18n("Disaster")
            ]
        }

        QQC2.CheckBox {
            id: includeAcknowledged
            text: i18n("Show acknowledged problems")
        }

        QQC2.SpinBox {
            id: maxProblems
            Kirigami.FormData.label: i18n("Maximum problems to show:")
            from: 1
            to: 100
        }

        QQC2.SpinBox {
            id: maxProblemAgeHours
            Kirigami.FormData.label: i18n("Only show problems newer than (hours, 0 = no limit):")
            from: 0
            to: 8760
            stepSize: 6
        }

        QQC2.CheckBox {
            id: openWebUi
            text: i18n("Open the problem in the web browser when clicked")
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            opacity: 0.7
            wrapMode: Text.WordWrap
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            text: i18n("Note: the password is stored unencrypted in the Plasma widget configuration. A dedicated Zabbix API user with read-only permissions is recommended.")
        }
    }
}
