import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool webEnabled: true
    property real webDensity: 0.95
    property real windStrength: 1.75
    property real motionAmount: 2.0
    property int renderFps: 30
    property real renderScale: 0.75
    property int idleSeconds: 90
    property int weaveSeconds: 30

    property bool overlayVisible: false
    property real buildProgress: 0
    property real fractureProgress: 0
    property real effectOpacity: 1
    property real elapsedTime: 0
    property real activationSeed: 1
    property bool acceptingInput: false
    property bool weaving: false
    property bool scattering: false
    property real weavePhase: 0
    property real scatterElapsed: 0
    property real centerOffsetX: 0
    property real centerOffsetY: 0
    property int generatedSpokeCount: 15
    property int generatedRingCount: 29
    property real generatedWindAngle: 0
    property int generatedStartSector: 0
    property real generatedBaseDirection: 1

    function fract(value) {
        return value - Math.floor(value);
    }

    function clampUnit(value) {
        return Math.max(0, Math.min(1, value));
    }

    readonly property real webAspect: Math.max(0.01, width / Math.max(1, height))
    readonly property real webCenterX: root.centerOffsetX * root.webAspect
    readonly property real webCoverage: Math.sqrt(
        Math.pow(root.webAspect * 0.5 + Math.abs(root.webCenterX), 2)
        + Math.pow(0.5 + Math.abs(root.centerOffsetY), 2)
    ) * 1.012
    readonly property real ringStep: 0.875 / root.generatedRingCount
    readonly property real firstRingBirth: 0.055 + root.ringStep
    readonly property real ringCycle: Math.max(0, root.buildProgress - 0.055) / root.ringStep
    readonly property int activeRingIndex: Math.max(1, Math.min(
        root.generatedRingCount,
        Math.floor(root.ringCycle)
    ))
    readonly property real activeRingPhase: root.buildProgress < root.firstRingBirth
        ? 0 : root.clampUnit(root.ringCycle - root.activeRingIndex)
    readonly property real activeRingRadius: root.activeRingIndex / root.generatedRingCount
    readonly property real nextRingRadius: Math.min(
        root.generatedRingCount,
        root.activeRingIndex + 1
    ) / root.generatedRingCount
    readonly property real activeRingStroke: root.clampUnit(root.activeRingPhase / 0.78)
    readonly property real ringTransfer: root.clampUnit((root.activeRingPhase - 0.78) / 0.22)
    readonly property real activeDirection: root.generatedBaseDirection
        * (root.activeRingIndex % 2 === 0 ? -1 : 1)
    readonly property real spiderTurnOut: root.smoothUnit(
        (root.activeRingPhase - 0.72) / 0.10
    )
    readonly property real spiderTurnIn: root.smoothUnit(
        (root.activeRingPhase - 0.92) / 0.08
    )
    readonly property real spiderHeadingOffset: root.activeDirection * 90
        * (1 - root.spiderTurnOut) - root.activeDirection * 90 * root.spiderTurnIn
    readonly property real spiderSectorTravel: root.generatedStartSector
        + root.activeDirection * root.activeRingStroke * root.generatedSpokeCount
    readonly property real spiderAngle: root.spiderSectorTravel
        / root.generatedSpokeCount * Math.PI * 2 - Math.PI
    readonly property real spiderSectorPhase: root.fract(
        (root.spiderAngle + Math.PI) / (Math.PI * 2) * root.generatedSpokeCount
    ) * Math.PI
    readonly property real spiderSagBase: Math.max(0, Math.sin(root.spiderSectorPhase))
    readonly property real spiderSagShape: root.spiderSagBase * Math.sqrt(root.spiderSagBase)
    readonly property real spiderWindScale: Math.max(0, Math.min(2, root.windStrength / 1.5))
    readonly property real spiderMotionScale: Math.max(0, Math.min(2, root.motionAmount / 1.5))
    readonly property real spiderFlex: root.spiderWindScale * (0.52 + root.spiderMotionScale * 0.48)
    readonly property real spiderLivingSag: Math.sin(
        root.elapsedTime * 0.72 + root.activeRingRadius * 9.3
            + root.spiderSectorTravel * 1.17 + root.activationSeed * 0.009
    ) * root.spiderFlex * root.activeRingRadius * 0.0065
    readonly property real spiderRingRadius: root.activeRingRadius
        + (root.nextRingRadius - root.activeRingRadius) * root.ringTransfer
    readonly property real spiderRadius: root.buildProgress < root.firstRingBirth
        ? Math.max(0.021, root.buildProgress / root.firstRingBirth / root.generatedRingCount)
        : Math.max(0.021, root.spiderRingRadius
            - (0.005 + root.activeRingRadius * 0.017 + root.spiderLivingSag)
                * root.spiderSagShape * (1 - root.ringTransfer))
    readonly property real spiderBaseX: root.webCenterX
        + Math.cos(root.spiderAngle) * root.webCoverage * root.spiderRadius
    readonly property real spiderBaseY: root.centerOffsetY
        + Math.sin(root.spiderAngle) * root.webCoverage * root.spiderRadius
    readonly property real spiderWindX: Math.cos(root.generatedWindAngle)
    readonly property real spiderWindY: Math.sin(root.generatedWindAngle)
    readonly property real spiderNormalX: -root.spiderWindY
    readonly property real spiderNormalY: root.spiderWindX
    readonly property real spiderGust: Math.sin(root.elapsedTime * 0.43 + root.activationSeed * 0.031) * 0.67
        + Math.sin(root.elapsedTime * 0.91 + root.activationSeed * 0.019) * 0.23
        + Math.sin(root.elapsedTime * 1.57 + root.activationSeed * 0.007) * 0.10
    readonly property real spiderElasticBase: root.clampUnit((root.spiderRadius - 0.035) / 0.965)
    readonly property real spiderElasticity: root.spiderElasticBase * Math.sqrt(root.spiderElasticBase)
    readonly property real spiderCrossSection: root.spiderBaseX * root.spiderNormalX
        + root.spiderBaseY * root.spiderNormalY
    readonly property real spiderPrimaryShift: root.spiderGust * root.spiderFlex
        * root.spiderElasticity * (0.052 + root.spiderCrossSection * 0.034)
    readonly property real spiderCrossShift: Math.sin(
        root.elapsedTime * 0.56 + root.spiderRadius * 7.1
            + root.spiderCrossSection * 3.4 + root.activationSeed * 0.011
    ) * root.spiderMotionScale * root.spiderWindScale * root.spiderElasticity * 0.021
    readonly property real spiderPulseShift: Math.sin(
        root.elapsedTime * 0.34 + root.spiderRadius * 10.3 - root.spiderCrossSection * 2.2
    ) * root.spiderMotionScale * root.spiderWindScale
        * root.spiderElasticity * root.spiderRadius * 0.010
    readonly property real spiderScreenX: root.spiderBaseX
        + root.spiderWindX * (root.spiderPrimaryShift - root.spiderPulseShift)
        - root.spiderNormalX * root.spiderCrossShift
    readonly property real spiderScreenY: root.spiderBaseY
        + root.spiderWindY * (root.spiderPrimaryShift - root.spiderPulseShift)
        - root.spiderNormalY * root.spiderCrossShift
    readonly property real blackoutProgress: root.smoothUnit(
        (root.buildProgress - 0.88) / 0.12
    )

    function beginWeb(forcePreview) {
        if (!root.webEnabled && !forcePreview)
            return;

        root.activationSeed = Math.random() * 8192 + (Date.now() % 100003) * 0.013;
        root.centerOffsetX = (Math.random() * 2 - 1) * 0.055;
        root.centerOffsetY = (Math.random() * 2 - 1) * 0.022;
        root.generatedSpokeCount = 14 + Math.floor(Math.random() * 4);
        root.generatedRingCount = 27 + Math.floor(Math.random() * 5);
        root.generatedWindAngle = -0.44 + Math.random() * 0.88;
        root.generatedStartSector = Math.floor(Math.random() * root.generatedSpokeCount);
        root.generatedBaseDirection = Math.random() > 0.5 ? 1 : -1;
        root.overlayVisible = true;
        root.buildProgress = 0.008;
        root.fractureProgress = 0;
        root.effectOpacity = 1;
        root.acceptingInput = true;
        root.weaving = true;
        root.scattering = false;
        root.weavePhase = 0;
        root.scatterElapsed = 0;
        activityCatcher.originReady = false;
        root.elapsedTime = Math.random() * 37;
    }

    function scatterWeb() {
        if (!root.overlayVisible || root.scattering)
            return;

        root.weaving = false;
        root.scattering = true;
        root.scatterElapsed = 0;
        root.acceptingInput = false;
    }

    function smoothUnit(value) {
        const unit = Math.max(0, Math.min(1, value));
        return unit * unit * (3 - 2 * unit);
    }

    function finishScatter() {
        root.overlayVisible = false;
        root.weaving = false;
        root.scattering = false;
        root.buildProgress = 0;
        root.fractureProgress = 0;
        root.effectOpacity = 1;
        root.scatterElapsed = 0;
    }

    onWebEnabledChanged: {
        if (!root.webEnabled)
            root.scatterWeb();
        else if (idleMonitor.isIdle)
            root.beginWeb(false);
    }

    visible: root.overlayVisible
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    mask: Region { item: inputCatcher }

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.namespace: "tenebris-spiderweb"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    IdleMonitor {
        id: idleMonitor
        enabled: root.webEnabled
        timeout: Math.max(5, root.idleSeconds)
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                root.beginWeb(false);
            else
                root.scatterWeb();
        }
    }

    Timer {
        interval: Math.max(16, Math.round(1000 / Math.max(1, root.renderFps)))
        repeat: true
        running: root.overlayVisible && (root.weaving || root.scattering
            || (root.windStrength > 0 && root.motionAmount > 0))
        onTriggered: {
            const delta = interval / 1000;
            root.elapsedTime += delta;

            if (root.weaving) {
                root.weavePhase = Math.min(1, root.weavePhase + delta / Math.max(1, root.weaveSeconds));
                root.buildProgress = root.weavePhase;
                if (root.weavePhase >= 1)
                    root.weaving = false;
            }

            if (root.scattering) {
                root.scatterElapsed += delta;
                root.fractureProgress = root.smoothUnit(root.scatterElapsed / 1.65);
                if (root.scatterElapsed > 0.43)
                    root.effectOpacity = 1 - root.smoothUnit((root.scatterElapsed - 0.43) / 1.43);
                if (root.scatterElapsed >= 1.86)
                    root.finishScatter();
            }
        }
    }

    IpcHandler {
        target: "tenebris.web"

        function preview(): string {
            root.beginWeb(true);
            return "visible";
        }

        function scatter(): string {
            root.scatterWeb();
            return "scattering";
        }

        function reseed(): string {
            root.beginWeb(true);
            return String(root.activationSeed);
        }
    }

    Item {
        id: inputCatcher
        anchors.fill: parent
        visible: root.acceptingInput

        MouseArea {
            id: activityCatcher
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            property real originX: 0
            property real originY: 0
            property bool originReady: false

            onEntered: {
                originX = mouseX;
                originY = mouseY;
                originReady = true;
            }

            onPositionChanged: function(mouse) {
                if (!originReady) {
                    originX = mouse.x;
                    originY = mouse.y;
                    originReady = true;
                    return;
                }
                const deltaX = mouse.x - originX;
                const deltaY = mouse.y - originY;
                if (deltaX * deltaX + deltaY * deltaY >= 18 * 18)
                    root.scatterWeb();
            }

            onPressed: root.scatterWeb()
            onWheel: root.scatterWeb()
        }
    }

    Item {
        id: webRenderSource
        anchors.fill: parent

        ShaderEffect {
            id: webShader
            anchors.fill: parent
            blending: true

            property real webTime: root.elapsedTime
            property real build: root.buildProgress
            property real fracture: root.fractureProgress
            property size resolution: Qt.size(Math.max(1, width), Math.max(1, height))
            property real webSeed: root.activationSeed
            property real densityControl: root.webDensity
            property real windControl: root.windStrength
            property real motionControl: root.motionAmount
            property point webCenter: Qt.point(root.centerOffsetX, root.centerOffsetY)
            property real spokeControl: root.generatedSpokeCount
            property real ringControl: root.generatedRingCount
            property real windAngleControl: root.generatedWindAngle
            property real startSectorControl: root.generatedStartSector
            property real directionControl: root.generatedBaseDirection

            fragmentShader: Qt.resolvedUrl("shaders/spiderweb.frag.qsb")

            onStatusChanged: {
                if (status === ShaderEffect.Error)
                    console.warn("TENEBRIS spider-web shader failed:", log);
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.blackoutProgress * root.effectOpacity
    }

    ShaderEffectSource {
        id: webUpscale
        anchors.fill: parent
        sourceItem: webRenderSource
        hideSource: true
        live: root.overlayVisible
        smooth: true
        mipmap: false
        format: ShaderEffectSource.RGBA8
        textureSize: Qt.size(
            Math.max(1, Math.round(width * root.renderScale)),
            Math.max(1, Math.round(height * root.renderScale))
        )
        opacity: root.effectOpacity
    }

    AnimatedSprite {
        id: weavingSpider
        visible: root.overlayVisible && root.weaving && !root.scattering
            && root.buildProgress > 0.012
        running: visible
        source: Qt.resolvedUrl("assets/spider_walk_sheet.png")
        frameCount: 12
        frameWidth: 181
        frameHeight: 181
        frameRate: 6
        loops: AnimatedSprite.Infinite
        interpolate: false
        width: 46
        height: 46
        x: root.width * (0.5 + root.spiderScreenX / root.webAspect) - width / 2
        y: root.height * (0.5 + root.spiderScreenY) - height / 2
        // Turn from the current ring tangent into the radial connector, then
        // turn naturally onto the next ring's reversed tangent.
        rotation: root.spiderAngle * 180 / Math.PI + root.spiderHeadingOffset
        transformOrigin: Item.Center
        opacity: 0.86 * root.effectOpacity
    }
}
