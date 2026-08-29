pragma Singleton
import QtQuick

QtObject {
    // Nearly monochrome archive palette. Blood is intentionally semantic.
    readonly property color voidColor: "#050505"
    readonly property color background: "#090909"
    // Let the parchment wallpaper breathe through the ironwork. Raised elements
    // remain denser so small labels stay readable over detailed backgrounds.
    readonly property color surface: "#D4101010"
    readonly property color surfaceRaised: "#E0181818"
    readonly property color borderDim: "#34322F"
    readonly property color border: "#66625B"
    readonly property color silver: "#B8B2A7"
    readonly property color bone: "#E1DBCF"
    readonly property color text: "#D5D0C6"
    readonly property color textMuted: "#8A867F"
    readonly property color blood: "#7C0E13"
    readonly property color bloodBright: "#B51D24"
    readonly property color bloodDark: "#2F0508"
    readonly property color rust: "#7B3329"
    readonly property color shadow: "#B8000000"

    // The display face is optional and is not redistributed. Qt falls back to
    // the bundled Omarchy/Noto families when it is unavailable.
    readonly property string heroFont: "Argor Flahm Scaqh"
    readonly property string panelFont: "Noto Serif Display"
    readonly property string uiFont: "Noto Serif"
    readonly property string displayFont: panelFont
    readonly property string serifFont: uiFont
    readonly property string monoFont: "JetBrainsMono Nerd Font"
    readonly property string monoFallback: "DejaVu Sans Mono"

    // Dashboard content uses one technical face and a compact, repeatable
    // scale. Display/panel titles intentionally keep their separate faces.
    readonly property string contentFont: monoFont
    readonly property int typeMicro: 7
    readonly property int typeCaption: 8
    readonly property int typeMeta: 9
    readonly property int typeBody: 10
    readonly property int typeLead: 14

    readonly property int borderWidth: 1
    readonly property int radiusSmall: 2
    readonly property int radiusPanel: 2
    readonly property int spacingXs: 4
    readonly property int spacingSm: 6
    readonly property int spacingMd: 10
    readonly property int spacingLg: 16

    readonly property int motionFast: 140
    readonly property int motionNormal: 190
    readonly property int motionSlow: 420
}
