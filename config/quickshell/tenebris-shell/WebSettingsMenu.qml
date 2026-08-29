import QtQuick
import Quickshell

Rectangle {
    id: root

    property bool webEnabled: true
    property real webDensity: 0.95
    property real windStrength: 1.75
    property real motionAmount: 2.0
    property int renderFps: 30
    property real renderScale: 0.75
    property int idleSeconds: 90
    property int weaveSeconds: 30

    signal closeRequested()
    signal enabledRequested(bool value)
    signal densityRequested(real value)
    signal windRequested(real value)
    signal motionRequested(real value)
    signal fpsRequested(int value)
    signal renderScaleRequested(real value)
    signal idleRequested(int value)
    signal weaveRequested(int value)
    signal previewRequested()

    implicitWidth: 286
    implicitHeight: 414
    color: "#0B0B0B"
    border.color: TenebrisTheme.border
    border.width: 1
    radius: 0

    component StepperRow: Item {
        id: stepper

        required property string title
        required property real value
        property real minimum: 0
        property real maximum: 1
        property real step: 0.1
        property int decimals: 2
        property string suffix: ""
        signal adjusted(real value)

        width: parent ? parent.width : 0
        height: 37

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: stepper.title
            color: TenebrisTheme.textMuted
            font.family: TenebrisTheme.contentFont
            font.pixelSize: TenebrisTheme.typeMeta
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Rectangle {
                width: 24
                height: 22
                color: minusMouse.containsMouse ? "#282725" : "#171716"
                border.color: TenebrisTheme.borderDim

                Text {
                    anchors.centerIn: parent
                    text: "−"
                    color: TenebrisTheme.silver
                    font.family: TenebrisTheme.contentFont
                    font.pixelSize: 12
                }

                MouseArea {
                    id: minusMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stepper.adjusted(Math.max(
                        stepper.minimum,
                        stepper.value - stepper.step
                    ))
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 61
                horizontalAlignment: Text.AlignHCenter
                text: Number(stepper.value).toFixed(stepper.decimals) + stepper.suffix
                color: TenebrisTheme.text
                font.family: TenebrisTheme.contentFont
                font.pixelSize: TenebrisTheme.typeBody
            }

            Rectangle {
                width: 24
                height: 22
                color: plusMouse.containsMouse ? "#282725" : "#171716"
                border.color: TenebrisTheme.borderDim

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: TenebrisTheme.silver
                    font.family: TenebrisTheme.contentFont
                    font.pixelSize: 11
                }

                MouseArea {
                    id: plusMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stepper.adjusted(Math.min(
                        stepper.maximum,
                        stepper.value + stepper.step
                    ))
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#272624"
        }
    }

    Repeater {
        model: [
            { x: 3, y: 3, rotation: 0 },
            { x: root.width - 27, y: 3, rotation: 90 },
            { x: root.width - 27, y: root.height - 27, rotation: 180 },
            { x: 3, y: root.height - 27, rotation: 270 }
        ]

        Image {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: 24
            height: 24
            rotation: modelData.rotation
            transformOrigin: Item.Center
            source: Quickshell.shellPath("assets/frame_corner.png")
            fillMode: Image.PreserveAspectFit
            opacity: 0.54
        }
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 15
        anchors.bottomMargin: 14
        spacing: 0

        Item {
            width: parent.width
            height: 43

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Web of Silence"
                color: TenebrisTheme.bone
                font.family: TenebrisTheme.panelFont
                font.pixelSize: 16
                font.letterSpacing: 0.8
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "×"
                color: closeMouse.containsMouse ? TenebrisTheme.bone : TenebrisTheme.textMuted
                font.family: TenebrisTheme.contentFont
                font.pixelSize: 17

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 37
            color: enabledMouse.containsMouse ? "#1D1C1B" : "transparent"

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Screensaver"
                color: TenebrisTheme.textMuted
                font.family: TenebrisTheme.contentFont
                font.pixelSize: TenebrisTheme.typeMeta
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 17
                color: "transparent"
                border.color: root.webEnabled ? TenebrisTheme.silver : TenebrisTheme.borderDim

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.webEnabled ? parent.width - width - 3 : 3
                    width: 11
                    height: 11
                    color: root.webEnabled ? TenebrisTheme.silver : "#494744"

                    Behavior on x {
                        NumberAnimation { duration: TenebrisTheme.motionFast }
                    }
                }
            }

            MouseArea {
                id: enabledMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.enabledRequested(!root.webEnabled)
            }
        }

        StepperRow {
            title: "Silk density"
            value: root.webDensity
            minimum: 0.20
            maximum: 2.0
            step: 0.10
            decimals: 2
            onAdjusted: value => root.densityRequested(value)
        }

        StepperRow {
            title: "Wind load"
            value: root.windStrength
            minimum: 0
            maximum: 3.0
            step: 0.25
            decimals: 2
            onAdjusted: value => root.windRequested(value)
        }

        StepperRow {
            title: "Elastic motion"
            value: root.motionAmount
            minimum: 0
            maximum: 3.0
            step: 0.25
            decimals: 2
            onAdjusted: value => root.motionRequested(value)
        }

        StepperRow {
            title: "Frame rate"
            value: root.renderFps
            minimum: 10
            maximum: 60
            step: 5
            decimals: 0
            suffix: " fps"
            onAdjusted: value => root.fpsRequested(Math.round(value))
        }

        StepperRow {
            title: "Render scale"
            value: root.renderScale
            minimum: 0.50
            maximum: 1.0
            step: 0.05
            decimals: 2
            suffix: "×"
            onAdjusted: value => root.renderScaleRequested(value)
        }

        StepperRow {
            title: "Idle delay"
            value: root.idleSeconds
            minimum: 5
            maximum: 300
            step: 5
            decimals: 0
            suffix: "s"
            onAdjusted: value => root.idleRequested(Math.round(value))
        }

        StepperRow {
            title: "Weave time"
            value: root.weaveSeconds
            minimum: 10
            maximum: 180
            step: 5
            decimals: 0
            suffix: "s"
            onAdjusted: value => root.weaveRequested(Math.round(value))
        }

        Item {
            width: parent.width
            height: 42

            Rectangle {
                anchors.centerIn: parent
                width: 112
                height: 25
                color: previewMouse.containsMouse ? "#2A2927" : "#171716"
                border.color: TenebrisTheme.borderDim

                Text {
                    anchors.centerIn: parent
                    text: "Preview"
                    color: TenebrisTheme.text
                    font.family: TenebrisTheme.contentFont
                    font.pixelSize: TenebrisTheme.typeMeta
                }

                MouseArea {
                    id: previewMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.previewRequested()
                }
            }
        }
    }
}
