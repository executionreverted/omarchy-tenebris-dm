import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false
    property bool webEnabled: true
    property real webDensity: 0.95
    property real windStrength: 1.75
    property real motionAmount: 2.0
    property int renderFps: 30
    property real renderScale: 0.75
    property int idleSeconds: 90
    property int weaveSeconds: 30
    property bool stayAwake: false
    property bool stayAwakeKnown: false
    property bool stayAwakePending: false

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

    function refreshStayAwake() {
        if (!idleStatusProcess.running && !idleToggleProcess.running)
            idleStatusProcess.running = true;
    }

    function setStayAwake(value) {
        if (!root.stayAwakeKnown || root.stayAwakePending
                || idleToggleProcess.running)
            return;

        root.stayAwakePending = true;
        idleToggleProcess.requestedState = value;
        idleToggleProcess.running = true;
    }

    visible: root.open
    aboveWindows: true
    focusable: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 286
    implicitHeight: 451

    onOpenChanged: {
        if (open)
            Qt.callLater(refreshStayAwake);
    }

    Component.onCompleted: refreshStayAwake()

    anchors {
        top: true
        left: true
    }

    margins {
        top: 100
        left: 126
    }

    WlrLayershell.namespace: "tenebris-web-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: root.closeRequested()
    }

    WebSettingsMenu {
        anchors.fill: parent
        webEnabled: root.webEnabled
        webDensity: root.webDensity
        windStrength: root.windStrength
        motionAmount: root.motionAmount
        renderFps: root.renderFps
        renderScale: root.renderScale
        idleSeconds: root.idleSeconds
        weaveSeconds: root.weaveSeconds
        stayAwake: root.stayAwake
        stayAwakeKnown: root.stayAwakeKnown
        stayAwakePending: root.stayAwakePending
        onCloseRequested: root.closeRequested()
        onEnabledRequested: value => root.enabledRequested(value)
        onDensityRequested: value => root.densityRequested(value)
        onWindRequested: value => root.windRequested(value)
        onMotionRequested: value => root.motionRequested(value)
        onFpsRequested: value => root.fpsRequested(value)
        onRenderScaleRequested: value => root.renderScaleRequested(value)
        onIdleRequested: value => root.idleRequested(value)
        onWeaveRequested: value => root.weaveRequested(value)
        onStayAwakeRequested: value => root.setStayAwake(value)
        onPreviewRequested: root.previewRequested()
    }

    Process {
        id: idleStatusProcess
        command: ["omarchy-shell", "idle", "status"]
        stdout: StdioCollector {
            id: idleStatusOutput
            waitForEnd: true
        }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    const status = JSON.parse(String(idleStatusOutput.text || "{}"));
                    root.stayAwake = status.stayAwake === true;
                    root.stayAwakeKnown = true;
                } catch (error) {
                    root.stayAwakeKnown = false;
                    console.warn("TENEBRIS idle status parse failed:", error);
                }
            } else {
                root.stayAwakeKnown = false;
            }
            root.stayAwakePending = false;
        }
    }

    Process {
        id: idleToggleProcess
        property bool requestedState: false
        command: [
            "omarchy-shell", "idle",
            requestedState ? "disable" : "enable"
        ]
        onExited: idleStatusProcess.running = true
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.open
        onTriggered: root.refreshStayAwake()
    }
}
