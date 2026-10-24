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
    spacing: 12

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
                    const parsed = JSON.parse(txt)
                    root.layoutEntries = Array.isArray(parsed) ? parsed : []
                } else {
                    root.layoutEntries = []
                }
            } catch (e) {
                console.warn("[SessionLayoutEditor] Error parsing layout JSON:", e)
                root.layoutEntries = []
            }
            root.ready = true
        }
        onLoadFailed: (error) => {
            console.warn("[SessionLayoutEditor] Failed to load layout file:", error)
            root.layoutEntries = []
            root.ready = true
        }
    }

    Process {
        id: captureProc
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/layout_engine.py", "--capture"]
        onRunningChanged: {
            if (!running) {
                root.reload()
            }
        }
    }

    Process {
        id: testRunProc
        command: ["bash", "-c", "rm -f /tmp/hypr-autostart-*.lock && python3 \"$HOME/.config/hypr/scripts/layout_engine.py\" --run"]
    }

    // Top Action Toolbar
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        GroupedList {
            Layout.fillWidth: true
            ConfigSwitch {
                buttonIcon: "desktop_windows"
                text: Translation.tr("Restore layout on boot")
                checked: Config.options.hyprland.sessionAutostart ?? false
                onCheckedChanged: {
                    if (checked === (Config.options.hyprland.sessionAutostart ?? false)) return
                    Config.options.hyprland.sessionAutostart = checked
                }
            }
        }

        // Capture Live Windows Button
        RippleButton {
            id: captureBtn
            Layout.preferredHeight: 38
            implicitWidth: captureRow.implicitWidth + 24
            buttonRadius: Appearance.rounding.small
            colBackground: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.35)
            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.15)
            colRipple: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.05)
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
            colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.35)
            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.15)
            colRipple: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.05)
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
            implicitHeight: cardContent.implicitHeight + 28
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            clip: true

            ColumnLayout {
                id: cardContent
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Header Row: Workspace Badge, App Name (editable), Up/Down, Delete
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Pill {
                        color: Appearance.colors.colPrimaryContainer
                        implicitWidth: wsLabel.implicitWidth + 20
                        implicitHeight: 32
                        StyledText {
                            id: wsLabel
                            anchors.centerIn: parent
                            text: `WS ${entryCard.modelData.workspace ?? 1}`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    StyledTextInput {
                        id: nameInput
                        Layout.fillWidth: true
                        text: entryCard.modelData.name || (entryCard.modelData.match || "App")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                        onEditingFinished: {
                            if (text !== entryCard.modelData.name) {
                                root.updateEntry(entryCard.index, "name", text)
                            }
                        }
                    }

                    // Move Up, Move Down, Delete
                    RowLayout {
                        spacing: 4

                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            enabled: entryCard.index > 0
                            opacity: enabled ? 1 : 0.3
                            buttonRadius: Appearance.rounding.small
                            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.6)
                            onClicked: root.moveEntry(entryCard.index, -1)
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "arrow_upward"
                                iconSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            enabled: entryCard.index < root.layoutEntries.length - 1
                            opacity: enabled ? 1 : 0.3
                            buttonRadius: Appearance.rounding.small
                            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.6)
                            onClicked: root.moveEntry(entryCard.index, 1)
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "arrow_downward"
                                iconSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.small
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
                }

                // Subtle Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0Border, 0.5)
                }

                // Row 1: Command and Match Pattern
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 3
                        spacing: 4
                        StyledText {
                            text: Translation.tr("Command (CLI)")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                        MaterialTextField {
                            id: cmdInput
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("e.g. kitty --class kitty-main")
                            text: entryCard.modelData.cmd ?? ""
                            onEditingFinished: {
                                if (text !== entryCard.modelData.cmd) {
                                    root.updateEntry(entryCard.index, "cmd", text)
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 2
                        spacing: 4
                        StyledText {
                            text: Translation.tr("Window Class Matcher")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                        MaterialTextField {
                            id: matchInput
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("e.g. kitty-main")
                            text: entryCard.modelData.match ?? ""
                            onEditingFinished: {
                                if (text !== entryCard.modelData.match) {
                                    root.updateEntry(entryCard.index, "match", text)
                                }
                            }
                        }
                    }
                }

                // Row 2: Workspace, Split Position, Target Parent, Width, Height
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Workspace
                    ColumnLayout {
                        spacing: 4
                        StyledText {
                            text: Translation.tr("Workspace")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
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

                    // Split Direction (Segmented Buttons)
                    ColumnLayout {
                        spacing: 4
                        StyledText {
                            text: Translation.tr("Split Direction")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                        RowLayout {
                            spacing: 2
                            SelectionGroupButton {
                                buttonText: Translation.tr("Root")
                                buttonIcon: "crop_square"
                                toggled: (entryCard.modelData.split || "root") === "root"
                                leftmost: true
                                onClicked: root.updateEntry(entryCard.index, "split", "root")
                            }
                            SelectionGroupButton {
                                buttonText: Translation.tr("Right")
                                buttonIcon: "arrow_forward"
                                toggled: (entryCard.modelData.split || "root") === "right"
                                onClicked: root.updateEntry(entryCard.index, "split", "right")
                            }
                            SelectionGroupButton {
                                buttonText: Translation.tr("Down")
                                buttonIcon: "arrow_downward"
                                toggled: (entryCard.modelData.split || "root") === "down"
                                rightmost: true
                                onClicked: root.updateEntry(entryCard.index, "split", "down")
                            }
                        }
                    }

                    // Target Parent (only visible if split is right or down)
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: (entryCard.modelData.split || "root") !== "root"
                        spacing: 4
                        StyledText {
                            text: Translation.tr("Parent Class")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                        MaterialTextField {
                            id: targetInput
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("e.g. kitty-fastfetch")
                            text: entryCard.modelData.target ?? ""
                            onEditingFinished: {
                                if (text !== entryCard.modelData.target) {
                                    root.updateEntry(entryCard.index, "target", text)
                                }
                            }
                        }
                    }

                    // Target Size (W × H px)
                    ColumnLayout {
                        spacing: 4
                        StyledText {
                            text: Translation.tr("Target Size (W × H px)")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                        RowLayout {
                            spacing: 6
                            MaterialTextField {
                                implicitWidth: 80
                                placeholderText: Translation.tr("Auto")
                                text: (entryCard.modelData.width ?? 0) > 0 ? `${entryCard.modelData.width}` : ""
                                validator: IntValidator { bottom: 0; top: 7680 }
                                onEditingFinished: {
                                    const val = parseInt(text) || 0
                                    if (val !== (entryCard.modelData.width ?? 0)) {
                                        root.updateEntry(entryCard.index, "width", val)
                                    }
                                }
                            }
                            StyledText {
                                text: "×"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colSubtext
                            }
                            MaterialTextField {
                                implicitWidth: 80
                                placeholderText: Translation.tr("Auto")
                                text: (entryCard.modelData.height ?? 0) > 0 ? `${entryCard.modelData.height}` : ""
                                validator: IntValidator { bottom: 0; top: 7680 }
                                onEditingFinished: {
                                    const val = parseInt(text) || 0
                                    if (val !== (entryCard.modelData.height ?? 0)) {
                                        root.updateEntry(entryCard.index, "height", val)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
