import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string home: Quickshell.env("HOME")
  readonly property string assetRoot: home + "/.config/quickshell/tenebris-shell/assets"
  readonly property string titleFont: "Argor Flahm Scaqh"
  readonly property string bodyFont: "Noto Serif"
  readonly property bool compactLayout: width < 760 || height < 520
  readonly property int fieldWidth: Math.min(440, Math.max(280, width - 96))
  readonly property int fieldHeight: compactLayout ? 44 : 58
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function asset(name) {
    return fileUrl(assetRoot + "/" + name)
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: if (inputEnabled) Qt.callLater(forcePasswordFocus)
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      horizontalAlignment: Image.AlignHCenter
      verticalAlignment: Image.AlignVCenter
      asynchronous: true
      cache: false
      sourceSize.width: Math.min(width, 2560)
      sourceSize.height: Math.min(height, 1600)
    }

    Rectangle {
      anchors.fill: parent
      color: "#99000000"
    }

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: "#C8000000" }
        GradientStop { position: 0.24; color: "#24000000" }
        GradientStop { position: 0.72; color: "#3A000000" }
        GradientStop { position: 1.0; color: "#E0000000" }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: {
        root.wakeRequested()
        root.forcePasswordFocus()
      }
      onPositionChanged: root.wakeRequested()
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
      opacity: 0.86
    }

    Repeater {
      model: [
        { xSide: "left", ySide: "top", angle: 0 },
        { xSide: "right", ySide: "top", angle: 90 },
        { xSide: "right", ySide: "bottom", angle: 180 },
        { xSide: "left", ySide: "bottom", angle: 270 }
      ]

      Image {
        required property var modelData
        width: root.compactLayout ? 38 : Math.max(48, Math.min(72, root.width * 0.045))
        height: width
        source: root.asset("frame_corner.png")
        rotation: modelData.angle
        opacity: 0.78
        anchors.left: modelData.xSide === "left" ? parent.left : undefined
        anchors.right: modelData.xSide === "right" ? parent.right : undefined
        anchors.top: modelData.ySide === "top" ? parent.top : undefined
        anchors.bottom: modelData.ySide === "bottom" ? parent.bottom : undefined
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
        font.family: root.titleFont
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
        source: root.asset("large_sigil.png")
        fillMode: Image.PreserveAspectFit
        opacity: 0.23
      }

      Image {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.compactLayout ? 40 : 78
        width: Math.min(500, parent.width - 30)
        height: root.compactLayout ? 40 : 56
        source: root.asset("divider_ornate.png")
        fillMode: Image.PreserveAspectFit
        opacity: 0.66
      }

      Rectangle {
        id: inputField
        width: root.fieldWidth
        height: root.fieldHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.compactLayout ? 92 : 144
        color: "#D9050505"
        border.width: root.errorState ? 2 : 1
        border.color: root.errorState ? Color.lock.textError
          : (passwordInput.text.length > 0 || root.authenticatingPassword ? "#B8B2A7" : "#66625B")

        Behavior on border.color { ColorAnimation { duration: 150 } }

        Rectangle {
          anchors.fill: parent
          anchors.margins: 5
          color: "transparent"
          border.width: 1
          border.color: "#282624"
        }

        TextInput {
          id: passwordInput
          anchors.fill: parent
          anchors.leftMargin: 30 + (root.fingerprintConfigured ? 24 : 0)
          anchors.rightMargin: 30 + (root.fingerprintConfigured ? 24 : 0)
          horizontalAlignment: TextInput.AlignHCenter
          verticalAlignment: TextInput.AlignVCenter
          activeFocusOnPress: true
          clip: true
          enabled: root.inputEnabled && !root.authenticatingPassword
          readOnly: root.authenticatingPassword
          echoMode: TextInput.Password
          passwordCharacter: "\u2022"
          passwordMaskDelay: 0
          color: "#E1DBCF"
          selectionColor: Color.lock.selection
          selectedTextColor: "#E1DBCF"
          font.family: root.bodyFont
          font.pixelSize: root.compactLayout ? 19 : 24
          font.letterSpacing: text.length > 0 ? 6 : 0
          cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
          cursorDelegate: Rectangle {
            width: 1
            color: "#E1DBCF"
            visible: passwordInput.cursorVisible
          }

          onTextChanged: {
            if (!root.syncingPasswordText) root.passwordTextEdited(text)
            if (text.length > 0) root.wakeRequested()
            if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
          }

          onAccepted: {
            var submitted = root.passwordText
            root.passwordTextEdited("")
            if (submitted.length > 0) root.submitPassword(submitted)
          }

          Keys.onPressed: function(event) {
            root.wakeRequested()
            if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
              root.passwordTextEdited("")
              event.accepted = true
            }
          }
        }

        Text {
          anchors.fill: passwordInput
          visible: passwordInput.text.length === 0
          text: root.authenticatingPassword ? "Verifying…"
            : (root.errorState ? "Authentication failed" : "Password")
          color: root.errorState ? Color.lock.textError : "#8A867F"
          font.family: root.bodyFont
          font.pixelSize: root.compactLayout ? 14 : 17
          font.italic: root.errorState
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: 18
          anchors.verticalCenter: parent.verticalCenter
          visible: root.fingerprintConfigured
          text: "󰌷"
          color: "#8A867F"
          font.family: Style.font.family
          font.pixelSize: 19
        }
      }

      SealClock {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: inputField.bottom
        anchors.topMargin: root.compactLayout ? 10 : 18
        width: root.compactLayout ? 96 : 174
        height: width + (root.compactLayout ? 30 : 42)
        hourHandSource: root.asset("clock_hour_hand.png")
        minuteHandSource: root.asset("clock_minute_hand.png")
        bodyFont: root.bodyFont
      }
    }
  }
}
