import QtQuick
import QtQuick.Controls as Controls
import Quickshell

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property color accent: TenebrisTheme.border
    property color panelColor: TenebrisTheme.surface
    property bool quiet: false
    property bool textured: true
    property bool showCorners: true
    property int headerHeight: 38
    // Noto Serif Display's uppercase side bearings read a few pixels left of
    // their geometric box. Keep every archive heading on the optical axis.
    property real titleOpticalOffset: 4
    property string headerIcon: ""
    property string headerIconTooltip: ""
    property bool headerIconActive: false
    property bool headerIconBare: false
    property string headerSecondaryIcon: ""
    property string headerSecondaryIconTooltip: ""
    property bool headerSecondaryIconActive: false
    property bool headerSecondaryIconBare: false
    property bool showSubtitleWithButtons: false
    property bool subtitleInteractive: false
    signal headerIconClicked()
    signal headerSecondaryIconClicked()
    signal subtitleClicked()
    default property alias content: contentArea.data

    color: root.panelColor
    border.color: root.quiet ? TenebrisTheme.borderDim : root.accent
    border.width: 1
    radius: 0
    clip: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: 5
        color: "transparent"
        border.color: "#3A3834"
        border.width: 1
    }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.topMargin: root.headerHeight - 3
        height: 1
        color: TenebrisTheme.borderDim
    }

    Image {
        visible: root.textured
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.topMargin: root.headerHeight - 10
        height: 13
        source: Quickshell.shellPath("assets/divider_framed.png")
        fillMode: Image.Stretch
        smooth: true
        opacity: 0.30
    }

    Item {
        id: titleBar
        readonly property real titleReserve: rightControls.visible
            ? rightControls.width + 18 : 0
        anchors.left: parent.left
        anchors.leftMargin: root.textured ? 42 : 18
        anchors.right: parent.right
        anchors.rightMargin: root.textured ? 42 : 18
        anchors.top: parent.top
        height: root.headerHeight - 3
        clip: true
        z: 3

        Row {
            id: rightControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: 7
            visible: subtitleText.visible || headerButtons.visible

            Text {
                id: subtitleText
                visible: root.subtitle.length > 0 && root.width >= 420
                    && (!headerButtons.visible || root.showSubtitleWithButtons)
                width: Math.min(118, implicitWidth)
                anchors.verticalCenter: parent.verticalCenter
                text: root.subtitle
                color: subtitleMouse.containsMouse
                    ? TenebrisTheme.bone : TenebrisTheme.textMuted
                font.family: TenebrisTheme.contentFont
                font.pixelSize: TenebrisTheme.typeCaption
                font.letterSpacing: 0.7
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideMiddle

                MouseArea {
                    id: subtitleMouse
                    anchors.fill: parent
                    enabled: root.subtitleInteractive
                    hoverEnabled: root.subtitleInteractive
                    cursorShape: root.subtitleInteractive
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.subtitleClicked()
                }
            }

            Row {
                id: headerButtons
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                visible: root.headerIcon.length > 0 || root.headerSecondaryIcon.length > 0

                Rectangle {
                    id: headerButton
                    width: 28
                    height: 19
                    visible: root.headerIcon.length > 0
                    color: root.headerIconBare ? "transparent"
                        : (root.headerIconActive || headerButtonMouse.containsMouse
                            ? TenebrisTheme.bloodDark : "#76090909")
                    border.color: root.headerIconBare ? "transparent"
                        : (root.headerIconActive
                            ? TenebrisTheme.bloodBright
                            : (headerButtonMouse.containsMouse ? TenebrisTheme.border : TenebrisTheme.borderDim))
                    border.width: root.headerIconBare ? 0 : 1

                    Text {
                        anchors.centerIn: parent
                        text: root.headerIcon
                        color: root.headerIconActive || headerButtonMouse.containsMouse
                            ? TenebrisTheme.bone
                            : TenebrisTheme.silver
                        font.family: TenebrisTheme.monoFont
                        font.pixelSize: root.headerIconBare ? 14 : 11
                    }

                    MouseArea {
                        id: headerButtonMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.headerIconClicked()
                    }

                    Controls.ToolTip {
                        visible: root.headerIconTooltip.length > 0
                            && headerButtonMouse.containsMouse
                        text: root.headerIconTooltip
                        delay: 320
                        timeout: 5000
                        padding: 0

                        background: Rectangle {
                            color: "#F2050505"
                            border.color: TenebrisTheme.border
                            border.width: 1
                            radius: 0
                        }

                        contentItem: Text {
                            text: root.headerIconTooltip
                            color: TenebrisTheme.bone
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeMeta
                            font.letterSpacing: 0.35
                            leftPadding: 9
                            rightPadding: 9
                            topPadding: 6
                            bottomPadding: 6
                        }
                    }

                    Behavior on color { ColorAnimation { duration: TenebrisTheme.motionFast } }
                }

                Rectangle {
                    id: headerSecondaryButton
                    width: 28
                    height: 19
                    visible: root.headerSecondaryIcon.length > 0
                    color: root.headerSecondaryIconBare ? "transparent"
                        : (root.headerSecondaryIconActive || headerSecondaryButtonMouse.containsMouse
                            ? TenebrisTheme.bloodDark : "#76090909")
                    border.color: root.headerSecondaryIconBare ? "transparent"
                        : (root.headerSecondaryIconActive
                            ? TenebrisTheme.bloodBright
                            : (headerSecondaryButtonMouse.containsMouse ? TenebrisTheme.border : TenebrisTheme.borderDim))
                    border.width: root.headerSecondaryIconBare ? 0 : 1

                    Text {
                        anchors.centerIn: parent
                        text: root.headerSecondaryIcon
                        color: root.headerSecondaryIconActive || headerSecondaryButtonMouse.containsMouse
                            ? TenebrisTheme.bone
                            : TenebrisTheme.silver
                        font.family: TenebrisTheme.monoFont
                        font.pixelSize: root.headerSecondaryIconBare ? 14 : 11
                    }

                    MouseArea {
                        id: headerSecondaryButtonMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.headerSecondaryIconClicked()
                    }

                    Controls.ToolTip {
                        visible: root.headerSecondaryIconTooltip.length > 0
                            && headerSecondaryButtonMouse.containsMouse
                        text: root.headerSecondaryIconTooltip
                        delay: 320
                        timeout: 5000
                        padding: 0

                        background: Rectangle {
                            color: "#F2050505"
                            border.color: TenebrisTheme.border
                            border.width: 1
                            radius: 0
                        }

                        contentItem: Text {
                            text: root.headerSecondaryIconTooltip
                            color: TenebrisTheme.bone
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeMeta
                            font.letterSpacing: 0.35
                            leftPadding: 9
                            rightPadding: 9
                            topPadding: 6
                            bottomPadding: 6
                        }
                    }

                    Behavior on color { ColorAnimation { duration: TenebrisTheme.motionFast } }
                }
            }
        }

        Text {
            width: Math.max(0, parent.width - titleBar.titleReserve * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: root.titleOpticalOffset
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: root.quiet ? TenebrisTheme.textMuted : TenebrisTheme.silver
            font.family: TenebrisTheme.panelFont
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.1
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    Repeater {
        model: root.textured && root.showCorners ? [
            { x: 0, y: 0, rotation: 0 },
            { x: root.width - 42, y: 0, rotation: 90 },
            { x: root.width - 42, y: root.height - 42, rotation: 180 },
            { x: 0, y: root.height - 42, rotation: 270 }
        ] : []

        Image {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: 42
            height: 42
            rotation: modelData.rotation
            transformOrigin: Item.Center
            source: Quickshell.shellPath("assets/frame_corner.png")
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: 0.72
            z: 5
        }
    }

    Item {
        id: contentArea
        anchors.left: parent.left
        anchors.leftMargin: 13
        anchors.right: parent.right
        anchors.rightMargin: 13
        anchors.top: parent.top
        anchors.topMargin: root.headerHeight + 5
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 13
        clip: true
        z: 4
    }
}
