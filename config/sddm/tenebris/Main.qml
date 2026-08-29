import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
  id: root
  width: 1920
  height: 1080
  color: "#050505"

  property string currentUser: userModel.lastUser
  property bool loginFailed: false
  readonly property bool compactLayout: width < 760 || height < 520
  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
      if (name.indexOf("uwsm") !== -1 || name.indexOf("Omarchy") !== -1)
        return i
    }
    return sessionModel.lastIndex
  }

  FontLoader {
    id: argorFont
    source: "ArgFlahm.ttf"
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      password.text = ""
      password.forceActiveFocus()
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  Image {
    anchors.fill: parent
    source: "background.png"
    fillMode: Image.PreserveAspectCrop
    horizontalAlignment: Image.AlignHCenter
    verticalAlignment: Image.AlignVCenter
    asynchronous: true
    sourceSize.width: Math.min(width, 2560)
    sourceSize.height: Math.min(height, 1600)
  }

  Rectangle {
    anchors.fill: parent
    color: "#A0000000"
  }

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: "#D0000000" }
      GradientStop { position: 0.28; color: "#26000000" }
      GradientStop { position: 0.70; color: "#48000000" }
      GradientStop { position: 1.0; color: "#E6000000" }
    }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: root.compactLayout ? 10
      : Math.max(18, Math.min(root.width, root.height) * 0.025)
    color: "transparent"
    border.width: 1
    border.color: "#706B62"
    opacity: 0.72
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: root.compactLayout ? 14
      : Math.max(24, Math.min(root.width, root.height) * 0.033)
    color: "transparent"
    border.width: 1
    border.color: "#2E2C29"
  }

  Repeater {
    model: [
      { xSide: "left", ySide: "top", angle: 0 },
      { xSide: "right", ySide: "top", angle: 90 },
      { xSide: "right", ySide: "bottom", angle: 180 },
      { xSide: "left", ySide: "bottom", angle: 270 }
    ]

    Image {
      property var corner: modelData
      width: root.compactLayout ? 38 : Math.max(48, Math.min(72, root.width * 0.045))
      height: width
      source: "frame_corner.png"
      rotation: corner.angle
      opacity: 0.78
      anchors.left: corner.xSide === "left" ? parent.left : undefined
      anchors.right: corner.xSide === "right" ? parent.right : undefined
      anchors.top: corner.ySide === "top" ? parent.top : undefined
      anchors.bottom: corner.ySide === "bottom" ? parent.bottom : undefined
      anchors.margins: root.compactLayout ? 10
        : Math.max(18, Math.min(root.width, root.height) * 0.025)
    }
  }

  Column {
    anchors.top: parent.top
    anchors.topMargin: root.compactLayout ? 24 : Math.max(56, root.height * 0.075)
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 2

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Tenebris"
      color: "#D8D1C5"
      font.family: argorFont.name
      font.pixelSize: root.compactLayout ? 28
        : Math.max(34, Math.min(58, root.width * 0.035))
      font.letterSpacing: 2
      renderType: Text.NativeRendering
    }

  }

  Item {
    id: gatePanel
    width: Math.min(620, root.width - 72)
    height: root.compactLayout ? 280 : 520
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: root.compactLayout ? 15
      : Math.min(72, root.height * 0.055)

    Image {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      width: root.compactLayout ? 64 : 116
      height: root.compactLayout ? 70 : 120
      source: "large_sigil.png"
      fillMode: Image.PreserveAspectFit
      opacity: 0.23
    }

    Image {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: root.compactLayout ? 40 : 78
      width: Math.min(500, parent.width - 30)
      height: root.compactLayout ? 40 : 56
      source: "divider_ornate.png"
      fillMode: Image.PreserveAspectFit
      opacity: 0.66
    }

    Rectangle {
      id: inputField
      width: Math.min(440, parent.width - 50)
      height: root.compactLayout ? 44 : 58
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: root.compactLayout ? 92 : 144
      color: "#D9050505"
      border.width: root.loginFailed ? 2 : 1
      border.color: root.loginFailed ? "#B51D24" : (password.text.length > 0 ? "#B8B2A7" : "#66625B")

      Rectangle {
        anchors.fill: parent
        anchors.margins: 5
        color: "transparent"
        border.width: 1
        border.color: "#282624"
      }

      TextInput {
        id: password
        anchors.fill: parent
        anchors.leftMargin: 30
        anchors.rightMargin: 30
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        echoMode: TextInput.Password
        passwordCharacter: "\u2022"
        passwordMaskDelay: 0
        color: "#E1DBCF"
        selectionColor: "#7C0E13"
        selectedTextColor: "#E1DBCF"
        font.family: "Noto Serif"
        font.pixelSize: root.compactLayout ? 19 : 24
        font.letterSpacing: text.length > 0 ? 6 : 0
        focus: true

        onTextChanged: root.loginFailed = false

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (password.text.length > 0)
              sddm.login(root.currentUser, password.text, root.sessionIndex)
            event.accepted = true
          } else if (event.key === Qt.Key_Escape) {
            password.text = ""
            event.accepted = true
          }
        }
      }

      Text {
        anchors.fill: password
        visible: password.text.length === 0
        text: root.loginFailed ? "Authentication failed" : "Password"
        color: root.loginFailed ? "#B51D24" : "#8A867F"
        font.family: "Noto Serif"
        font.pixelSize: root.compactLayout ? 14 : 17
        font.italic: root.loginFailed
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: password.forceActiveFocus()
      }
    }

    SealClock {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: inputField.bottom
      anchors.topMargin: root.compactLayout ? 10 : 18
      width: root.compactLayout ? 96 : 174
      height: width + (root.compactLayout ? 30 : 42)
      hourHandSource: "clock_hour_hand.png"
      minuteHandSource: "clock_minute_hand.png"
      bodyFont: "Noto Serif"
    }
  }

  Row {
    anchors.right: parent.right
    anchors.rightMargin: root.compactLayout ? 60 : Math.max(110, root.width * 0.07)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.compactLayout ? 24 : Math.max(90, root.height * 0.09)
    spacing: root.compactLayout ? 12 : 20

    Text {
      text: "Restart"
      color: restartArea.containsMouse ? "#D5D0C6" : "#77736D"
      font.family: "Noto Serif"
      font.pixelSize: root.compactLayout ? 9 : 12
      MouseArea {
        id: restartArea
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sddm.reboot()
      }
    }

    Text {
      text: "Shut Down"
      color: shutdownArea.containsMouse ? "#B51D24" : "#77736D"
      font.family: "Noto Serif"
      font.pixelSize: root.compactLayout ? 9 : 12
      MouseArea {
        id: shutdownArea
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sddm.powerOff()
      }
    }
  }

  Component.onCompleted: password.forceActiveFocus()
}
