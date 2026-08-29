import QtQuick
import Quickshell

Item {
    id: root

    property real band0: 0
    property real band1: 0
    property real band2: 0
    property real band3: 0
    property real band4: 0
    property real band5: 0
    property real band6: 0
    property real band7: 0
    property real band8: 0
    property real band9: 0
    property real band10: 0
    property real band11: 0
    property real band12: 0
    property real band13: 0
    property real band14: 0
    property real band15: 0
    property real energy: 0
    property real peak: 0
    property bool playing: false
    property string trackKey: "THE BLACK ARCHIVE"

    readonly property real span: Math.min(width, height)
    readonly property real sealSize: span * 0.52
    readonly property real spectrumRadius: span * 0.27

    function bandAt(index) {
        switch (index) {
        case 0: return root.band0;
        case 1: return root.band1;
        case 2: return root.band2;
        case 3: return root.band3;
        case 4: return root.band4;
        case 5: return root.band5;
        case 6: return root.band6;
        case 7: return root.band7;
        case 8: return root.band8;
        case 9: return root.band9;
        case 10: return root.band10;
        case 11: return root.band11;
        case 12: return root.band12;
        case 13: return root.band13;
        case 14: return root.band14;
        case 15: return root.band15;
        }
        return 0;
    }

    Item {
        anchors.centerIn: parent
        width: root.span
        height: width

        Repeater {
            model: 16

            Item {
                required property int index
                anchors.fill: parent
                rotation: index * 22.5

                Rectangle {
                    readonly property real amplitude: Math.max(0, Math.min(1, root.bandAt(parent.index)))
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.5 - root.spectrumRadius - height
                    width: amplitude > 0.72 ? 2 : 1
                    height: 4 + amplitude * root.span * 0.17
                    radius: width * 0.5
                    color: amplitude > 0.76 ? "#b51d24" : "#d7d1c7"
                    opacity: 0.22 + amplitude * 0.70

                    Behavior on height {
                        NumberAnimation { duration: 82; easing.type: Easing.OutQuad }
                    }
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.sealSize * 1.18
            height: width
            radius: width * 0.5
            color: "transparent"
            border.width: 1
            border.color: "#706d66"
            opacity: 0.52

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 36000
                loops: Animation.Infinite
                running: root.visible && root.playing
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.sealSize * 0.88
            height: width
            radius: width * 0.5
            color: "transparent"
            border.width: 1
            border.color: "#b8b2a7"
            opacity: 0.42 + root.energy * 0.30

            RotationAnimator on rotation {
                from: 360
                to: 0
                duration: 27000
                loops: Animation.Infinite
                running: root.visible && root.playing
            }
        }

        Repeater {
            model: 8

            Item {
                required property int index
                anchors.fill: parent
                rotation: index * 45

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.5 - root.sealSize * 0.61
                    width: 2
                    height: 7 + root.energy * 8
                    color: index % 3 === 0 && root.peak > 0.58 ? "#b51d24" : "#aaa49a"
                    opacity: 0.58
                }
            }
        }

        Image {
            anchors.centerIn: parent
            width: root.sealSize
            height: width
            source: Quickshell.shellPath("assets/large_sigil.png")
            fillMode: Image.PreserveAspectFit
            opacity: 0.40 + root.energy * 0.26
            smooth: true

            RotationAnimator on rotation {
                from: -1.8
                to: 1.8
                duration: 4600
                loops: Animation.Infinite
                running: root.visible && root.playing
                easing.type: Easing.InOutSine
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 4 + root.energy * 7
            height: width
            radius: width * 0.5
            color: root.peak > 0.66 ? "#b51d24" : "#d7d1c7"
            opacity: 0.78
        }
    }
}
