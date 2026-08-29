import QtQuick

Item {
    id: root

    property url asset: ""
    property string label: ""
    property string badgeText: ""
    signal invoked(int button)

    readonly property bool hovered: utilityMouse.containsMouse

    width: 32
    height: 34

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        color: utilityMouse.pressed
            ? TenebrisTheme.bloodDark
            : (root.hovered ? "#B31A1918" : "transparent")
        border.color: root.hovered ? TenebrisTheme.border : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: TenebrisTheme.motionFast } }
        Behavior on border.color { ColorAnimation { duration: TenebrisTheme.motionFast } }
    }

    Image {
        anchors.centerIn: parent
        width: 20
        height: 20
        source: root.asset
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: root.hovered ? 1.0 : 0.82

        Behavior on opacity { NumberAnimation { duration: TenebrisTheme.motionFast } }
    }

    Text {
        visible: root.badgeText.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        text: root.badgeText
        color: root.hovered ? TenebrisTheme.bone : TenebrisTheme.textMuted
        font.family: TenebrisTheme.monoFont
        font.pixelSize: 5
        font.letterSpacing: 0.2
    }

    Rectangle {
        visible: root.hovered
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: 10
        height: 1
        color: TenebrisTheme.bloodBright
    }

    MouseArea {
        id: utilityMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) { root.invoked(mouse.button) }
    }
}
