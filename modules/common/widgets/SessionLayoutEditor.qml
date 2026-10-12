import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models

ColumnLayout {
    id: root
    Layout.fillWidth: true
    width: parent.width
    spacing: 8

    property var layoutEntries: []
    property bool ready: false
    property string filePath: FileUtils.trimFileProtocol(`${Directories.home}/.config/hypr/custom/session_layout.json`)

    function reload() {
        layoutFileView.reload()
    }

    function save() {
        const jsonStr = JSON.stringify(root.layoutEntries, null, 2)
        layoutFileView.setText(jsonStr)
    }

    function addEntry() {
        let list = root.layoutEntries.slice(0)
        list.push({
            "workspace": 1,
            "name": "New App",
            "cmd": "",
            "match": "",
            "split": "root",
            "target": "",
            "width": 0,
            "height": 0,
            "timeout": 15
        })
        root.layoutEntries = list
        root.save()
    }

    function removeEntry(index) {
        let list = root.layoutEntries.slice(0)
        list.splice(index, 1)
        root.layoutEntries = list
        root.save()
    }

    function moveEntry(index, dir) {
        let targetIdx = index + dir
        if (targetIdx < 0 || targetIdx >= root.layoutEntries.length) return
        let list = root.layoutEntries.slice(0)
        let temp = list[index]
        list[index] = list[targetIdx]
        list[targetIdx] = temp
        root.layoutEntries = list
        root.save()
    }

    function updateEntry(index, key, value) {
        if (index < 0 || index >= root.layoutEntries.length) return
        let list = root.layoutEntries.slice(0)
        list[index][key] = value
        root.layoutEntries = list
        root.save()
    }

    FileView {
        id: layoutFileView
        path: root.filePath
        watchChanges: true
        onLoaded: {
            try {
                const txt = layoutFileView.text()
                if (txt && txt.trim().length > 0) {
                    root.layoutEntries = JSON.parse(txt)
                    root.ready = true
                }
            } catch (e) {
                console.warn("[SessionLayoutEditor] Error parsing layout JSON:", e)
            }
        }
    }

    Process {
        id: captureProc
        command: ["python3", "/home/schnee/.config/hypr/scripts/layout_engine.py", "--capture"]
        onRunningChanged: {
            if (!running) {
                root.reload()
            }
        }
    }

    Process {
        id: testRunProc
        command: ["bash", "-c", "rm -f /tmp/hypr-autostart-*.lock && python3 /home/schnee/.config/hypr/scripts/layout_engine.py --run"]
    }

    // Top Action Toolbar
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        GroupedList {
            Layout.fillWidth: true
            ConfigSwitch {
                buttonIcon: "desktop_windows"
                text: Translation.tr("Restore window layout on boot")
                checked: Config.options.hyprland.sessionAutostart ?? false
                onCheckedChanged: {
                    if (checked === (Config.options.hyprland.sessionAutostart ?? false)) return
                    Config.options.hyprland.sessionAutostart = checked
                    Quickshell.execDetached(["bash", "-c", `chmod ${checked ? "+x" : "-x"} ~/.config/hypr/scripts/autostart.sh`])
                }
            }
        }

        // Capture Live Windows Button
        RippleButton {
            id: captureBtn
            Layout.preferredHeight: 38
            implicitWidth: captureRow.implicitWidth + 24
            buttonRadius: Appearance.rounding.small
            colBackground: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.4)
            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.2)
            colRipple: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.1)
            enabled: !captureProc.running
            onClicked: captureProc.running = true

            RowLayout {
                id: captureRow
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: captureProc.running ? "sync" : "screenshot_monitor"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSecondaryContainer
                }
                StyledText {
                    text: captureProc.running ? Translation.tr("Capturing...") : Translation.tr("Capture Live")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }
        }

        // Test Run Button
        RippleButton {
            id: runBtn
            Layout.preferredHeight: 38
            implicitWidth: runRow.implicitWidth + 24
            buttonRadius: Appearance.rounding.small
            colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.4)
            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.2)
            colRipple: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.1)
            enabled: !testRunProc.running
            onClicked: testRunProc.running = true

            RowLayout {
                id: runRow
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: testRunProc.running ? "hourglass_top" : "motion_play"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnPrimaryContainer
                }
                StyledText {
                    text: testRunProc.running ? Translation.tr("Running...") : Translation.tr("Test Run")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }
        }

        // Add App Button
        RippleButton {
            id: addBtn
            Layout.preferredHeight: 38
            implicitWidth: addRow.implicitWidth + 24
            buttonRadius: Appearance.rounding.small
            colBackground: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.6)
            colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.5)
            onClicked: root.addEntry()

            RowLayout {
                id: addRow
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: "add"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    text: Translation.tr("Add App")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colPrimary
                }
            }
        }
    }

    // List of Layout Entries
    Repeater {
        id: layoutRepeater
        model: root.layoutEntries

        delegate: Rectangle {
            id: entryCard
            required property var modelData
            required property int index

            Layout.fillWidth: true
            implicitHeight: cardContent.implicitHeight + 20
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            ColumnLayout {
                id: cardContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                // Header Row: Workspace Badge, App Name, Up/Down, Delete
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialPill {
                        bgColor: Appearance.colors.colPrimaryContainer
                        StyledText {
                            text: `WS ${entryCard.modelData.workspace ?? 1}`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    StyledText {
                        text: entryCard.modelData.name || (entryCard.modelData.match || "App")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }

                    Item { Layout.fillWidth: true }

                    // Move Up Button
                    RippleButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        enabled: entryCard.index > 0
                        opacity: enabled ? 1 : 0.3
                        buttonRadius: 16
                        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.5)
                        onClicked: root.moveEntry(entryCard.index, -1)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "arrow_upward"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                        }
                    }

                    // Move Down Button
                    RippleButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        enabled: entryCard.index < root.layoutEntries.length - 1
                        opacity: enabled ? 1 : 0.3
                        buttonRadius: 16
                        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.5)
                        onClicked: root.moveEntry(entryCard.index, 1)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "arrow_downward"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                        }
                    }

                    // Delete Button
                    RippleButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        buttonRadius: 16
                        colBackground: ColorUtils.transparentize(Appearance.colors.colError, 0.85)
                        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colError, 0.6)
                        colRipple: ColorUtils.transparentize(Appearance.colors.colError, 0.5)
                        onClicked: root.removeEntry(entryCard.index)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "delete"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colError
                        }
                    }
                }

                // Row 1: Command and Match Pattern
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 3
                        spacing: 2
                        StyledText {
                            text: Translation.tr("Command")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        MaterialTextArea {
                            id: cmdInput
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("e.g. kitty --class kitty-main")
                            text: entryCard.modelData.cmd ?? ""
                            wrapMode: TextEdit.Wrap
                            onTextChanged: {
                                if (text !== entryCard.modelData.cmd) {
                                    cmdTimer.restart()
                                }
                            }
                            Timer {
                                id: cmdTimer
                                interval: 600
                                onTriggered: root.updateEntry(entryCard.index, "cmd", cmdInput.text)
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 2
                        spacing: 2
                        StyledText {
                            text: Translation.tr("Window Class Matcher")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        MaterialTextArea {
                            id: matchInput
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("e.g. kitty-main")
                            text: entryCard.modelData.match ?? ""
                            onTextChanged: {
                                if (text !== entryCard.modelData.match) {
                                    matchTimer.restart()
                                }
                            }
                            Timer {
                                id: matchTimer
                                interval: 600
                                onTriggered: root.updateEntry(entryCard.index, "match", matchInput.text)
                            }
                        }
                    }
                }

                // Row 2: Workspace, Split Position, Target Parent, Width, Height
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Workspace
                    ColumnLayout {
                        spacing: 2
                        StyledText {
                            text: Translation.tr("Workspace")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        ConfigSpinBox {
                            width: 105
                            from: 1
                            to: 20
                            value: entryCard.modelData.workspace ?? 1
                            onValueChanged: {
                                if (value !== entryCard.modelData.workspace) {
                                    root.updateEntry(entryCard.index, "workspace", value)
                                }
                            }
                        }
                    }

                    // Split Direction
                    ColumnLayout {
                        spacing: 2
                        StyledText {
                            text: Translation.tr("Split")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        ConfigSelectionArray {
                            currentValue: entryCard.modelData.split || "root"
                            onSelected: newValue => {
                                root.updateEntry(entryCard.index, "split", newValue)
                            }
                            options: [
                                { displayName: Translation.tr("Root"),  icon: "crop_square",     value: "root" },
                                { displayName: Translation.tr("Right"), icon: "arrow_forward",   value: "right" },
                                { displayName: Translation.tr("Down"),  icon: "arrow_downward",  value: "down" },
                            ]
                        }
                    }

                    // Target Parent (only visible if split is right or down)
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: (entryCard.modelData.split ?? "root") !== "root"
                        spacing: 2
                        StyledText {
                            text: Translation.tr("Target Parent Class")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        MaterialTextArea {
                            id: targetInput
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Parent class")
                            text: entryCard.modelData.target ?? ""
                            onTextChanged: {
                                if (text !== entryCard.modelData.target) {
                                    targetTimer.restart()
                                }
                            }
                            Timer {
                                id: targetTimer
                                interval: 600
                                onTriggered: root.updateEntry(entryCard.index, "target", targetInput.text)
                            }
                        }
                    }

                    // Width (px)
                    ColumnLayout {
                        spacing: 2
                        StyledText {
                            text: Translation.tr("Width (px)")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        ConfigSpinBox {
                            width: 120
                            from: 0
                            to: 3840
                            stepSize: 10
                            value: entryCard.modelData.width ?? 0
                            onValueChanged: {
                                if (value !== entryCard.modelData.width) {
                                    root.updateEntry(entryCard.index, "width", value)
                                }
                            }
                        }
                    }

                    // Height (px)
                    ColumnLayout {
                        spacing: 2
                        StyledText {
                            text: Translation.tr("Height (px)")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        ConfigSpinBox {
                            width: 120
                            from: 0
                            to: 2160
                            stepSize: 10
                            value: entryCard.modelData.height ?? 0
                            onValueChanged: {
                                if (value !== entryCard.modelData.height) {
                                    root.updateEntry(entryCard.index, "height", value)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
