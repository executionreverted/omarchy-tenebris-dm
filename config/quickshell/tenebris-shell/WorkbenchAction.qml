import QtQuick
import QtQuick.Controls as Controls
import Quickshell

Rectangle {
    id: root

    property url asset: ""
    property string label: ""
    property bool enabled: true
    property real iconOffsetX: 0
    property real iconOffsetY: 0
    signal invoked()

    width: 30
    height: 30
    color: actionMouse.containsMouse && root.enabled ? "#2B1113" : "#A00A0A0A"
    border.color: actionMouse.containsMouse && root.enabled
        ? TenebrisTheme.bloodBright : TenebrisTheme.borderDim
    border.width: 1
    opacity: root.enabled ? 1.0 : 0.30

    Image {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: root.iconOffsetX
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.iconOffsetY
        width: 26
        height: 26
        source: root.asset
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: actionMouse.containsMouse && root.enabled ? 1.0 : 0.78
    }

    MouseArea {
        id: actionMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function(mouse) {
            mouse.accepted = true;
            if (root.enabled)
                root.invoked();
        }
    }

    Controls.ToolTip {
        visible: root.label.length > 0 && actionMouse.containsMouse
        text: root.label
        delay: 320
        timeout: 5000
        padding: 0

        background: Rectangle {
            color: "#F2050505"
            border.color: TenebrisTheme.border
            border.width: 1
            radius: 0
        }

        contentItem: Text {
            text: root.label
            color: root.enabled ? TenebrisTheme.bone : TenebrisTheme.textMuted
            font.family: TenebrisTheme.contentFont
            font.pixelSize: TenebrisTheme.typeMeta
            font.letterSpacing: 0.35
            leftPadding: 9
            rightPadding: 9
            topPadding: 6
            bottomPadding: 6
        }
    }
}
