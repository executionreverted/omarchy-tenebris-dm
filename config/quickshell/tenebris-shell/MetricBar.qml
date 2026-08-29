import QtQuick

Item {
    id: root

    property string label: "CORE"
    property string valueText: "0%"
    property real value: 0
    property bool critical: false

    implicitHeight: 34

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        text: root.label
        color: root.critical ? TenebrisTheme.bloodBright : TenebrisTheme.silver
        font.family: TenebrisTheme.contentFont
        font.pixelSize: TenebrisTheme.typeBody
        font.bold: true
        font.letterSpacing: 0.8
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        text: root.valueText
        color: root.critical ? TenebrisTheme.bloodBright : TenebrisTheme.text
        font.family: TenebrisTheme.contentFont
        font.pixelSize: TenebrisTheme.typeBody
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 3
        color: "#34322F"

        Rectangle {
            height: parent.height
            width: parent.width * Math.max(0, Math.min(100, root.value)) / 100
            color: root.critical ? TenebrisTheme.bloodBright : TenebrisTheme.silver
            Behavior on width { NumberAnimation { duration: TenebrisTheme.motionNormal; easing.type: Easing.OutCubic } }
        }
    }
}
