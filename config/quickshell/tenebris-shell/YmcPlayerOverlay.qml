import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false
    property string playerTitle: "THE ARCHIVE RESTS"
    property string playerArtist: "NO CANTICLE"
    property string playerAlbum: ""
    property string playerStatus: "SILENT"
    property real playerPosition: 0
    property real playerLength: 0
    property string playerRepeat: "off"
    property var queue: []
    property int queuePosition: 0
    property string searchText: ""
    property string notice: ""

    signal closeRequested()

    function artistFor(track) {
        const artists = track && track.artists instanceof Array ? track.artists : [];
        const names = [];
        for (let i = 0; i < artists.length; ++i) {
            if (artists[i] && artists[i].name)
                names.push(String(artists[i].name));
        }
        return names.length > 0 ? names.join(", ") : "Unknown pilgrim";
    }

    function refreshQueue() {
        queueFile.reload();
    }

    function searchAndPlay() {
        const query = String(root.searchText || "").trim();
        if (query.length === 0)
            return;
        root.notice = "CONSULTING THE ARCHIVE…";
        Quickshell.execDetached([
            "python3", Quickshell.shellPath("ymc-bridge.py"), "search-play", query
        ]);
        searchRefresh.restart();
    }

    function playIndex(index) {
        Quickshell.execDetached([
            "python3", Quickshell.shellPath("ymc-bridge.py"), "play-index", String(index)
        ]);
        root.queuePosition = index;
        root.notice = "CANTICLE BOUND TO THE PLAYER";
        searchRefresh.restart();
    }

    function control(action) {
        Quickshell.execDetached([
            "python3", Quickshell.shellPath("music-player.py"), "control", action
        ]);
    }

    visible: root.open
    anchors { top: true; right: true; bottom: true; left: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "tenebris-ymc-player"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onOpenChanged: {
        if (root.open) {
            root.refreshQueue();
            root.notice = "ONE ENGINE · ONE ARCHIVE · ONE QUEUE";
            Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
        }
    }

    FileView {
        id: queueFile
        path: Quickshell.env("HOME") + "/.cache/tenebris/ymc-state.json"
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                const state = JSON.parse(text());
                root.queue = state.queue instanceof Array ? state.queue : [];
                root.queuePosition = Math.max(0, Number(state.queuePosition || 0));
            } catch (error) {
                root.queue = [];
                root.queuePosition = 0;
            }
        }
        onFileChanged: reload()
    }

    Timer {
        id: searchRefresh
        interval: 900
        repeat: false
        onTriggered: {
            root.refreshQueue();
            root.notice = "ARCHIVE SYNCHRONIZED";
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#D9060606"

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeRequested()
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Q && event.modifiers === Qt.NoModifier) {
                root.closeRequested()
                event.accepted = true
            }
        }

        ArchiveFrame {
            id: playerFrame
            anchors.centerIn: parent
            width: Math.min(parent.width - 120, 1088)
            height: Math.min(parent.height - 100, 740)
            title: "YMC GRIMOIRE"
            panelColor: "#EF080807"
            textured: true

            MouseArea { anchors.fill: parent; onClicked: {} }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                width: 24
                height: 20
                color: closeMouse.containsMouse ? TenebrisTheme.bloodDark : "#66090909"
                border.color: closeMouse.containsMouse ? TenebrisTheme.bloodBright : TenebrisTheme.borderDim

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: TenebrisTheme.bone
                    font.family: TenebrisTheme.uiFont
                    font.pixelSize: 15
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 18

                ColumnLayout {
                    Layout.preferredWidth: 330
                    Layout.fillHeight: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 0.58
                        color: "#B8070707"
                        border.color: TenebrisTheme.borderDim
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            source: root.queue.length > 0
                                ? "https://i.ytimg.com/vi/" + String(root.queue[root.queuePosition].videoId || "") + "/hqdefault.jpg"
                                : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 0.72 : 0
                        }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0; color: "#15000000" }
                                GradientStop { position: 1; color: "#E5080808" }
                            }
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 118
                            height: 118
                            source: Quickshell.shellPath("assets/large_sigil.png")
                            fillMode: Image.PreserveAspectFit
                            opacity: 0.68
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.playerTitle
                        color: TenebrisTheme.bone
                        font.family: TenebrisTheme.uiFont
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.playerArtist
                        color: TenebrisTheme.silver
                        font.family: TenebrisTheme.monoFont
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.playerAlbum.length > 0 ? root.playerAlbum : "UNBOUND RECORD"
                        color: TenebrisTheme.textMuted
                        font.family: TenebrisTheme.serifFont
                        font.pixelSize: 10
                        font.italic: true
                        elide: Text.ElideRight
                    }

                    OrnamentDivider { Layout.fillWidth: true; Layout.preferredHeight: 18 }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10

                        Repeater {
                            model: [
                                { glyph: "󰒮", action: "previous" },
                                { glyph: root.playerStatus === "PLAYING" ? "󰏤" : "󰐊", action: "play-pause" },
                                { glyph: "󰒭", action: "next" },
                                { glyph: root.playerRepeat === "one" ? "󰑘" : "󰑖", action: "repeat" }
                            ]

                            Rectangle {
                                required property var modelData
                                width: modelData.action === "play-pause" ? 46 : 36
                                height: 32
                                color: transportMouse.containsMouse ? TenebrisTheme.bloodDark : "#770A0A09"
                                border.color: modelData.action === "repeat" && root.playerRepeat !== "off"
                                    ? TenebrisTheme.bloodBright
                                    : (transportMouse.containsMouse ? TenebrisTheme.bloodBright : TenebrisTheme.borderDim)

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.glyph
                                    color: parent.modelData.action === "repeat" && root.playerRepeat !== "off"
                                        ? TenebrisTheme.bloodBright : TenebrisTheme.bone
                                    font.family: TenebrisTheme.monoFont
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: transportMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.control(parent.modelData.action)
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.fillWidth: true
                        text: root.notice
                        color: TenebrisTheme.textMuted
                        font.family: TenebrisTheme.monoFont
                        font.pixelSize: 8
                        font.letterSpacing: 0.7
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: TenebrisTheme.borderDim
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Text {
                        text: "SEEK THE ARCHIVE"
                        color: TenebrisTheme.silver
                        font.family: TenebrisTheme.uiFont
                        font.pixelSize: 14
                        font.letterSpacing: 1.1
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        color: "#B5070707"
                        border.color: searchInput.activeFocus ? TenebrisTheme.bloodBright : TenebrisTheme.borderDim

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 42
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.searchText
                            color: TenebrisTheme.bone
                            selectionColor: TenebrisTheme.bloodDark
                            selectedTextColor: TenebrisTheme.bone
                            font.family: TenebrisTheme.monoFont
                            font.pixelSize: 11
                            clip: true
                            onTextEdited: root.searchText = text
                            Keys.onReturnPressed: root.searchAndPlay()
                            Keys.onEnterPressed: root.searchAndPlay()
                            Keys.onEscapePressed: root.closeRequested()
                        }

                        Text {
                            visible: searchInput.text.length === 0
                            anchors.left: searchInput.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "artist, album or forgotten canticle…"
                            color: TenebrisTheme.textMuted
                            font.family: TenebrisTheme.monoFont
                            font.pixelSize: 10
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍉"
                            color: searchMouse.containsMouse ? TenebrisTheme.bloodBright : TenebrisTheme.silver
                            font.family: TenebrisTheme.monoFont
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: searchMouse
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 40
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.searchAndPlay()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "BOUND QUEUE"
                            color: TenebrisTheme.silver
                            font.family: TenebrisTheme.uiFont
                            font.pixelSize: 12
                            font.letterSpacing: 0.9
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.queue.length + " CANTICLES"
                            color: TenebrisTheme.textMuted
                            font.family: TenebrisTheme.monoFont
                            font.pixelSize: 8
                        }
                    }

                    ListView {
                        id: queueView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 5
                        model: root.queue

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: queueView.width
                            height: 48
                            color: index === root.queuePosition
                                ? "#A1260A0D"
                                : (queueMouse.containsMouse ? "#A1131110" : "#86090908")
                            border.color: index === root.queuePosition
                                ? TenebrisTheme.bloodBright
                                : (queueMouse.containsMouse ? TenebrisTheme.border : TenebrisTheme.borderDim)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 2
                                visible: parent.index === root.queuePosition
                                color: TenebrisTheme.bloodBright
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                text: String(parent.index + 1).padStart(2, "0")
                                color: TenebrisTheme.textMuted
                                font.family: TenebrisTheme.monoFont
                                font.pixelSize: 9
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 44
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: modelData.title || "Untitled canticle"
                                    color: TenebrisTheme.bone
                                    font.family: TenebrisTheme.uiFont
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: root.artistFor(modelData)
                                    color: TenebrisTheme.textMuted
                                    font.family: TenebrisTheme.monoFont
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: queueMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.playIndex(parent.index)
                            }
                        }

                        Text {
                            visible: root.queue.length === 0
                            anchors.centerIn: parent
                            text: "THE QUEUE AWAITS ITS FIRST CANTICLE"
                            color: TenebrisTheme.textMuted
                            font.family: TenebrisTheme.monoFont
                            font.pixelSize: 9
                            font.letterSpacing: 0.8
                        }
                    }
                }
            }
        }
    }
}
