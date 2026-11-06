/*
 * SPDX-FileCopyrightText: 2026 Mario Gielissen <mario@gielissen.org>
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * List of active Zabbix problems, colored by severity.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../code/zabbix.js" as Zabbix

ListView {
    id: listView

    property var problems: []
    property bool openWebUiOnProblem: true

    signal problemActivated(string eventid, string triggerid)

    model: problems
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

    function durationText(clock) {
        const seconds = Math.max(0, Math.floor(Date.now() / 1000) - clock);
        if (seconds < 60)
            return "<1m";
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60)
            return minutes + "m";
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return hours + "h " + (minutes % 60) + "m";
        const days = Math.floor(hours / 24);
        return days + "d " + (hours % 24) + "h";
    }

    delegate: QQC2.ItemDelegate {
        id: delegateItem

        required property var modelData
        required property int index

        width: ListView.view.width
        padding: Kirigami.Units.smallSpacing
        hoverEnabled: true
        onClicked: {
            if (listView.openWebUiOnProblem)
                listView.problemActivated(modelData.eventid, modelData.triggerid);
        }

        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            // Severity color strip
            Rectangle {
                Layout.preferredWidth: Kirigami.Units.smallSpacing
                Layout.fillHeight: true
                radius: width
                color: Zabbix.severityColor(modelData.severity)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: modelData.name
                    elide: Text.ElideRight
                    font.bold: modelData.severity >= 4
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    opacity: 0.7
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    elide: Text.ElideRight
                    text: modelData.host + " · " + listView.durationText(modelData.clock)
                        + (modelData.acknowledged ? " · " + i18n("acknowledged") : "")
                }
            }

            PlasmaComponents3.Label {
                text: listView.severityName(modelData.severity)
                color: Zabbix.severityColor(modelData.severity)
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }
    }

    footer: Item {
        height: Kirigami.Units.smallSpacing
    }

    function severityName(severity) {
        const names = [
            i18n("Not classified"),
            i18n("Information"),
            i18n("Warning"),
            i18n("Average"),
            i18n("High"),
            i18n("Disaster")
        ];
        const s = severity >= 0 && severity <= 5 ? severity : 0;
        return names[s];
    }
}
