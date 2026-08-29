import QtQuick
import Quickshell

Item {
    id: root

    property bool textured: true
    implicitHeight: root.textured ? 18 : 13

    Image {
        anchors.fill: parent
        visible: root.textured
        source: Quickshell.shellPath("assets/divider_ornate.png")
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: 0.82
    }

    Rectangle {
        visible: !root.textured
        anchors.left: parent.left
        anchors.right: centerMark.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: TenebrisTheme.borderDim
    }

    Text {
        id: centerMark
        visible: !root.textured
        anchors.centerIn: parent
        text: "✠"
        color: TenebrisTheme.border
        font.family: TenebrisTheme.serifFont
        font.pixelSize: 10
    }

    Rectangle {
        visible: !root.textured
        anchors.left: centerMark.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: TenebrisTheme.borderDim
    }
}
