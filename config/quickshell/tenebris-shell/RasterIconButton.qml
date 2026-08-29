import QtQuick

Item {
    id: root

    property url asset
    property string label: "ARCHIVE"
    property bool active: false
    signal invoked()

    implicitWidth: 76
    implicitHeight: 66
    clip: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        color: mouse.containsMouse ? "#211012" : "transparent"
        border.color: root.active ? TenebrisTheme.bloodBright
            : (mouse.containsMouse ? TenebrisTheme.blood : "transparent")
        border.width: 1

        Behavior on color { ColorAnimation { duration: TenebrisTheme.motionFast } }
        Behavior on border.color { ColorAnimation { duration: TenebrisTheme.motionFast } }
    }

    Image {
        id: icon
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: 48
        height: 47
        source: root.asset
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: mouse.containsMouse || root.active ? 1.0 : 0.82

        Behavior on opacity { NumberAnimation { duration: TenebrisTheme.motionFast } }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        text: root.label
        color: root.active ? TenebrisTheme.bone : TenebrisTheme.textMuted
        font.family: TenebrisTheme.contentFont
        font.pixelSize: TenebrisTheme.typeMeta
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.5
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    Rectangle {
        visible: root.active || mouse.containsMouse
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: parent.height - 14
        color: root.active ? TenebrisTheme.bloodBright : TenebrisTheme.blood
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.invoked()
    }
}
