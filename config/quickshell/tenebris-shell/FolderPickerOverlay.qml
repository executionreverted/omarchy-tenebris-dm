import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false
    property string initialPath: "~/Projects"
    property string currentPath: ""
    property string currentDisplayPath: "~"
    property string parentPath: ""
    property bool canGoUp: false
    property var folders: []
    property bool loading: false

    signal closeRequested()
    signal folderSelected(string path)

    function browse(path) {
        if (browserProcess.running)
            return;
        root.loading = true;
        browserProcess.command = [
            "python3", Quickshell.shellPath("folder-browser.py"), String(path || "~")
        ];
        browserProcess.running = true;
    }

    onOpenChanged: {
        if (root.open) {
            root.browse(root.initialPath);
            Qt.callLater(function() { keyCatcher.forceActiveFocus(); });
        }
    }

    visible: root.open
    aboveWindows: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.namespace: "tenebris-folder-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: root.closeRequested()
    }

    Process {
        id: browserProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim());
                    root.currentPath = data.path || "";
                    root.currentDisplayPath = data.displayPath || "~";
                    root.parentPath = data.parent || data.path || "";
                    root.canGoUp = data.canGoUp === true;
                    root.folders = data.entries || [];
                    folderList.positionViewAtBeginning();
                } catch (error) {
                    console.warn("TENEBRIS folder browser failed:", error);
                }
                root.loading = false;
            }
        }

        onExited: root.loading = false
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.closeRequested()
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Q && event.modifiers === Qt.NoModifier) {
                root.closeRequested();
                event.accepted = true;
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#B8000000"

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    ArchiveFrame {
        id: pickerFrame
        anchors.centerIn: parent
        width: Math.min(620, parent.width - 56)
        height: Math.min(650, parent.height - 92)
        title: "CHOOSE A VAULT"
        subtitle: root.currentDisplayPath
        panelColor: "#F20A0A09"
        z: 2

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true; }
        }

        Column {
            id: pickerColumn
            anchors.fill: parent
            spacing: 9

            Row {
                id: quickNav
                width: parent.width
                height: 32
                spacing: 6

                Repeater {
                    model: [
                        { glyph: "←", label: "UP", path: root.parentPath, enabled: root.canGoUp },
                        { glyph: "⌂", label: "HOME", path: "~", enabled: true },
                        { glyph: "󰉋", label: "PROJECTS", path: "~/Projects", enabled: true }
                    ]

                    Rectangle {
                        required property var modelData
                        width: modelData.label === "PROJECTS" ? 112 : 78
                        height: 32
                        color: quickMouse.containsMouse && modelData.enabled
                            ? "#241619" : "#B20B0B0A"
                        border.color: quickMouse.containsMouse && modelData.enabled
                            ? TenebrisTheme.bloodBright : TenebrisTheme.borderDim
                        opacity: modelData.enabled ? 1 : 0.35

                        Row {
                            id: quickContent
                            anchors.centerIn: parent
                            height: parent.height
                            spacing: 7

                            Item {
                                width: quickGlyph.implicitWidth
                                height: parent.height

                                Text {
                                    id: quickGlyph
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -1
                                    text: modelData.glyph
                                    color: TenebrisTheme.silver
                                    font.family: TenebrisTheme.monoFont
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                id: quickLabel
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.label
                                color: TenebrisTheme.text
                                font.family: TenebrisTheme.contentFont
                                font.pixelSize: TenebrisTheme.typeCaption
                                font.letterSpacing: 0.8
                            }
                        }

                        MouseArea {
                            id: quickMouse
                            anchors.fill: parent
                            enabled: modelData.enabled
                            hoverEnabled: true
                            cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.browse(modelData.path)
                        }
                    }
                }
            }

            Rectangle {
                id: pathBar
                width: parent.width
                height: 34
                color: "#A00B0B0A"
                border.color: TenebrisTheme.borderDim

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentDisplayPath
                    color: TenebrisTheme.bone
                    font.family: TenebrisTheme.contentFont
                    font.pixelSize: TenebrisTheme.typeMeta
                    elide: Text.ElideMiddle
                }
            }

            Item {
                id: folderArea
                width: parent.width
                height: Math.max(0, pickerColumn.height
                    - quickNav.height - pathBar.height - footerRow.height
                    - pickerColumn.spacing * 3 - 8)

                Text {
                    visible: !root.loading && root.folders.length === 0
                    anchors.centerIn: parent
                    text: "NO SUBFOLDERS\nTHIS VAULT CAN STILL BE USED"
                    color: TenebrisTheme.textMuted
                    font.family: TenebrisTheme.contentFont
                    font.pixelSize: TenebrisTheme.typeMeta
                    font.letterSpacing: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.5
                }

                Text {
                    visible: root.loading
                    anchors.centerIn: parent
                    text: "READING THE ARCHIVE…"
                    color: TenebrisTheme.silver
                    font.family: TenebrisTheme.contentFont
                    font.pixelSize: TenebrisTheme.typeMeta
                    font.letterSpacing: 1
                }

                ListView {
                    id: folderList
                    visible: !root.loading
                    anchors.fill: parent
                    anchors.rightMargin: 8
                    model: root.folders
                    spacing: 4
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: true

                    delegate: Rectangle {
                        id: folderRow
                        required property var modelData
                        width: ListView.view.width
                        height: 43
                        color: folderMouse.containsMouse ? "#251619" : "#8A0B0B0A"
                        border.color: folderMouse.containsMouse
                            ? TenebrisTheme.bloodBright : TenebrisTheme.borderDim

                        Rectangle {
                            visible: folderMouse.containsMouse
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 2
                            color: TenebrisTheme.bloodBright
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -1
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: "󰉋"
                            color: folderMouse.containsMouse
                                ? TenebrisTheme.bone : TenebrisTheme.silver
                            font.family: TenebrisTheme.monoFont
                            font.pixelSize: 15
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 42
                            anchors.right: arrow.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.name
                            color: folderMouse.containsMouse
                                ? TenebrisTheme.bone : TenebrisTheme.text
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeBody
                            elide: Text.ElideRight
                        }

                        Text {
                            id: arrow
                            anchors.right: parent.right
                            anchors.rightMargin: 13
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -1
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: "›"
                            color: TenebrisTheme.textMuted
                            font.family: TenebrisTheme.uiFont
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: folderMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.browse(modelData.path)
                        }
                    }
                }

                Rectangle {
                    visible: folderList.contentHeight > folderList.height
                    anchors.right: parent.right
                    width: 2
                    height: Math.max(26, parent.height * folderList.visibleArea.heightRatio)
                    y: Math.max(0, Math.min(
                        parent.height - height,
                        parent.height * folderList.visibleArea.yPosition
                    ))
                    color: TenebrisTheme.bloodBright
                    opacity: 0.72
                }
            }

            Row {
                id: footerRow
                anchors.right: parent.right
                height: 34
                spacing: 7

                Repeater {
                    model: [
                        { label: "CANCEL", accept: false },
                        { label: "USE THIS FOLDER", accept: true }
                    ]

                    Rectangle {
                        required property var modelData
                        width: modelData.accept ? 148 : 82
                        height: 32
                        color: modelData.accept
                            ? (footerMouse.containsMouse ? TenebrisTheme.bloodBright : TenebrisTheme.blood)
                            : (footerMouse.containsMouse ? "#211718" : "#A00B0B0A")
                        border.color: modelData.accept
                            ? TenebrisTheme.bloodBright : TenebrisTheme.borderDim

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: modelData.accept ? TenebrisTheme.bone : TenebrisTheme.text
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeCaption
                            font.bold: modelData.accept
                            font.letterSpacing: 0.8
                        }

                        MouseArea {
                            id: footerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.accept)
                                    root.folderSelected(root.currentDisplayPath);
                                else
                                    root.closeRequested();
                            }
                        }
                    }
                }
            }
        }
    }
}
