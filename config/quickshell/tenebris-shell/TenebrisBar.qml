import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property string clockText: Qt.formatDateTime(new Date(), "HH:mm")
    property string ipAddress: "SEALED"
    property string ramText: "0/0G"
    property int battery: 0
    property int cpuTemp: 0
    readonly property int activeWorkspace: Hyprland.focusedWorkspace !== null
        ? Hyprland.focusedWorkspace.id : 1
    readonly property var utilityButtons: [
        { asset: "utility_agents@2x.png", label: "Agents", module: "omarchy.agents" },
        { asset: "utility_bluetooth@2x.png", label: "Bluetooth", module: "omarchy.bluetooth" },
        { asset: "utility_network@2x.png", label: "Network", module: "omarchy.network" },
        { asset: "utility_audio@2x.png", label: "Audio", module: "omarchy.audio" },
        { asset: "utility_display@2x.png", label: "Display", module: "omarchy.monitor" },
        { asset: "utility_power@2x.png", label: "Power", module: "omarchy.power" }
    ]

    function run(command) {
        Quickshell.execDetached(["sh", "-lc", command]);
    }

    function focusWorkspace(workspace) {
        root.run("hyprctl dispatch 'hl.dsp.focus({ workspace = \"" + workspace + "\" })'");
    }

    function toggleUtility(moduleName) {
        root.run("omarchy-shell shell toggle " + moduleName);
    }

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 48
    exclusionMode: ExclusionMode.Auto
    aboveWindows: true
    focusable: false
    color: "transparent"
    WlrLayershell.namespace: "tenebris-bar"
    WlrLayershell.layer: WlrLayer.Top

    Process {
        id: barState
        command: ["python3", Quickshell.shellPath("tenebris-state.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim());
                    root.ipAddress = data.ip || "SEALED";
                    root.ramText = data.ramText || "0/0G";
                    root.battery = data.battery || 0;
                    root.cpuTemp = data.cpuTemp || 0;
                } catch (error) {
                    console.warn("TENEBRIS bar state parse failed:", error);
                }
            }
        }
    }

    Timer {
        interval: 2400
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!barState.running) barState.running = true
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.clockText = Qt.formatDateTime(new Date(), "HH:mm")
    }

    Rectangle {
        anchors.fill: parent
        color: "#F4050505"
        border.color: "#5E5A54"
        border.width: 1

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.top: parent.top
            anchors.topMargin: 4
            height: 1
            color: "#312F2C"
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            height: 1
            color: "#312F2C"
        }

        Image {
            anchors.left: parent.left
            anchors.top: parent.top
            width: 46
            height: 46
            source: Quickshell.shellPath("assets/frame_corner.png")
            fillMode: Image.PreserveAspectFit
            opacity: 0.72
        }

        Image {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: 46
            height: 46
            rotation: 270
            source: Quickshell.shellPath("assets/frame_corner.png")
            fillMode: Image.PreserveAspectFit
            opacity: 0.72
        }

        Image {
            anchors.right: parent.right
            anchors.top: parent.top
            width: 46
            height: 46
            rotation: 90
            source: Quickshell.shellPath("assets/frame_corner.png")
            fillMode: Image.PreserveAspectFit
            opacity: 0.72
        }

        Image {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 46
            height: 46
            rotation: 180
            source: Quickshell.shellPath("assets/frame_corner.png")
            fillMode: Image.PreserveAspectFit
            opacity: 0.72
        }

        Row {
            id: workspaceRow
            anchors.left: parent.left
            // Keep the controls clear of the carved corner cap.
            anchors.leftMargin: 54
            anchors.verticalCenter: parent.verticalCenter
            height: 36
            spacing: 2

            Item {
                width: 38
                height: 36

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    color: menuMouse.pressed
                        ? TenebrisTheme.bloodDark
                        : (menuMouse.containsMouse ? "#B31A1918" : "transparent")
                    border.color: menuMouse.containsMouse ? TenebrisTheme.border : "transparent"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: TenebrisTheme.motionFast } }
                    Behavior on border.color { ColorAnimation { duration: TenebrisTheme.motionFast } }
                }

                Image {
                    anchors.centerIn: parent
                    width: 25
                    height: 25
                    source: Quickshell.shellPath("assets/omarchy_dungeon@2x.png")
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    opacity: menuMouse.containsMouse ? 1.0 : 0.78

                    Behavior on opacity { NumberAnimation { duration: TenebrisTheme.motionFast } }
                }

                MouseArea {
                    id: menuMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton)
                            root.run("xdg-terminal-exec");
                        else
                            root.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'");
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 20
                color: TenebrisTheme.borderDim
            }

            Repeater {
                model: 10

                Rectangle {
                    id: workspaceCell
                    required property int index
                    readonly property int workspaceId: index + 1
                    width: 28
                    height: 34
                    color: root.activeWorkspace === workspaceId
                        ? TenebrisTheme.blood
                        : (workspaceMouse.containsMouse ? "#B31A1918" : "transparent")
                    border.color: root.activeWorkspace === workspaceId
                        ? TenebrisTheme.bloodBright : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: workspaceCell.workspaceId === 10 ? "0" : workspaceCell.workspaceId
                        color: root.activeWorkspace === workspaceCell.workspaceId
                            ? TenebrisTheme.bone : TenebrisTheme.silver
                        font.family: TenebrisTheme.uiFont
                        font.pixelSize: 14
                    }

                    Rectangle {
                        visible: root.activeWorkspace === workspaceCell.workspaceId
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        width: 10
                        height: 1
                        color: TenebrisTheme.bloodBright
                    }

                    MouseArea {
                        id: workspaceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focusWorkspace(workspaceCell.workspaceId)
                    }
                }
            }
        }

        Rectangle {
            anchors.left: workspaceRow.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 26
            color: TenebrisTheme.borderDim
        }

        Item {
            id: titlePlate
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 500
            height: 42

            Image {
                anchors.left: parent.left
                anchors.right: titleText.left
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                source: Quickshell.shellPath("assets/topbar_title_ornament.png")
                fillMode: Image.PreserveAspectFit
                opacity: 0.74
            }

            Image {
                anchors.right: parent.right
                anchors.left: titleText.right
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                source: Quickshell.shellPath("assets/topbar_title_ornament.png")
                fillMode: Image.PreserveAspectFit
                mirror: true
                opacity: 0.74
            }

            Text {
                id: titleText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -1
                text: "Verum Lux, In Tenebris Habitat"
                color: TenebrisTheme.bone
                font.family: TenebrisTheme.heroFont
                font.pixelSize: 18
                font.letterSpacing: 0.4
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: 6
                width: 20
                height: 31
                source: Quickshell.shellPath("assets/wax_seal_round.png")
                fillMode: Image.PreserveAspectFit
                opacity: 0.78
            }
        }

        Row {
            id: statusRow
            anchors.right: parent.right
            // The clock must end before the mirrored corner ornament begins.
            anchors.rightMargin: 54
            anchors.verticalCenter: parent.verticalCenter
            height: 36
            spacing: 2

            Repeater {
                model: root.utilityButtons

                TenebrisUtilityButton {
                    required property var modelData
                    asset: Quickshell.shellPath("assets/" + modelData.asset)
                    label: modelData.label
                    badgeText: modelData.module === "omarchy.power" && root.battery > 0
                        ? String(root.battery) : ""
                    onInvoked: function(button) { root.toggleUtility(modelData.module) }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 20
                color: TenebrisTheme.borderDim
            }

            Item { width: 5; height: 1 }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.clockText
                color: TenebrisTheme.bone
                font.family: TenebrisTheme.uiFont
                font.pixelSize: 16
                font.letterSpacing: 0.2
            }

        }
    }
}
