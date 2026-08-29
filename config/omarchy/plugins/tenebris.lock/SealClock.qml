import QtQuick 2.15

Item {
  id: root

  property date now: new Date()
  property bool use24Hour: true
  property url hourHandSource: ""
  property url minuteHandSource: ""
  property string bodyFont: "Noto Serif"

  readonly property real secondValue: now.getSeconds() + now.getMilliseconds() / 1000
  readonly property real minuteValue: now.getMinutes() + secondValue / 60
  readonly property real hourValue: (now.getHours() % 12) + minuteValue / 60
  readonly property real readoutHeight: Math.min(40, height * 0.24)
  readonly property real dialSize: Math.max(0, Math.min(width, height - readoutHeight - 6))
  readonly property var cardinalMarks: [
    { label: "XII", angle: -Math.PI / 2 },
    { label: "III", angle: 0 },
    { label: "VI", angle: Math.PI / 2 },
    { label: "IX", angle: Math.PI }
  ]

  Timer {
    interval: 100
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  Item {
    id: dial
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.dialSize
    height: width

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: "#18000000"
      border.color: clockMouse.containsMouse ? "#706B62" : "#3C3935"
      border.width: 1
      opacity: 0.72
      Behavior on border.color { ColorAnimation { duration: 140 } }
    }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 0.78
      height: width
      radius: width / 2
      color: "transparent"
      border.color: "#46423D"
      border.width: 1
      opacity: 0.58
    }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 0.70
      height: width
      radius: width / 2
      color: "transparent"
      border.color: "#7C0E13"
      border.width: 1
      opacity: 0.20
    }

    Repeater {
      model: 60

      Item {
        property int markIndex: index
        readonly property real rawDistance: Math.abs(markIndex - root.secondValue)
        readonly property real secondDistance: Math.min(rawDistance, 60 - rawDistance)
        readonly property bool major: markIndex % 5 === 0
        anchors.fill: parent
        rotation: markIndex * 6

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          y: Math.max(4, dial.width * 0.04)
          width: parent.major ? 2 : 1
          height: parent.secondDistance < 0.72
            ? dial.width * 0.075 : (parent.major ? dial.width * 0.050 : dial.width * 0.022)
          color: parent.secondDistance < 0.72
            ? "#B51D24" : (parent.major ? "#B8B2A7" : "#66625B")
          opacity: parent.secondDistance < 0.72 ? 0.98 : (parent.major ? 0.60 : 0.30)
        }
      }
    }

    Repeater {
      model: root.cardinalMarks

      Text {
        property var mark: modelData
        x: dial.width * 0.5 + Math.cos(mark.angle) * dial.width * 0.36 - implicitWidth * 0.5
        y: dial.height * 0.5 + Math.sin(mark.angle) * dial.height * 0.36 - implicitHeight * 0.5
        text: mark.label
        color: "#8A867F"
        font.family: root.bodyFont
        font.pixelSize: Math.max(7, dial.width * 0.055)
        opacity: 0.72
      }
    }

    Item {
      anchors.fill: parent
      rotation: root.hourValue * 30
      z: 4

      Image {
        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height * 0.31
        width: height * 0.231
        y: parent.height * 0.5 - height * 0.902
        source: root.hourHandSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: 0.90
      }

      Behavior on rotation {
        RotationAnimation { duration: 180; direction: RotationAnimation.Shortest }
      }
    }

    Item {
      anchors.fill: parent
      rotation: root.minuteValue * 6
      z: 5

      Image {
        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height * 0.38
        width: height * 0.117
        y: parent.height * 0.5 - height * 0.937
        source: root.minuteHandSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: 0.94
      }

      Behavior on rotation {
        RotationAnimation { duration: 140; direction: RotationAnimation.Shortest }
      }
    }

    Item {
      anchors.fill: parent
      rotation: root.secondValue * 6
      z: 6

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.165
        width: 1
        height: parent.height * 0.365
        color: "#B51D24"
        opacity: 0.88
      }
    }

    Rectangle {
      anchors.centerIn: parent
      width: Math.max(10, parent.width * 0.11)
      height: width
      radius: width / 2
      color: "#E50B0B0B"
      border.color: "#7C0E13"
      border.width: 1
      z: 7

      Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.46
        height: width
        rotation: 45
        color: "#4E090C"
        border.color: "#B51D24"
        border.width: 1
        opacity: 0.82
      }
    }

    MouseArea {
      id: clockMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      z: 20
      onClicked: root.use24Hour = !root.use24Hour
    }
  }

  Item {
    anchors.top: dial.bottom
    anchors.topMargin: 5
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(parent.width, 190)
    height: root.readoutHeight

    Rectangle {
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width * 0.58
      height: 1
      color: "#46423D"
    }

    Text {
      anchors.top: parent.top
      anchors.topMargin: 4
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.use24Hour ? Qt.formatDateTime(root.now, "HH:mm")
        : Qt.formatDateTime(root.now, "h:mm AP")
      color: "#D8D1C5"
      font.family: root.bodyFont
      font.pixelSize: Math.max(10, root.readoutHeight * 0.40)
      font.bold: true
      font.letterSpacing: 1
    }

    Text {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDateTime(root.now, "dd · MM · yyyy")
      color: "#77736D"
      font.family: root.bodyFont
      font.pixelSize: Math.max(7, root.readoutHeight * 0.24)
      font.letterSpacing: 1.2
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.use24Hour = !root.use24Hour
    }
  }
}
