import QtQuick

Item {
  id: root

  property real webDensity: 0.95
  property real windStrength: 1.75
  property real motionAmount: 2.0
  property int renderFps: 30
  property real renderScale: 0.75
  property int weaveSeconds: 30
  property url fragmentShaderSource: ""
  property url spiderSpriteSource: ""

  property bool overlayVisible: false
  property bool weaving: false
  property bool scattering: false
  property real buildProgress: 0
  property real fractureProgress: 0
  property real effectOpacity: 1
  property real elapsedTime: 0
  property real weavePhase: 0
  property real scatterElapsed: 0
  property real activationSeed: 1
  property real centerOffsetX: 0
  property real centerOffsetY: 0
  property int generatedSpokeCount: 15
  property int generatedRingCount: 29
  property real generatedWindAngle: 0
  property int generatedStartSector: 0
  property real generatedBaseDirection: 1

  signal interactionRequested()
  signal dismissed()

  function fract(value) {
    return value - Math.floor(value)
  }

  function clampUnit(value) {
    return Math.max(0, Math.min(1, value))
  }

  function smoothUnit(value) {
    const unit = clampUnit(value)
    return unit * unit * (3 - 2 * unit)
  }

  readonly property real webAspect: Math.max(0.01, width / Math.max(1, height))
  readonly property real webCenterX: centerOffsetX * webAspect
  readonly property real webCoverage: Math.sqrt(
    Math.pow(webAspect * 0.5 + Math.abs(webCenterX), 2)
      + Math.pow(0.5 + Math.abs(centerOffsetY), 2)
  ) * 1.012
  readonly property real ringStep: 0.875 / generatedRingCount
  readonly property real firstRingBirth: 0.055 + ringStep
  readonly property real ringCycle: Math.max(0, buildProgress - 0.055) / ringStep
  readonly property int activeRingIndex: Math.max(1, Math.min(
    generatedRingCount, Math.floor(ringCycle)
  ))
  readonly property real activeRingPhase: buildProgress < firstRingBirth
    ? 0 : clampUnit(ringCycle - activeRingIndex)
  readonly property real activeRingRadius: activeRingIndex / generatedRingCount
  readonly property real nextRingRadius: Math.min(
    generatedRingCount, activeRingIndex + 1
  ) / generatedRingCount
  readonly property real activeRingStroke: clampUnit(activeRingPhase / 0.78)
  readonly property real ringTransfer: clampUnit((activeRingPhase - 0.78) / 0.22)
  readonly property real activeDirection: generatedBaseDirection
    * (activeRingIndex % 2 === 0 ? -1 : 1)
  readonly property real spiderTurnOut: smoothUnit((activeRingPhase - 0.72) / 0.10)
  readonly property real spiderTurnIn: smoothUnit((activeRingPhase - 0.92) / 0.08)
  readonly property real spiderHeadingOffset: activeDirection * 90
    * (1 - spiderTurnOut) - activeDirection * 90 * spiderTurnIn
  readonly property real spiderSectorTravel: generatedStartSector
    + activeDirection * activeRingStroke * generatedSpokeCount
  readonly property real spiderAngle: spiderSectorTravel
    / generatedSpokeCount * Math.PI * 2 - Math.PI
  readonly property real spiderSectorPhase: fract(
    (spiderAngle + Math.PI) / (Math.PI * 2) * generatedSpokeCount
  ) * Math.PI
  readonly property real spiderSagBase: Math.max(0, Math.sin(spiderSectorPhase))
  readonly property real spiderSagShape: spiderSagBase * Math.sqrt(spiderSagBase)
  readonly property real spiderWindScale: Math.max(0, Math.min(2, windStrength / 1.5))
  readonly property real spiderMotionScale: Math.max(0, Math.min(2, motionAmount / 1.5))
  readonly property real spiderFlex: spiderWindScale * (0.52 + spiderMotionScale * 0.48)
  readonly property real spiderLivingSag: Math.sin(
    elapsedTime * 0.72 + activeRingRadius * 9.3
      + spiderSectorTravel * 1.17 + activationSeed * 0.009
  ) * spiderFlex * activeRingRadius * 0.0065
  readonly property real spiderRingRadius: activeRingRadius
    + (nextRingRadius - activeRingRadius) * ringTransfer
  readonly property real spiderRadius: buildProgress < firstRingBirth
    ? Math.max(0.021, buildProgress / firstRingBirth / generatedRingCount)
    : Math.max(0.021, spiderRingRadius
      - (0.005 + activeRingRadius * 0.017 + spiderLivingSag)
        * spiderSagShape * (1 - ringTransfer))
  readonly property real spiderBaseX: webCenterX
    + Math.cos(spiderAngle) * webCoverage * spiderRadius
  readonly property real spiderBaseY: centerOffsetY
    + Math.sin(spiderAngle) * webCoverage * spiderRadius
  readonly property real spiderWindX: Math.cos(generatedWindAngle)
  readonly property real spiderWindY: Math.sin(generatedWindAngle)
  readonly property real spiderNormalX: -spiderWindY
  readonly property real spiderNormalY: spiderWindX
  readonly property real spiderGust: Math.sin(elapsedTime * 0.43 + activationSeed * 0.031) * 0.67
    + Math.sin(elapsedTime * 0.91 + activationSeed * 0.019) * 0.23
    + Math.sin(elapsedTime * 1.57 + activationSeed * 0.007) * 0.10
  readonly property real spiderElasticBase: clampUnit((spiderRadius - 0.035) / 0.965)
  readonly property real spiderElasticity: spiderElasticBase * Math.sqrt(spiderElasticBase)
  readonly property real spiderCrossSection: spiderBaseX * spiderNormalX
    + spiderBaseY * spiderNormalY
  readonly property real spiderPrimaryShift: spiderGust * spiderFlex
    * spiderElasticity * (0.052 + spiderCrossSection * 0.034)
  readonly property real spiderCrossShift: Math.sin(
    elapsedTime * 0.56 + spiderRadius * 7.1
      + spiderCrossSection * 3.4 + activationSeed * 0.011
  ) * spiderMotionScale * spiderWindScale * spiderElasticity * 0.021
  readonly property real spiderPulseShift: Math.sin(
    elapsedTime * 0.34 + spiderRadius * 10.3 - spiderCrossSection * 2.2
  ) * spiderMotionScale * spiderWindScale
    * spiderElasticity * spiderRadius * 0.010
  readonly property real spiderScreenX: spiderBaseX
    + spiderWindX * (spiderPrimaryShift - spiderPulseShift)
    - spiderNormalX * spiderCrossShift
  readonly property real spiderScreenY: spiderBaseY
    + spiderWindY * (spiderPrimaryShift - spiderPulseShift)
    - spiderNormalY * spiderCrossShift
  readonly property real blackoutProgress: smoothUnit((buildProgress - 0.88) / 0.12)

  function beginWeb() {
    activationSeed = Math.random() * 8192 + (Date.now() % 100003) * 0.013
    centerOffsetX = (Math.random() * 2 - 1) * 0.055
    centerOffsetY = (Math.random() * 2 - 1) * 0.022
    generatedSpokeCount = 14 + Math.floor(Math.random() * 4)
    generatedRingCount = 27 + Math.floor(Math.random() * 5)
    generatedWindAngle = -0.44 + Math.random() * 0.88
    generatedStartSector = Math.floor(Math.random() * generatedSpokeCount)
    generatedBaseDirection = Math.random() > 0.5 ? 1 : -1
    overlayVisible = true
    weaving = true
    scattering = false
    buildProgress = 0.008
    fractureProgress = 0
    effectOpacity = 1
    weavePhase = 0
    scatterElapsed = 0
    elapsedTime = Math.random() * 37
    activityCatcher.originReady = false
    Qt.callLater(forceActiveFocus)
  }

  function scatterWeb() {
    if (!overlayVisible || scattering) return
    interactionRequested()
    weaving = false
    scattering = true
    scatterElapsed = 0
  }

  function resetWeb() {
    overlayVisible = false
    weaving = false
    scattering = false
    buildProgress = 0
    fractureProgress = 0
    effectOpacity = 1
    weavePhase = 0
    scatterElapsed = 0
  }

  function finishScatter() {
    resetWeb()
    dismissed()
  }

  visible: overlayVisible
  focus: overlayVisible

  Keys.onPressed: function(event) {
    if (!overlayVisible) return
    scatterWeb()
    event.accepted = true
  }

  Timer {
    interval: Math.max(16, Math.round(1000 / Math.max(1, root.renderFps)))
    repeat: true
    running: root.overlayVisible && (root.weaving || root.scattering
      || (root.buildProgress < 1
        && root.windStrength > 0 && root.motionAmount > 0))
    onTriggered: {
      const delta = interval / 1000
      root.elapsedTime += delta

      if (root.weaving) {
        root.weavePhase = Math.min(1,
          root.weavePhase + delta / Math.max(1, root.weaveSeconds))
        root.buildProgress = root.weavePhase
        if (root.weavePhase >= 1) root.weaving = false
      }

      if (root.scattering) {
        root.scatterElapsed += delta
        root.fractureProgress = root.smoothUnit(root.scatterElapsed / 1.65)
        if (root.scatterElapsed > 0.43)
          root.effectOpacity = 1 - root.smoothUnit((root.scatterElapsed - 0.43) / 1.43)
        if (root.scatterElapsed >= 1.86) root.finishScatter()
      }
    }
  }

  Item {
    id: webRenderSource
    anchors.fill: parent

    ShaderEffect {
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
      fragmentShader: root.fragmentShaderSource
    }
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: root.blackoutProgress * root.effectOpacity
  }

  ShaderEffectSource {
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
    visible: root.overlayVisible && root.weaving && !root.scattering
      && root.buildProgress > 0.012
    running: visible
    source: root.spiderSpriteSource
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
    rotation: root.spiderAngle * 180 / Math.PI + root.spiderHeadingOffset
    transformOrigin: Item.Center
    opacity: 0.86 * root.effectOpacity
  }

  MouseArea {
    id: activityCatcher
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.AllButtons
    cursorShape: root.scattering ? Qt.ArrowCursor : Qt.BlankCursor
    property real originX: 0
    property real originY: 0
    property bool originReady: false

    onEntered: {
      originX = mouseX
      originY = mouseY
      originReady = true
    }

    onPositionChanged: function(mouse) {
      if (!originReady) {
        originX = mouse.x
        originY = mouse.y
        originReady = true
        return
      }
      const deltaX = mouse.x - originX
      const deltaY = mouse.y - originY
      if (deltaX * deltaX + deltaY * deltaY >= 18 * 18) root.scatterWeb()
    }

    onPressed: root.scatterWeb()
    onWheel: root.scatterWeb()
  }
}
