import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool overlayActive: false
    property bool terminalReady: false
    property bool geometryQueued: false

    visible: root.overlayActive
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.namespace: "tenebris-terminal-frame"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Purely visual: the terminal remains fully pointer-accessible.
    mask: Region {}

    function queueTerminalGeometry() {
        if (!root.overlayActive || !root.terminalReady)
            return;
        geometryDebounce.restart();
    }

    onOverlayActiveChanged: root.queueTerminalGeometry()
    onTerminalReadyChanged: root.queueTerminalGeometry()
    onWidthChanged: root.queueTerminalGeometry()
    onHeightChanged: root.queueTerminalGeometry()

    Timer {
        id: geometryDebounce
        interval: 80
        onTriggered: {
            if (!root.overlayActive || !root.terminalReady)
                return;
            if (geometryProcess.running) {
                root.geometryQueued = true;
                return;
            }
            geometryProcess.running = true;
        }
    }

    Process {
        id: geometryProcess
        command: ["python3", Quickshell.shellPath("place-dashboard-terminal.py")]
        onExited: {
            if (root.geometryQueued) {
                root.geometryQueued = false;
                geometryDebounce.restart();
            }
        }
    }

    Item {
        id: frame

        readonly property real railWidth: 94
        readonly property real rightColumnWidth: Math.max(250, root.width * 0.18)
        readonly property real centralWidth: root.width - 156 - rightColumnWidth

        x: 13 + railWidth + 18
        y: 48 + 48
        width: centralWidth * 0.535
        height: (root.height - 114) * 0.55

        // The native terminal begins exactly on this divider and ends six
        // pixels inside the other carved edges. place-dashboard-terminal.py
        // mirrors these values from the live output and this exact frame math.
        Rectangle {
            x: 8
            y: 35
            width: frame.width - 16
            height: 1
            color: TenebrisTheme.borderDim
            opacity: 0.72
        }

        Repeater {
            model: [
                { x: 0, y: 0, rotation: 0 },
                { x: frame.width - 42, y: 0, rotation: 90 },
                { x: frame.width - 42, y: frame.height - 42, rotation: 180 },
                { x: 0, y: frame.height - 42, rotation: 270 }
            ]

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
                opacity: 0.78
            }
        }
    }
}
