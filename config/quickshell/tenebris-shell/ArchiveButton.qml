import QtQuick

Rectangle {
    id: root

    property string glyph: "✠"
    property string label: "ARCHIVE"
    property string detail: ""
    property bool active: false
    signal invoked()

    implicitWidth: 64
    implicitHeight: 62
    color: mouse.containsMouse ? "#181716" : "transparent"
    border.color: active ? TenebrisTheme.blood : (mouse.containsMouse ? TenebrisTheme.border : "transparent")
    border.width: 1
    radius: TenebrisTheme.radiusSmall

    Behavior on color { ColorAnimation { duration: TenebrisTheme.motionFast } }
    Behavior on border.color { ColorAnimation { duration: TenebrisTheme.motionFast } }

    Rectangle {
        visible: root.active || mouse.containsMouse
        width: 2
        height: parent.height - 12
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: root.active ? TenebrisTheme.bloodBright : TenebrisTheme.blood
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        text: root.glyph
        color: root.active ? TenebrisTheme.bone : TenebrisTheme.silver
        font.family: TenebrisTheme.monoFont
        font.pixelSize: 20
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 7
        text: root.label
        color: root.active ? TenebrisTheme.bone : TenebrisTheme.textMuted
        font.family: TenebrisTheme.contentFont
        font.pixelSize: TenebrisTheme.typeMeta
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.5
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.invoked()
    }
}
