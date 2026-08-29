import QtQuick

Item {
    id: root

    property date now: new Date()
    property bool use24Hour: true
    property real surge: 0

    readonly property bool hovered: sealMouse.containsMouse || readoutMouse.containsMouse
    readonly property real secondValue: now.getSeconds() + now.getMilliseconds() / 1000
    readonly property real minuteValue: now.getMinutes() + secondValue / 60
    readonly property real hourValue: (now.getHours() % 12) + minuteValue / 60
    readonly property real secondAngle: secondValue * 6
    readonly property real minuteAngle: minuteValue * 6
    readonly property real hourAngle: hourValue * 30
    readonly property real readoutHeight: 40
    readonly property real dialSize: Math.max(0,
        Math.min(width - 20, height - readoutHeight - 12))
    readonly property string primaryText: root.use24Hour
        ? Qt.formatDateTime(now, "HH:mm")
        : Qt.formatDateTime(now, "h:mm AP")
    readonly property string secondaryText: Qt.formatDateTime(now, "dd · MM · yyyy")
    readonly property var cardinalMarks: [
        { label: "XII", angle: -Math.PI / 2 },
        { label: "III", angle: 0 },
        { label: "VI", angle: Math.PI / 2 },
        { label: "IX", angle: Math.PI }
    ]

    function activateSeal() {
        root.use24Hour = !root.use24Hour;
        surgeAnimation.restart();
    }

    Timer {
        interval: 100
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    SequentialAnimation {
        id: surgeAnimation
        NumberAnimation {
            target: root
            property: "surge"
            from: 0
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "surge"
            from: 1
            to: 0
            duration: 900
            easing.type: Easing.OutExpo
        }
    }

    Item {
        id: sealStage
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.dialSize
        height: width

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 2
            height: width
            radius: width * 0.5
            color: "#0D000000"
            border.color: root.hovered ? TenebrisTheme.border : TenebrisTheme.borderDim
            border.width: 1
            opacity: 0.54

            Behavior on border.color {
                ColorAnimation { duration: TenebrisTheme.motionFast }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.70
            height: width
            radius: width * 0.5
            color: "transparent"
            border.color: TenebrisTheme.bloodBright
            border.width: 1
            opacity: 0.16 + root.surge * 0.60
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.78
            height: width
            radius: width * 0.5
            color: "transparent"
            border.color: TenebrisTheme.borderDim
            border.width: 1
            opacity: 0.54
        }

        Repeater {
            model: 60

            Item {
                required property int index
                readonly property real rawDistance: Math.abs(index - root.secondValue)
                readonly property real secondDistance: Math.min(rawDistance, 60 - rawDistance)
                readonly property bool major: index % 5 === 0
                anchors.fill: parent
                rotation: index * 6
                z: 3

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 7
                    width: parent.major ? 2 : 1
                    height: parent.secondDistance < 0.72
                        ? 11 : (parent.major ? 7 : 3)
                    color: parent.secondDistance < 0.72
                        ? TenebrisTheme.bloodBright
                        : (parent.major ? TenebrisTheme.silver : TenebrisTheme.border)
                    opacity: parent.secondDistance < 0.72
                        ? 0.98
                        : (parent.secondDistance < 2.4
                            ? 0.58 : (parent.major ? 0.56 : 0.28))

                    Behavior on height {
                        NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                    }
                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on opacity { NumberAnimation { duration: 130 } }
                }
            }
        }

        Repeater {
            model: root.cardinalMarks

            Text {
                required property var modelData
                x: sealStage.width * 0.5
                    + Math.cos(modelData.angle) * sealStage.width * 0.375
                    - implicitWidth * 0.5
                y: sealStage.height * 0.5
                    + Math.sin(modelData.angle) * sealStage.height * 0.375
                    - implicitHeight * 0.5
                text: modelData.label
                color: TenebrisTheme.textMuted
                font.family: TenebrisTheme.contentFont
                font.pixelSize: TenebrisTheme.typeCaption
                opacity: 0.64
                z: 4
            }
        }

        Item {
            id: hourHandLayer
            anchors.fill: parent
            rotation: root.hourAngle
            z: 5

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                height: parent.height * 0.31
                width: height * 0.231
                y: parent.height * 0.5 - height * 0.902
                source: Qt.resolvedUrl("assets/clock_hour_hand.png")
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                opacity: root.hovered ? 0.98 : 0.86
            }

            Behavior on rotation {
                RotationAnimation {
                    duration: 180
                    direction: RotationAnimation.Shortest
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            id: minuteHandLayer
            anchors.fill: parent
            rotation: root.minuteAngle
            z: 6

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                height: parent.height * 0.38
                width: height * 0.117
                y: parent.height * 0.5 - height * 0.937
                source: Qt.resolvedUrl("assets/clock_minute_hand.png")
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                opacity: root.hovered ? 1.0 : 0.90
            }

            Behavior on rotation {
                RotationAnimation {
                    duration: 140
                    direction: RotationAnimation.Shortest
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            anchors.fill: parent
            rotation: root.secondAngle
            z: 7

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.5 - parent.height * 0.335
                width: 1
                height: parent.height * 0.365
                color: TenebrisTheme.bloodBright
                opacity: 0.86
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.155 - 3
                width: 6
                height: 6
                radius: 3
                color: TenebrisTheme.bloodBright
                opacity: 0.90
            }
        }

        Rectangle {
            id: pivotHub
            anchors.centerIn: parent
            width: 18
            height: width
            radius: width * 0.5
            color: "#E50B0B0B"
            border.color: root.hovered ? TenebrisTheme.bloodBright : TenebrisTheme.blood
            border.width: 1
            z: 8

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.46
                height: width
                rotation: 45
                color: TenebrisTheme.bloodDark
                border.color: TenebrisTheme.bloodBright
                border.width: 1
                opacity: 0.78 + root.surge * 0.18
            }
        }

        MouseArea {
            id: sealMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: 20
            onClicked: root.activateSeal()
        }
    }

    Item {
        id: clockReadout
        anchors.top: sealStage.bottom
        anchors.topMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 24, 190)
        height: root.readoutHeight
        opacity: 0.82 + root.surge * 0.18

        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.58
            height: 1
            color: root.use24Hour ? TenebrisTheme.borderDim : TenebrisTheme.blood

            Behavior on color { ColorAnimation { duration: TenebrisTheme.motionFast } }
        }

        Text {
            anchors.top: parent.top
            anchors.topMargin: 5
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.primaryText
            color: TenebrisTheme.bone
            font.family: TenebrisTheme.contentFont
            font.pixelSize: TenebrisTheme.typeLead
            font.bold: true
            font.letterSpacing: 1.0
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.secondaryText
            color: TenebrisTheme.textMuted
            font.family: TenebrisTheme.contentFont
            font.pixelSize: TenebrisTheme.typeCaption
            font.letterSpacing: 1.6
        }

        MouseArea {
            id: readoutMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activateSeal()
        }
    }
}
