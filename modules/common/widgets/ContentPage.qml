import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common

/**
 * Scrollable page container for settings panels.
 *
 * Uses an internal Flickable with an overlay MouseArea to delegate wheel
 * events to InertialScrollEngine for smooth, responsive scrolling.
 */
Item {
    id: root
    clip: true

    property real baseWidth: 600
    property bool forceWidth: false
    property real bottomContentPadding: Config.options.settings.style === "minimal" ? 40 : 90

    // Children placed in ContentPage appear inside the ColumnLayout
    default property alias data: contentColumn.data

    implicitWidth: contentColumn.implicitWidth

    // =========================================================
    // Inner Flickable
    // =========================================================
    Flickable {
        id: flickable
        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight + root.bottomContentPadding
        boundsBehavior: Flickable.DragOverBounds
        maximumFlickVelocity: 3500

        ScrollBar.vertical: StyledScrollBar {}

        ColumnLayout {
            id: contentColumn
            width: root.forceWidth ? root.baseWidth : Math.max(root.baseWidth, implicitWidth)
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                margins: 20
            }
            spacing: 30
        }

        InertialScrollEngine {
            id: scrollEngine
            flickable: flickable
        }
    }

    // =========================================================
    // MouseArea overlay — intercepts wheel before Flickable
    // acceptedButtons: Qt.NoButton → clicks/drags pass through to child widgets
    // =========================================================
    MouseArea {
        anchors.fill: parent
        z: 1
        acceptedButtons: Qt.NoButton
        onWheel: function(wheel) {
            scrollEngine.handleWheel(wheel)
        }
    }
}
