/*
 * Zabbix widget for KDE Plasma 6
 *
 * Shows active Zabbix problems (triggers) via the Zabbix JSON-RPC API,
 * colored by severity. Supports API-token auth (Zabbix >= 5.4) and
 * username/password auth (also works on older versions).
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import "../code/zabbix.js" as Zabbix

PlasmoidItem {
    id: root

    readonly property bool configured: Plasmoid.configuration.serverUrl !== ""
        && (Plasmoid.configuration.authMode === "userpass"
            ? (Plasmoid.configuration.username !== "" && Plasmoid.configuration.password !== "")
            : Plasmoid.configuration.apiToken !== "")

    property var problems: []
    // "" | "loading" | "ok" | "error"
    property string status: ""
    property string errorMessage: ""
    property date lastCheck: new Date(0)

    readonly property int problemCount: problems.length
    readonly property int worstSeverity: {
        let worst = 0;
        for (let i = 0; i < problems.length; ++i) {
            if (problems[i].severity > worst)
                worst = problems[i].severity;
        }
        return worst;
    }

    readonly property var severityNames: [
        i18n("Not classified"),
        i18n("Information"),
        i18n("Warning"),
        i18n("Average"),
        i18n("High"),
        i18n("Disaster")
    ]

    // ---------------------------------------------------------------- API ---

    function fetchOptions() {
        return {
            url: Plasmoid.configuration.serverUrl,
            authMode: Plasmoid.configuration.authMode,
            token: Plasmoid.configuration.apiToken,
            username: Plasmoid.configuration.username,
            password: Plasmoid.configuration.password
        };
    }

    function refresh() {
        if (!root.configured) {
            root.status = "";
            root.problems = [];
            return;
        }
        if (root.status === "loading")
            return;

        root.status = "loading";
        root.errorMessage = "";

        const severities = [];
        for (let s = Plasmoid.configuration.severityThreshold; s <= 5; ++s)
            severities.push(String(s));

        Zabbix.fetchProblems(root.fetchOptions(), {
            severities: severities,
            includeAcknowledged: Plasmoid.configuration.includeAcknowledged,
            limit: Plasmoid.configuration.maxProblems,
            maxAgeHours: Plasmoid.configuration.maxProblemAgeHours
        }, function (err, problems) {
            if (err) {
                root.status = "error";
                root.errorMessage = (err.message || i18n("Error")) +
                    (err.data ? (": " + err.data) : "");
                return;
            }
            // Most severe first; longest-running first within a severity.
            problems.sort(function (a, b) {
                if (a.severity !== b.severity)
                    return b.severity - a.severity;
                return a.clock - b.clock;
            });
            root.problems = problems;
            root.lastCheck = new Date();
            root.status = "ok";
        });
    }

    function openWebUi(eventid, triggerid) {
        const base = Zabbix.normalizeUrl(Plasmoid.configuration.serverUrl);
        if (base === "")
            return;
        if (eventid && triggerid)
            Qt.openUrlExternally(base + "/tr_events.php?triggerid=" + triggerid + "&eventid=" + eventid);
        else
            Qt.openUrlExternally(base + "/");
    }

    function formatDuration(seconds) {
        if (seconds < 60)
            return i18n("%1 seconds", seconds);
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60)
            return i18n("%1 minutes", minutes);
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return i18n("%1 hours %2", hours, i18n("%1 min", minutes % 60));
        return i18n("%1 days %2", Math.floor(hours / 24), hours % 24 + "h");
    }

    Component.onCompleted: refresh()

    Timer {
        id: refreshTimer
        interval: Math.max(10, Plasmoid.configuration.refreshInterval) * 1000
        running: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    // Re-fetch immediately when relevant settings change.
    Connections {
        target: Plasmoid.configuration
        function onServerUrlChanged() { Zabbix.sessionId = ""; root.refresh(); }
        function onAuthModeChanged() { Zabbix.sessionId = ""; root.refresh(); }
        function onApiTokenChanged() { root.refresh(); }
        function onUsernameChanged() { Zabbix.sessionId = ""; root.refresh(); }
        function onPasswordChanged() { Zabbix.sessionId = ""; root.refresh(); }
        function onSeverityThresholdChanged() { root.refresh(); }
        function onIncludeAcknowledgedChanged() { root.refresh(); }
        function onMaxProblemsChanged() { root.refresh(); }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh now")
            icon.name: "view-refresh"
            priority: Plasmoid.LowPriorityAction
            onTriggered: root.refresh()
        },
        PlasmaCore.Action {
            text: i18n("Open Zabbix web UI")
            icon.name: "globe"
            priority: Plasmoid.LowPriorityAction
            visible: root.configured
            onTriggered: root.openWebUi()
        }
    ]

    toolTipMainText: i18n("Zabbix")
    toolTipSubText: {
        if (!root.configured)
            return i18n("Not configured");
        if (root.status === "error")
            return root.errorMessage;
        if (root.problemCount === 0 && root.status === "ok")
            return i18n("No active problems");
        return i18np("%1 active problem", "%1 active problems", root.problemCount);
    }

    // ------------------------------------------------------- compact view ---

    compactRepresentation: PlasmaComponents3.ToolButton {
        id: compactButton

        icon.name: root.problemCount > 0 ? "dialog-warning" : "network-server"
        text: root.problemCount > 0 ? String(root.problemCount) : ""
        display: root.problemCount > 0 ? "TextBesideIcon" : "IconOnly"

        PlasmaComponents3.ToolTip {
            text: root.toolTipSubText
        }

        onClicked: root.expanded = true
    }

    // --------------------------------------------------------- full view ----

    fullRepresentation: ColumnLayout {
        id: fullView

        spacing: Kirigami.Units.smallSpacing

        Layout.minimumWidth: 240
        Layout.minimumHeight: 140
        Layout.preferredWidth: 420
        Layout.preferredHeight: 360

        // Header
        RowLayout {
            Layout.fillWidth: true

            Kirigami.Heading {
                text: i18n("Zabbix")
                level: 2
            }

            PlasmaComponents3.Label {
                visible: root.status === "ok" && root.problemCount > 0
                text: root.problemCount
                font.bold: true
                color: Zabbix.severityColor(root.worstSeverity)
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents3.BusyIndicator {
                running: root.status === "loading"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

            PlasmaComponents3.ToolButton {
                icon.name: "view-refresh"
                text: i18n("Refresh")
                PlasmaComponents3.ToolTip { text: parent.text }
                enabled: root.configured && root.status !== "loading"
                onClicked: root.refresh()
            }

            PlasmaComponents3.ToolButton {
                icon.name: "globe"
                text: i18n("Open Zabbix web UI")
                PlasmaComponents3.ToolTip { text: parent.text }
                visible: root.configured
                onClicked: root.openWebUi()
            }
        }

        // Not configured
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !root.configured
            type: Kirigami.MessageType.Information
            text: i18n("Open the settings of this widget to configure the Zabbix server URL and authentication.")
        }

        // Error
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.status === "error"
            type: Kirigami.MessageType.Warning
            text: root.errorMessage
            actions: [
                QQC2.Action {
                    text: i18n("Retry")
                    onTriggered: root.refresh()
                }
            ]
        }

        // Loading placeholder
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: root.status === "loading" && root.problemCount === 0
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.7
            text: i18n("Loading problems…")
        }

        // No problems
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: root.status === "ok" && root.problemCount === 0 && root.configured
            Item { Layout.fillWidth: true }
            Kirigami.Icon {
                source: "dialog-ok-apply"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                color: Kirigami.Theme.positiveTextColor
            }
            PlasmaComponents3.Label {
                text: i18n("No active problems")
                color: Kirigami.Theme.positiveTextColor
            }
            Item { Layout.fillWidth: true }
        }

        // Problem list
        ProblemList {
            visible: root.problemCount > 0
            problems: root.problems
            openWebUiOnProblem: Plasmoid.configuration.openWebUi
            onProblemActivated: (eventid, triggerid) => root.openWebUi(eventid, triggerid)
        }

        // Footer
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            visible: root.status === "ok"
            opacity: 0.6
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            horizontalAlignment: Text.AlignHCenter
            text: i18n("Last check: %1", Qt.formatDateTime(root.lastCheck, "hh:mm:ss"))
        }
    }
}
