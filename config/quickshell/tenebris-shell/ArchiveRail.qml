import QtQuick
import Quickshell

Rectangle {
    id: root

    property bool cleanMode: false
    property bool webScreensaverEnabled: true
    signal commandRequested(string command)
    signal webMenuRequested()

    onWebScreensaverEnabledChanged: webCanvas.requestPaint()

    implicitWidth: root.cleanMode ? 72 : 94
    color: TenebrisTheme.surface
    border.color: TenebrisTheme.borderDim
    border.width: 1
    radius: 0
    clip: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: 5
        color: "transparent"
        border.color: "#34322F"
        border.width: 1
    }

    Repeater {
        model: root.cleanMode ? [] : [
            { x: 0, y: 0, rotation: 0 },
            { x: root.width - 32, y: 0, rotation: 90 },
            { x: root.width - 32, y: root.height - 32, rotation: 180 },
            { x: 0, y: root.height - 32, rotation: 270 }
        ]

        Image {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: 32
            height: 32
            rotation: modelData.rotation
            transformOrigin: Item.Center
            source: Quickshell.shellPath("assets/frame_corner.png")
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: 0.64
        }
    }

    Item {
        id: webToggle
        visible: !root.cleanMode
        anchors.top: parent.top
        anchors.topMargin: 7
        anchors.horizontalCenter: parent.horizontalCenter
        width: 70
        height: 68

        Canvas {
            id: webCanvas
            anchors.fill: parent
            opacity: webToggleHover.hovered
                ? 0.82 : (root.webScreensaverEnabled ? 0.18 : 0.06)
            antialiasing: true

            onPaint: {
                const context = getContext("2d");
                context.clearRect(0, 0, width, height);
                context.strokeStyle = root.webScreensaverEnabled
                    ? "#AAA7A0" : "#61383A";
                context.lineWidth = 0.55;

                const nodes = [
                    [1, 5], [15, 1], [34, 8], [54, 2], [69, 13],
                    [7, 27], [25, 21], [45, 27], [65, 34],
                    [2, 50], [19, 61], [38, 53], [59, 65], [69, 52]
                ];
                const links = [
                    [0, 1], [1, 2], [2, 3], [3, 4], [0, 5], [1, 6],
                    [2, 6], [2, 7], [3, 7], [4, 8], [5, 6], [6, 7],
                    [7, 8], [5, 9], [6, 10], [6, 11], [7, 11], [8, 13],
                    [9, 10], [10, 11], [11, 12], [12, 13]
                ];

                for (let index = 0; index < links.length; index++) {
                    const start = nodes[links[index][0]];
                    const end = nodes[links[index][1]];
                    const bend = ((index * 17) % 7 - 3) * 0.48;
                    const middleX = (start[0] + end[0]) * 0.5 + bend;
                    const middleY = (start[1] + end[1]) * 0.5 + 1.2 + bend * 0.25;
                    context.beginPath();
                    context.moveTo(start[0], start[1]);
                    context.quadraticCurveTo(middleX, middleY, end[0], end[1]);
                    context.stroke();
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: TenebrisTheme.motionNormal }
            }
        }

        Image {
            anchors.centerIn: parent
            width: 58
            height: 60
            source: Quickshell.shellPath("assets/large_sigil.png")
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: webToggleHover.hovered ? 0.94 : 0.72

            Behavior on opacity {
                NumberAnimation { duration: TenebrisTheme.motionFast }
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            width: 5
            height: 5
            rotation: 45
            color: root.webScreensaverEnabled
                ? TenebrisTheme.silver : TenebrisTheme.bloodDark
            border.color: root.webScreensaverEnabled
                ? TenebrisTheme.border : TenebrisTheme.blood
            border.width: 1
        }

        HoverHandler {
            id: webToggleHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.webMenuRequested()
        }
    }

    OrnamentDivider {
        visible: !root.cleanMode
        anchors.top: parent.top
        anchors.topMargin: 76
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 20
        height: 12
        textured: true
    }

    Column {
        visible: !root.cleanMode
        anchors.top: parent.top
        anchors.topMargin: 91
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1

        Repeater {
            model: [
                { asset: "rail_icon_terminal.png", label: "Terminal", command: "omarchy launch terminal", active: true },
                { asset: "rail_icon_archive.png", label: "Files", command: "omarchy launch nautilus", active: false },
                { asset: "rail_icon_quill.png", label: "Editor", command: "omarchy launch editor '$HOME/Projects'", active: false },
                { asset: "rail_icon_sigil.png", label: "Browser", command: "omarchy launch browser", active: false },
                { asset: "rail_icon_image.png", label: "Images", command: "uwsm app -- nautilus --new-window \"$(xdg-user-dir PICTURES)\"", active: false },
                { asset: "rail_icon_rune.png", label: "Rune", command: "omarchy launch tui btop", active: false },
                { asset: "rail_icon_settings.png", label: "Settings", command: "omarchy menu toggle", active: false }
            ]

            RasterIconButton {
                required property var modelData
                width: 78
                height: 66
                asset: Quickshell.shellPath("assets/" + modelData.asset)
                label: modelData.label
                active: modelData.active
                onInvoked: root.commandRequested(modelData.command)
            }
        }
    }

    Column {
        visible: root.cleanMode
        anchors.top: parent.top
        anchors.topMargin: 48
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 3

        ArchiveButton { glyph: ""; label: "Terminal"; onInvoked: root.commandRequested("omarchy launch terminal") }
        ArchiveButton { glyph: "󰉋"; label: "Archive"; onInvoked: root.commandRequested("omarchy launch nautilus") }
        ArchiveButton { glyph: "󰨞"; label: "Editor"; onInvoked: root.commandRequested("omarchy launch editor '$HOME/Projects'") }
        ArchiveButton { glyph: "󰖟"; label: "Network"; onInvoked: root.commandRequested("omarchy launch browser") }
        ArchiveButton { glyph: "󰄫"; label: "Vitals"; onInvoked: root.commandRequested("omarchy launch tui btop") }
        ArchiveButton { glyph: "󰒓"; label: "Config"; onInvoked: root.commandRequested("omarchy menu toggle") }
    }

    Image {
        visible: !root.cleanMode
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 94
        anchors.horizontalCenter: parent.horizontalCenter
        width: 28
        height: 45
        source: Quickshell.shellPath("assets/small_cross.png")
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: 0.42
    }

    Image {
        id: archiveSeal
        visible: !root.cleanMode
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: 62
        height: 70
        source: Quickshell.shellPath("assets/wax_seal_hex_complete.png")
        // The source sheet also contains three construction swatches beneath
        // the seal. Display only the finished seal instead of scaling the
        // entire sheet into the dock button.
        sourceClipRect: Qt.rect(17, 0, 92, 100)
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: 0.68

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: archiveSeal.opacity = 0.95
            onExited: archiveSeal.opacity = 0.68
            onClicked: root.commandRequested("omarchy menu toggle")
        }
    }
}
