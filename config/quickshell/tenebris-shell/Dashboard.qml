import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: root

    signal musicPlayerRequested(string provider)
    signal musicPlayerDismissRequested()
    signal webPreviewRequested()

    property int dashboardWorkspace: 1
    property bool cleanMode: false
    property bool webScreensaverEnabled: true
    property bool webSettingsOpen: false
    property real webDensity: 0.95
    property real webWindStrength: 1.75
    property real webMotionAmount: 2.0
    property int webFps: 30
    property real webRenderScale: 0.75
    property int webIdleSeconds: 90
    property int webWeaveSeconds: 30
    // A 720p output leaves 606 logical pixels below the exclusive top bar.
    // Compress the fixed telemetry stack there instead of clipping the clock.
    readonly property bool compactHeight: root.height < 800
    property var settingsDocument: ({})
    property string clockText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "dddd, dd MMMM yyyy")

    property real cpuUsage: 0
    property int cpuTemp: 0
    property real ramUsage: 0
    property string ramText: "0/0G"
    property real diskUsage: 0
    property string diskText: "0/0G"
    property string netDown: "0 B/s"
    property string netUp: "0 B/s"
    property string ipAddress: "SEALED"
    property string networkName: "NO ACTIVE LINK"
    property string networkKind: "DISCONNECTED"
    property string networkInterface: ""
    property string networkSignal: "--"
    property string networkBand: ""
    property int battery: 0
    property string batteryStatus: "AC"
    property string uptime: "0h 0m"
    property string hostName: "TENEBRIS"
    property var projects: []
    property string projectsRevision: ""
    property string projectRoot: "~/Projects"
    property string projectSort: "modified-desc"
    property bool projectPickerOpen: false
    property bool projectSortOpen: false
    property var workspaces: []
    property bool stateLoaded: false
    property bool terminalPresent: false
    property bool terminalLaunchPending: false
    property string terminalWorkspace: ""
    property bool dashboardOccupied: false
    property bool terminalMovePending: false
    property bool terminalStowHold: false
    property bool terminalProbeQueued: false

    property string playerStatus: "SILENT"
    property string playerArtist: "NO CANTICLE"
    property string playerTitle: "THE ARCHIVE RESTS"
    property string playerAlbum: ""
    property string playerSource: ""
    property string playerId: ""
    property string playerArt: ""
    property string playerUrl: ""
    property string playerVideoId: ""
    property real playerPosition: 0
    property real playerLength: 0
    property string playerRepeat: "off"
    property string musicProvider: ""
    property bool ymcAvailable: false
    property bool cliampAvailable: false
    property bool ymcVisible: false
    property bool cliampVisible: false
    property real audioBand0: 0
    property real audioBand1: 0
    property real audioBand2: 0
    property real audioBand3: 0
    property real audioBand4: 0
    property real audioBand5: 0
    property real audioBand6: 0
    property real audioBand7: 0
    property real audioBand8: 0
    property real audioBand9: 0
    property real audioBand10: 0
    property real audioBand11: 0
    property real audioBand12: 0
    property real audioBand13: 0
    property real audioBand14: 0
    property real audioBand15: 0
    property real audioEnergy: 0
    property real audioPeak: 0
    readonly property bool liveVisualizerEnabled: true

    readonly property var workspaceRooms: [
        { name: "TABLE", asset: "workspace_table.png" },
        { name: "WORK", asset: "workspace_work.png" },
        { name: "TAVERN", asset: "workspace_tavern.png" },
        { name: "FORGE", asset: "workspace_forge.png" },
        { name: "VAULT", asset: "workspace_vault.png" },
        { name: "CHAPEL", asset: "workspace_chapel.png" },
        { name: "CRYPT", asset: "workspace_crypt.png" },
        { name: "ARMORY", asset: "workspace_armory.png" },
        { name: "ARCHIVE", asset: "workspace_archive.png" },
        { name: "GATE", asset: "workspace_gate.png" }
    ]

    readonly property var workbenchActions: [
        { asset: "workbench_terminal.png", label: "Open in terminal", action: "terminal" },
        { asset: "workbench_vscode.png", label: "Open in VS Code", action: "vscode" },
        { asset: "workbench_codex.png", label: "Open with Codex", action: "codex", iconOffsetX: -1, iconOffsetY: 2 },
        { asset: "workbench_files.png", label: "Open in Files", action: "files" },
        { asset: "workbench_github.png", label: "Open on GitHub", action: "github" }
    ]

    readonly property var workbenchSortOptions: [
        { label: "NAME  A–Z", value: "name-asc" },
        { label: "NAME  Z–A", value: "name-desc" },
        { label: "MODIFIED  NEWEST", value: "modified-desc" },
        { label: "MODIFIED  OLDEST", value: "modified-asc" }
    ]

    readonly property bool archiveVisible: Hyprland.focusedWorkspace !== null
        && Hyprland.focusedWorkspace.id === root.dashboardWorkspace
    // The visual registration frame belongs to the dashboard, not to the
    // asynchronous Hyprland client model. Keeping it independent of the
    // terminal probe prevents a one-frame disappearance while a terminal is
    // opened, moved back from its stow workspace, or resized with an output.
    readonly property bool terminalFrameVisible: root.archiveVisible
        && !root.dashboardOccupied
        && !root.terminalStowHold

    function launch(command) {
        Quickshell.execDetached(["sh", "-lc", command]);
    }

    function launchRailCommand(command) {
        if (!root.terminalPresent
                || root.terminalWorkspace !== String(root.dashboardWorkspace)) {
            root.launch(command);
            return;
        }

        // Move the registered terminal before starting the requested app. This
        // closes the short compositor race where a transparent TUI could reveal
        // the dashboard terminal beneath it while the client model caught up.
        root.terminalStowHold = true;
        root.terminalMovePending = true;
        root.terminalWorkspace = "special:tenebris-stowed";
        Quickshell.execDetached([
            "sh", "-lc",
            "hyprctl dispatch 'hl.dsp.window.move({ workspace = \"special:tenebris-stowed\", follow = false, window = \"class:tenebris-terminal\" })' >/dev/null; exec " + command
        ]);
        terminalMoveGuard.restart();
        terminalStowGuard.restart();
    }

    function projectAction(action, path) {
        if (root.terminalPresent
                && root.terminalWorkspace === String(root.dashboardWorkspace)) {
            root.terminalStowHold = true;
            root.terminalMovePending = true;
            root.terminalWorkspace = "special:tenebris-stowed";
            Quickshell.execDetached([
                "hyprctl", "dispatch",
                "hl.dsp.window.move({ workspace = \"special:tenebris-stowed\", follow = false, window = \"class:tenebris-terminal\" })"
            ]);
            terminalMoveGuard.restart();
            terminalStowGuard.restart();
        }
        Quickshell.execDetached([
            "python3", Quickshell.shellPath("project-action.py"),
            action, path, root.projectRoot
        ]);
    }

    function mediaControl(action) {
        Quickshell.execDetached([
            "python3", Quickshell.shellPath("music-player.py"), "control", action
        ]);
    }

    function musicMetadata(kind, value) {
        const metadata = String(value || "").trim();
        if (metadata.length === 0)
            return;
        Quickshell.execDetached([
            "python3", Quickshell.shellPath("music-player.py"), "metadata",
            kind, metadata, root.playerUrl, root.playerArtist, root.playerAlbum,
            String(root.playerLength)
        ]);
    }

    function toggleMusicPlayer(provider) {
        if (String(provider || "").length === 0)
            return;
        root.musicPlayerRequested(provider);
    }

    function seekMedia(ratio) {
        if (root.playerId.length === 0 || root.playerLength <= 0)
            return;
        const bounded = Math.max(0, Math.min(1, Number(ratio)));
        const target = bounded * root.playerLength;
        root.playerPosition = target;
        Quickshell.execDetached([
            "python3", Quickshell.shellPath("music-player.py"), "seek", String(target)
        ]);
    }

    function setSpectrumBand(index, value) {
        switch (index) {
        case 0: root.audioBand0 = value; break;
        case 1: root.audioBand1 = value; break;
        case 2: root.audioBand2 = value; break;
        case 3: root.audioBand3 = value; break;
        case 4: root.audioBand4 = value; break;
        case 5: root.audioBand5 = value; break;
        case 6: root.audioBand6 = value; break;
        case 7: root.audioBand7 = value; break;
        case 8: root.audioBand8 = value; break;
        case 9: root.audioBand9 = value; break;
        case 10: root.audioBand10 = value; break;
        case 11: root.audioBand11 = value; break;
        case 12: root.audioBand12 = value; break;
        case 13: root.audioBand13 = value; break;
        case 14: root.audioBand14 = value; break;
        case 15: root.audioBand15 = value; break;
        }
    }

    function updateSpectrum(line) {
        const spectrum = String(line || "").trim();
        let cursor = 0;
        let count = 0;
        let sum = 0;
        let peak = 0;
        while (cursor < spectrum.length && count < 16) {
            let delimiter = spectrum.indexOf(";", cursor);
            if (delimiter < 0)
                delimiter = spectrum.length;
            const rawValue = Math.max(0, Math.min(1,
                Number(spectrum.substring(cursor, delimiter)) / 1000));
            // Lift quiet dungeon-synth passages without flattening loud peaks.
            const value = Math.min(1, Math.pow(rawValue, 0.58) * 1.12);
            if (isFinite(value)) {
                root.setSpectrumBand(count, value);
                sum += value;
                peak = Math.max(peak, value);
                count += 1;
            }
            cursor = delimiter + 1;
        }
        if (count < 8)
            return;
        const average = sum / count;
        root.audioEnergy = root.audioEnergy * 0.56 + average * 0.44;
        root.audioPeak = Math.max(peak, root.audioPeak * 0.82);
    }

    function ensureTerminal() {
        if (root.terminalPresent || root.terminalLaunchPending)
            return;
        root.terminalLaunchPending = true;
        root.terminalPresent = true;
        Quickshell.execDetached([
            "bash", Quickshell.shellPath("launch-dashboard-terminal.sh")
        ]);
        terminalLaunchGuard.restart();
    }

    function syncTerminalPlacement() {
        if (!root.terminalPresent || root.terminalMovePending)
            return;

        if (root.terminalStowHold) {
            if (root.dashboardOccupied)
                root.terminalStowHold = false;
            else if (root.terminalWorkspace === String(root.dashboardWorkspace)) {
                root.terminalMovePending = true;
                Quickshell.execDetached([
                    "hyprctl", "dispatch",
                    "hl.dsp.window.move({ workspace = \"special:tenebris-stowed\", follow = false, window = \"class:tenebris-terminal\" })"
                ]);
                terminalMoveGuard.restart();
                return;
            } else {
                return;
            }
        }

        let destination = "";
        if (root.dashboardOccupied && root.terminalWorkspace === String(root.dashboardWorkspace))
            destination = "special:tenebris-stowed";
        else if (!root.dashboardOccupied && root.terminalWorkspace === "special:tenebris-stowed")
            destination = String(root.dashboardWorkspace);

        if (destination.length === 0)
            return;

        root.terminalMovePending = true;
        // Hyprland's toplevel/client models omit the parked special-workspace
        // client on some transitions. Keep our intended destination locally so
        // the terminal can always be restored when the dashboard is empty.
        root.terminalWorkspace = destination;
        root.terminalPresent = true;
        Quickshell.execDetached([
            "hyprctl", "dispatch",
            "hl.dsp.window.move({ workspace = \"" + destination
                + "\", follow = false, window = \"class:tenebris-terminal\" })"
        ]);
        terminalMoveGuard.restart();
    }

    function refreshLiveToplevels() {
        const values = Hyprland.toplevels.values || [];
        let terminalFound = false;
        let liveTerminalWorkspace = "";
        let occupied = false;

        for (const toplevel of values) {
            const ipc = toplevel.lastIpcObject || {};
            const appClass = String(ipc.class || ipc.initialClass || "");
            const workspaceName = toplevel.workspace !== null
                ? String(toplevel.workspace.name)
                : String((ipc.workspace || {}).name || "");

            if (appClass === "tenebris-terminal") {
                terminalFound = true;
                liveTerminalWorkspace = workspaceName;
            } else if (workspaceName === String(root.dashboardWorkspace)) {
                occupied = true;
            }
        }

        // Avoid treating an early, not-yet-populated model as an empty desktop.
        if (values.length > 0 || root.stateLoaded) {
            const intentionallyStowed = root.terminalPresent
                && root.terminalWorkspace === "special:tenebris-stowed";
            if (terminalFound)
                root.terminalLaunchPending = false;
            if (terminalFound || (!root.terminalLaunchPending && !intentionallyStowed))
                root.terminalPresent = terminalFound;
            if (terminalFound || !intentionallyStowed)
                root.terminalWorkspace = liveTerminalWorkspace;
            root.dashboardOccupied = occupied;
            root.syncTerminalPlacement();
        }
    }

    function refreshTerminalStateFromClients(clients) {
        let terminalFound = false;
        let liveTerminalWorkspace = "";
        let occupied = false;

        for (const client of clients) {
            const appClass = String(client.class || client.initialClass || "");
            const workspaceName = String((client.workspace || {}).name || "");

            if (appClass === "tenebris-terminal") {
                terminalFound = true;
                liveTerminalWorkspace = workspaceName;
            } else if (workspaceName === String(root.dashboardWorkspace)) {
                occupied = true;
            }
        }

        const intentionallyStowed = root.terminalPresent
            && root.terminalWorkspace === "special:tenebris-stowed";
        if (terminalFound)
            root.terminalLaunchPending = false;
        if (terminalFound || (!root.terminalLaunchPending && !intentionallyStowed))
            root.terminalPresent = terminalFound;
        if (terminalFound || !intentionallyStowed)
            root.terminalWorkspace = liveTerminalWorkspace;
        root.dashboardOccupied = occupied;
        root.syncTerminalPlacement();
    }

    function requestTerminalProbe() {
        root.terminalProbeQueued = true;
        terminalEventProbe.restart();
    }

    function eventParts(event, count) {
        try {
            if (event && event.parse)
                return event.parse(count);
        } catch (error) {
        }
        return String(event && event.data ? event.data : "").split(",");
    }

    function handleHyprlandEvent(event) {
        const name = String(event && event.name ? event.name : "");
        if (name === "openwindow") {
            const parts = root.eventParts(event, 4);
            const workspaceName = String(parts[1] || "");
            const appClass = String(parts[2] || "");
            if (workspaceName === String(root.dashboardWorkspace)
                    && appClass !== "tenebris-terminal") {
                // Floating clients are always above tiled clients in Hyprland.
                // Remove the registered terminal on the compositor's map event
                // instead of trying to fight that ordering with visual z values.
                root.dashboardOccupied = true;
                root.webSettingsOpen = false;
                root.syncTerminalPlacement();
            }
        }

        if (name === "openwindow" || name === "closewindow"
                || name === "movewindow" || name === "workspace")
            root.requestTerminalProbe();
    }

    function focusWorkspace(workspace) {
        root.launch("hyprctl dispatch 'hl.dsp.focus({ workspace = \"" + workspace + "\" })'");
    }

    function workspaceRoom(workspace) {
        const index = Math.max(1, Math.min(10, Number(workspace))) - 1;
        return root.workspaceRooms[index];
    }

    function formatDuration(seconds) {
        const value = Math.max(0, Math.round(seconds || 0));
        const minutes = Math.floor(value / 60);
        const remainder = value % 60;
        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder;
    }

    function persistWebSettings() {
        const next = {};
        const current = root.settingsDocument || {};
        for (const key in current)
            next[key] = current[key];

        next.cleanMode = root.cleanMode;
        next.dashboardWorkspace = root.dashboardWorkspace;
        next.webScreensaverEnabled = root.webScreensaverEnabled;
        next.webDensity = root.webDensity;
        next.webWindStrength = root.webWindStrength;
        next.webMotionAmount = root.webMotionAmount;
        next.webFps = root.webFps;
        next.webRenderScale = root.webRenderScale;
        next.webIdleSeconds = root.webIdleSeconds;
        next.webWeaveSeconds = root.webWeaveSeconds;
        next.projectRoot = root.projectRoot;
        next.projectSort = root.projectSort;
        root.settingsDocument = next;
        settingsFile.setText(JSON.stringify(next, null, 2) + "\n");
    }

    function setProjectRoot(path) {
        const selected = String(path || "~/Projects");
        if (selected === root.projectRoot)
            return;
        root.projectRoot = selected;
        root.projects = [];
        root.projectsRevision = "";
        root.persistWebSettings();
    }

    function setProjectSort(value) {
        const selected = String(value || "modified-desc");
        if (selected === root.projectSort)
            return;
        root.projectSort = selected;
        root.projectsRevision = "";
        root.persistWebSettings();
    }

    function setWebEnabled(value) {
        root.webScreensaverEnabled = value;
        root.persistWebSettings();
    }

    function setWebDensity(value) {
        root.webDensity = Math.max(0.20, Math.min(2.0, value));
        root.persistWebSettings();
    }

    function setWebWind(value) {
        root.webWindStrength = Math.max(0, Math.min(3.0, value));
        root.persistWebSettings();
    }

    function setWebMotion(value) {
        root.webMotionAmount = Math.max(0, Math.min(3.0, value));
        root.persistWebSettings();
    }

    function setWebFps(value) {
        root.webFps = Math.max(10, Math.min(60, Math.round(value)));
        root.persistWebSettings();
    }

    function setWebRenderScale(value) {
        root.webRenderScale = Math.max(0.50, Math.min(1.0, value));
        root.persistWebSettings();
    }

    function setWebIdle(value) {
        root.webIdleSeconds = Math.max(5, Math.min(300, Math.round(value)));
        root.persistWebSettings();
    }

    function setWebWeave(value) {
        root.webWeaveSeconds = Math.max(10, Math.min(180, Math.round(value)));
        root.persistWebSettings();
    }

    visible: root.archiveVisible
    aboveWindows: false
    exclusiveZone: 0
    focusable: false
    color: "transparent"

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    FileView {
        id: settingsFile
        path: Quickshell.shellPath("settings.json")
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                const settings = JSON.parse(text());
                root.settingsDocument = settings;
                root.cleanMode = settings.cleanMode === true;
                root.dashboardWorkspace = Math.max(1, Math.min(10, Number(settings.dashboardWorkspace || 1)));
                root.webScreensaverEnabled = settings.webScreensaverEnabled !== false;
                root.webDensity = Math.max(0.20, Math.min(2.0, Number(settings.webDensity || 0.95)));
                root.webWindStrength = Math.max(0, Math.min(3.0, Number(settings.webWindStrength || 1.75)));
                root.webMotionAmount = Math.max(0, Math.min(3.0, Number(settings.webMotionAmount || 2.0)));
                root.webFps = Math.max(10, Math.min(60, Number(settings.webFps || 30)));
                root.webRenderScale = Math.max(0.50, Math.min(1.0, Number(settings.webRenderScale || 0.75)));
                root.webIdleSeconds = Math.max(5, Math.min(300, Number(settings.webIdleSeconds || 90)));
                root.webWeaveSeconds = Math.max(10, Math.min(180, Number(settings.webWeaveSeconds || 30)));
                root.projectRoot = String(settings.projectRoot || "~/Projects");
                const requestedSort = String(settings.projectSort || "modified-desc");
                root.projectSort = root.workbenchSortOptions.some(option => option.value === requestedSort)
                    ? requestedSort : "modified-desc";
            } catch (error) {
                console.warn("TENEBRIS settings parse failed:", error);
            }
        }
        onFileChanged: reload()
    }

    Process {
        id: statePoll
        command: [
            "python3", Quickshell.shellPath("tenebris-state.py"),
            "--role=dashboard",
            "--projects-root=" + root.projectRoot,
            "--projects-sort=" + root.projectSort
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim());
                    root.cpuUsage = data.cpu || 0;
                    root.cpuTemp = data.cpuTemp || 0;
                    root.ramUsage = data.ram || 0;
                    root.ramText = data.ramText || "0/0G";
                    root.diskUsage = data.disk || 0;
                    root.diskText = data.diskText || "0/0G";
                    root.netDown = data.downText || "0 B/s";
                    root.netUp = data.upText || "0 B/s";
                    root.ipAddress = data.ip || "SEALED";
                    const network = data.network || {};
                    root.networkName = network.name || "NO ACTIVE LINK";
                    root.networkKind = network.kind || "DISCONNECTED";
                    root.networkInterface = network.iface || "";
                    root.networkSignal = network.signal || "--";
                    root.networkBand = network.band || "";
                    root.battery = data.battery || 0;
                    root.batteryStatus = data.batteryStatus || "AC";
                    root.uptime = data.uptime || "0h 0m";
                    root.hostName = String(data.host || "TENEBRIS").toUpperCase();
                    const nextProjectsRevision = String(data.projectsRevision || "");
                    if (nextProjectsRevision !== root.projectsRevision) {
                        root.projects = data.projects || [];
                        root.projectsRevision = nextProjectsRevision;
                    }
                    root.workspaces = data.workspaces || [];
                    const intentionallyStowed = root.terminalPresent
                        && root.terminalWorkspace === "special:tenebris-stowed";
                    if (data.terminalPresent === true) {
                        root.terminalPresent = true;
                        root.terminalLaunchPending = false;
                    } else if (!root.terminalLaunchPending && !intentionallyStowed) {
                        root.terminalPresent = false;
                    }
                    if (data.terminalPresent === true || !intentionallyStowed)
                        root.terminalWorkspace = data.terminalWorkspace || "";
                    root.dashboardOccupied = data.dashboardOccupied === true;
                    const music = data.music || {};
                    root.musicProvider = music.active || "";
                    root.ymcAvailable = music.ymcAvailable === true;
                    root.cliampAvailable = music.cliampAvailable === true;
                    root.ymcVisible = music.ymcVisible === true;
                    root.cliampVisible = music.cliampVisible === true;
                    const player = data.player || {};
                    root.playerStatus = player.status || "SILENT";
                    root.playerArtist = player.artist || "NO CANTICLE";
                    root.playerTitle = player.title || "THE ARCHIVE RESTS";
                    root.playerAlbum = player.album || "";
                    root.playerSource = player.source || "";
                    root.playerId = player.id || "";
                    root.playerArt = player.artUrl || "";
                    root.playerUrl = player.url || "";
                    root.playerVideoId = player.videoId || "";
                    root.playerPosition = player.position || 0;
                    root.playerLength = player.length || 0;
                    root.playerRepeat = player.repeat || "off";
                    root.stateLoaded = true;
                    Qt.callLater(root.syncTerminalPlacement);
                } catch (error) {
                    console.warn("TENEBRIS state parse failed:", error);
                }
            }
        }
    }

    IpcHandler {
        target: "tenebris.dashboard"

        function webMenu(): string {
            root.webSettingsOpen = !root.webSettingsOpen;
            return root.webSettingsOpen ? "open" : "closed";
        }

        function openWebMenu(): string {
            root.webSettingsOpen = true;
            return "open";
        }

        function closeWebMenu(): string {
            root.webSettingsOpen = false;
            return "closed";
        }

        function projectPicker(): string {
            root.projectSortOpen = false;
            root.projectPickerOpen = !root.projectPickerOpen;
            return root.projectPickerOpen ? "open" : "closed";
        }

        function projectSortMenu(): string {
            root.projectPickerOpen = false;
            root.projectSortOpen = !root.projectSortOpen;
            return root.projectSortOpen ? "open" : "closed";
        }

        function terminalStatus(): string {
            return JSON.stringify({
                present: root.terminalPresent,
                workspace: root.terminalWorkspace,
                occupied: root.dashboardOccupied,
                moving: root.terminalMovePending
            });
        }
    }

    Process {
        id: cavaProcess
        command: ["cava", "-p", Quickshell.shellPath("cava-tenebris.conf")]
        stdout: SplitParser {
            onRead: function(line) { root.updateSpectrum(line); }
        }
        onExited: if (root.archiveVisible && root.liveVisualizerEnabled) cavaRestart.restart()
    }

    Timer {
        id: cavaRestart
        interval: 1000
        onTriggered: if (root.archiveVisible && root.liveVisualizerEnabled && !cavaProcess.running) cavaProcess.running = true
    }

    onArchiveVisibleChanged: {
        if (root.archiveVisible && root.liveVisualizerEnabled && !cavaProcess.running)
            cavaProcess.running = true;
        else if (!root.archiveVisible) {
            if (cavaProcess.running)
                cavaProcess.running = false;
            root.musicPlayerDismissRequested();
        }
    }

    Component.onCompleted: {
        if (root.archiveVisible && root.liveVisualizerEnabled && !cavaProcess.running)
            cavaProcess.running = true;
    }

    Timer {
        interval: 2400
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: if (!statePoll.running) statePoll.running = true
    }

    Timer {
        id: terminalBootstrap
        interval: 300
        running: root.visible && root.stateLoaded && !root.terminalPresent
        onTriggered: root.ensureTerminal()
    }

    Timer {
        id: terminalMoveGuard
        interval: 180
        onTriggered: {
            root.terminalMovePending = false;
            root.refreshLiveToplevels();
        }
    }

    Timer {
        id: terminalStowGuard
        interval: 2400
        onTriggered: {
            root.terminalStowHold = false;
            root.refreshLiveToplevels();
        }
    }

    Timer {
        id: terminalLaunchGuard
        interval: 3000
        onTriggered: {
            root.terminalLaunchPending = false;
            root.refreshLiveToplevels();
        }
    }

    Process {
        id: terminalStateProbe
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.refreshTerminalStateFromClients(JSON.parse(text.trim()));
                } catch (error) {
                    console.warn("TENEBRIS client probe failed:", error);
                }
            }
        }
        onExited: {
            if (root.terminalProbeQueued)
                terminalEventProbe.restart();
        }
    }

    Timer {
        id: terminalEventProbe
        interval: 24
        onTriggered: {
            if (terminalStateProbe.running) {
                root.terminalProbeQueued = true;
                return;
            }
            root.terminalProbeQueued = false;
            terminalStateProbe.running = true;
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) { root.handleHyprlandEvent(event); }
    }

    Timer {
        interval: 600
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: if (!terminalStateProbe.running) terminalStateProbe.running = true
    }

    Timer {
        interval: 3200
        repeat: true
        running: root.visible && root.stateLoaded
        onTriggered: root.ensureTerminal()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: {
            root.clockText = Qt.formatDateTime(new Date(), "HH:mm");
            root.dateText = Qt.formatDateTime(new Date(), "dddd, dd MMMM yyyy");
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#10000000"

        // A dry matte vignette around the wallpaper without shaders or blur.
        Rectangle { anchors.left: parent.left; width: parent.width * 0.12; height: parent.height; color: "#30000000" }
        Rectangle { anchors.right: parent.right; width: parent.width * 0.12; height: parent.height; color: "#30000000" }
        Rectangle { anchors.top: parent.top; width: parent.width; height: parent.height * 0.08; color: "#22000000" }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.height * 0.09; color: "#30000000" }

        ArchiveRail {
            id: archiveRail
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.top: parent.top
            anchors.topMargin: 48
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: implicitWidth
            cleanMode: root.cleanMode
            webScreensaverEnabled: root.webScreensaverEnabled
            onWebMenuRequested: root.webSettingsOpen = !root.webSettingsOpen
            onCommandRequested: function(command) {
                root.launchRailCommand(command);
            }
        }

        Item {
            id: centralCanvas
            anchors.left: archiveRail.right
            anchors.leftMargin: 18
            anchors.right: rightColumn.left
            anchors.rightMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 48
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18

            // The selected XDG terminal is placed over this registered frame by Hyprland.
            ArchiveFrame {
                id: terminalRegister
                visible: !root.dashboardOccupied && !root.terminalStowHold
                x: 0
                y: 0
                width: parent.width * 0.535
                height: parent.height * 0.55
                title: "SCRIBE TERMINAL"
                subtitle: "XDG · ZSH/BASH"
                quiet: true
                textured: !root.cleanMode
                // The click-through top layer always owns these corners. This
                // leaves one visual authority during terminal launch/resizes.
                showCorners: false
                // The real translucent terminal sits above this registration bed.
                panelColor: "#44090909"
            }

            ArchiveFrame {
                id: worksPanel
                x: parent.width * 0.55
                y: 0
                width: parent.width * 0.45
                height: parent.height * 0.55
                title: "WORKBENCH"
                subtitle: root.projectRoot
                subtitleInteractive: true
                showSubtitleWithButtons: true
                headerIcon: "󰒺"
                headerIconBare: true
                headerIconActive: root.projectSortOpen
                onSubtitleClicked: {
                    root.projectSortOpen = false;
                    root.projectPickerOpen = true;
                }
                onHeaderIconClicked: root.projectSortOpen = !root.projectSortOpen
                textured: !root.cleanMode

                Image {
                    visible: !root.cleanMode
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 42
                    height: 112
                    source: Quickshell.shellPath("assets/quill.png")
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.24
                }

                Text {
                    visible: root.projects.length === 0
                    anchors.centerIn: parent
                    text: "NO VOLUMES CATALOGUED"
                    color: TenebrisTheme.textMuted
                    font.family: TenebrisTheme.contentFont
                    font.pixelSize: TenebrisTheme.typeBody
                    font.letterSpacing: 1
                }

                ListView {
                    id: projectsList
                    anchors.fill: parent
                    anchors.rightMargin: 5
                    model: root.projects
                    spacing: 3
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: true
                    cacheBuffer: 96

                    delegate: Rectangle {
                        id: projectRow
                        required property var modelData
                        readonly property bool hovered: projectHover.hovered
                        width: ListView.view.width
                        height: 45
                        color: hovered ? "#181716" : "transparent"
                        border.color: hovered ? TenebrisTheme.borderDim : "transparent"
                        border.width: 1

                        Rectangle {
                            visible: projectRow.hovered
                            anchors.left: parent.left
                            height: parent.height
                            width: 2
                            color: TenebrisTheme.blood
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 11
                            anchors.top: parent.top
                            anchors.topMargin: 7
                            width: parent.width - 190
                            text: modelData.name.toUpperCase()
                            color: projectRow.hovered ? TenebrisTheme.bone : TenebrisTheme.text
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeBody
                            font.bold: true
                            font.letterSpacing: 0.8
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 11
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            text: modelData.branch
                            color: TenebrisTheme.textMuted
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeCaption
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            z: 2

                            Repeater {
                                model: root.workbenchActions

                                WorkbenchAction {
                                    required property var modelData
                                    visible: modelData.action !== "github"
                                        || projectRow.modelData.isGit === true
                                    enabled: modelData.action !== "github"
                                        || String(projectRow.modelData.githubUrl || "").length > 0
                                    asset: Quickshell.shellPath("assets/" + modelData.asset)
                                    label: modelData.label
                                    iconOffsetX: Number(modelData.iconOffsetX || 0)
                                    iconOffsetY: Number(modelData.iconOffsetY || 0)
                                    onInvoked: root.projectAction(modelData.action, projectRow.modelData.path)
                                }
                            }
                        }

                        HoverHandler {
                            id: projectHover
                        }

                        MouseArea {
                            id: projectMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.projectAction("vscode", modelData.path)
                        }
                    }
                }

                Rectangle {
                    visible: projectsList.contentHeight > projectsList.height
                    anchors.right: parent.right
                    width: 2
                    height: Math.max(24, parent.height * projectsList.visibleArea.heightRatio)
                    y: Math.max(0, Math.min(
                        parent.height - height,
                        parent.height * projectsList.visibleArea.yPosition
                    ))
                    color: TenebrisTheme.bloodBright
                    opacity: 0.68
                    z: 5
                }

                MouseArea {
                    visible: root.projectSortOpen
                    anchors.fill: parent
                    z: 20
                    onClicked: root.projectSortOpen = false
                }

                Rectangle {
                    id: sortPopover
                    visible: root.projectSortOpen
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: 184
                    height: sortColumn.height + 12
                    color: "#F20A0A09"
                    border.color: TenebrisTheme.border
                    z: 21

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        color: "transparent"
                        border.color: TenebrisTheme.borderDim
                    }

                    Column {
                        id: sortColumn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        spacing: 2

                        Repeater {
                            model: root.workbenchSortOptions

                            Rectangle {
                                required property var modelData
                                width: sortColumn.width
                                height: 31
                                color: modelData.value === root.projectSort
                                    ? TenebrisTheme.bloodDark
                                    : (sortMouse.containsMouse ? "#211718" : "transparent")

                                Rectangle {
                                    visible: modelData.value === root.projectSort
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 2
                                    height: 19
                                    color: TenebrisTheme.bloodBright
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: modelData.value === root.projectSort
                                        ? TenebrisTheme.bone : TenebrisTheme.text
                                    font.family: TenebrisTheme.contentFont
                                    font.pixelSize: TenebrisTheme.typeCaption
                                    font.letterSpacing: 0.6
                                }

                                MouseArea {
                                    id: sortMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.setProjectSort(modelData.value);
                                        root.projectSortOpen = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ArchiveFrame {
                id: canticlesPanel
                x: 0
                y: parent.height * 0.575
                width: parent.width * 0.535
                height: parent.height * 0.425
                title: "CANTICLES"
                headerIcon: root.ymcAvailable ? "󰗃" : (root.cliampAvailable ? "󰎆" : "")
                headerIconActive: root.ymcAvailable
                    ? root.musicProvider === "ymc"
                    : root.musicProvider === "cliamp"
                onHeaderIconClicked: root.toggleMusicPlayer(root.ymcAvailable ? "ymc" : "cliamp")
                headerSecondaryIcon: root.ymcAvailable && root.cliampAvailable ? "󰎆" : ""
                headerSecondaryIconActive: root.musicProvider === "cliamp"
                onHeaderSecondaryIconClicked: root.toggleMusicPlayer("cliamp")
                textured: !root.cleanMode

                Item {
                    anchors.fill: parent

                    Rectangle {
                        id: coverFrame
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.min(height, parent.width * 0.44)
                        color: "#B80A0A0A"
                        border.color: TenebrisTheme.borderDim
                        border.width: 1
                        clip: true

                        Image {
                            id: albumArt
                            anchors.fill: parent
                            anchors.margins: 4
                            source: root.playerArt
                            visible: status === Image.Ready
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            opacity: 0.86
                        }

                        Image {
                            anchors.centerIn: parent
                            visible: albumArt.status !== Image.Ready && !root.cleanMode
                            width: parent.width * 0.62
                            height: width
                            source: Quickshell.shellPath("assets/large_sigil@2x.png")
                            fillMode: Image.PreserveAspectFit
                            opacity: 0.55
                        }

                        Rectangle {
                            visible: root.playerSource.length > 0
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 22
                            color: "#B2050505"

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 12
                                text: root.playerSource
                                color: TenebrisTheme.silver
                                font.family: TenebrisTheme.contentFont
                                font.pixelSize: TenebrisTheme.typeCaption
                                font.letterSpacing: 0.8
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Column {
                        anchors.left: coverFrame.right
                        anchors.leftMargin: 18
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 5

                        Text {
                            id: canticleTitle
                            width: parent.width
                            text: root.playerTitle
                            color: canticleTitleMouse.containsMouse
                                ? TenebrisTheme.bloodBright
                                : TenebrisTheme.bone
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeLead
                            font.bold: true
                            font.underline: canticleTitleMouse.containsMouse
                            elide: Text.ElideRight

                            Behavior on color { ColorAnimation { duration: TenebrisTheme.motionFast } }

                            MouseArea {
                                id: canticleTitleMouse
                                anchors.fill: parent
                                enabled: root.playerId.length > 0
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.musicMetadata("title", root.playerTitle)
                            }
                        }

                        Text {
                            id: canticleArtist
                            width: parent.width
                            text: root.playerArtist
                            color: canticleArtistMouse.containsMouse
                                ? TenebrisTheme.silver
                                : TenebrisTheme.textMuted
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeBody
                            font.underline: canticleArtistMouse.containsMouse
                            elide: Text.ElideRight

                            Behavior on color { ColorAnimation { duration: TenebrisTheme.motionFast } }

                            MouseArea {
                                id: canticleArtistMouse
                                anchors.fill: parent
                                enabled: root.playerId.length > 0
                                    && root.playerArtist !== "NO CANTICLE"
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.musicMetadata("artist", root.playerArtist)
                            }
                        }

                        Text {
                            id: canticleAlbum
                            width: parent.width
                            text: root.playerAlbum.length > 0
                                ? root.playerAlbum
                                : (root.playerId.length > 0 ? "UNBOUND RECORD" : "AWAITING AN MPRIS CANTICLE")
                            color: canticleAlbumMouse.containsMouse
                                ? TenebrisTheme.silver
                                : TenebrisTheme.border
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeMeta
                            font.italic: true
                            font.underline: canticleAlbumMouse.containsMouse
                            elide: Text.ElideRight

                            Behavior on color { ColorAnimation { duration: TenebrisTheme.motionFast } }

                            MouseArea {
                                id: canticleAlbumMouse
                                anchors.fill: parent
                                enabled: root.playerId.length > 0
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.musicMetadata("album", root.playerAlbum.length > 0
                                    ? root.playerArtist + " " + root.playerAlbum
                                    : root.playerArtist + " " + root.playerTitle)
                            }
                        }

                        OrnamentDivider { width: parent.width; height: 17; textured: !root.cleanMode }

                        Text {
                            text: root.formatDuration(root.playerPosition) + "  /  " + root.formatDuration(root.playerLength)
                            color: TenebrisTheme.text
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeMeta
                        }

                        Item {
                            id: seekTrack
                            width: parent.width
                            height: 17
                            property real hoverRatio: 0

                            Rectangle {
                                id: seekBed
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: seekMouse.containsMouse ? 6 : 3
                                color: seekMouse.containsMouse ? TenebrisTheme.border : TenebrisTheme.borderDim

                                Behavior on height { NumberAnimation { duration: TenebrisTheme.motionFast } }
                                Behavior on color { ColorAnimation { duration: TenebrisTheme.motionFast } }

                                Rectangle {
                                    width: parent.width * Math.min(1, root.playerPosition / Math.max(1, root.playerLength))
                                    height: parent.height
                                    color: seekMouse.containsMouse ? TenebrisTheme.bloodBright : TenebrisTheme.blood
                                    Behavior on width { NumberAnimation { duration: TenebrisTheme.motionNormal } }
                                }

                                Rectangle {
                                    visible: seekMouse.containsMouse && root.playerLength > 0
                                    x: Math.max(-4, Math.min(parent.width - 4,
                                        parent.width * root.playerPosition / Math.max(1, root.playerLength) - 4))
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: TenebrisTheme.bone
                                    border.color: TenebrisTheme.bloodBright
                                    border.width: 1
                                }
                            }

                            Rectangle {
                                visible: seekMouse.containsMouse && root.playerLength > 0
                                x: Math.max(0, Math.min(parent.width - width, seekMouse.mouseX - width * 0.5))
                                y: -17
                                width: seekHoverText.implicitWidth + 10
                                height: 16
                                color: "#EC0A0A0A"
                                border.color: TenebrisTheme.border
                                border.width: 1

                                Text {
                                    id: seekHoverText
                                    anchors.centerIn: parent
                                    text: root.formatDuration(seekTrack.hoverRatio * root.playerLength)
                                    color: TenebrisTheme.bone
                                    font.family: TenebrisTheme.contentFont
                                    font.pixelSize: TenebrisTheme.typeCaption
                                }
                            }

                            MouseArea {
                                id: seekMouse
                                anchors.fill: parent
                                enabled: root.playerId.length > 0 && root.playerLength > 0
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onPositionChanged: function(mouse) {
                                    seekTrack.hoverRatio = Math.max(0, Math.min(1, mouse.x / Math.max(1, width)));
                                }
                                onClicked: function(mouse) {
                                    root.seekMedia(mouse.x / Math.max(1, width));
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 22
                            opacity: root.playerId.length > 0 ? 1.0 : 0.28

                            Repeater {
                                model: [
                                    { glyph: "󰒮", action: "previous" },
                                    { glyph: root.playerStatus === "PLAYING" ? "󰏤" : "󰐊", action: "play-pause" },
                                    { glyph: "󰒭", action: "next" },
                                    { glyph: root.playerRepeat === "one" ? "󰑘" : "󰑖", action: "repeat" }
                                ]

                                Text {
                                    required property var modelData
                                    text: modelData.glyph
                                    color: modelData.action === "repeat" && root.playerRepeat !== "off"
                                        ? TenebrisTheme.bloodBright
                                        : (mediaMouse.containsMouse ? TenebrisTheme.bone : TenebrisTheme.silver)
                                    font.family: TenebrisTheme.monoFont
                                    font.pixelSize: 18

                                    MouseArea {
                                        id: mediaMouse
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        enabled: root.playerId.length > 0
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.mediaControl(modelData.action)
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 140
                            clip: true

                            SigilVisualizer {
                                anchors.fill: parent
                                anchors.margins: 4
                                visible: root.liveVisualizerEnabled
                                band0: root.audioBand0
                                band1: root.audioBand1
                                band2: root.audioBand2
                                band3: root.audioBand3
                                band4: root.audioBand4
                                band5: root.audioBand5
                                band6: root.audioBand6
                                band7: root.audioBand7
                                band8: root.audioBand8
                                band9: root.audioBand9
                                band10: root.audioBand10
                                band11: root.audioBand11
                                band12: root.audioBand12
                                band13: root.audioBand13
                                band14: root.audioBand14
                                band15: root.audioBand15
                                energy: root.audioEnergy
                                peak: root.audioPeak
                                playing: root.playerStatus === "PLAYING"
                                trackKey: root.playerArtist + " // " + root.playerTitle
                            }

                            Image {
                                visible: !root.liveVisualizerEnabled
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) * 0.76
                                height: width
                                source: Quickshell.shellPath("assets/large_sigil.png")
                                fillMode: Image.PreserveAspectFit
                                opacity: 0.34
                            }
                        }
                    }
                }
            }

            ArchiveFrame {
                id: ledgerPanel
                x: parent.width * 0.55
                y: parent.height * 0.575
                width: parent.width * 0.45
                height: parent.height * 0.425
                title: "WORKSPACES"
                subtitle: "1–10"
                textured: !root.cleanMode

                Grid {
                    id: workspaceGrid
                    anchors.fill: parent
                    columns: 5
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: root.workspaces

                        Rectangle {
                            required property var modelData
                            readonly property var room: root.workspaceRoom(modelData.id)
                            width: (workspaceGrid.width - workspaceGrid.columnSpacing * 4) / 5
                            height: (workspaceGrid.height - workspaceGrid.rowSpacing) / 2
                            color: "#D4070707"
                            border.color: workspaceMouse.containsMouse
                                ? TenebrisTheme.border
                                : TenebrisTheme.borderDim
                            border.width: 1
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: Quickshell.shellPath("assets/workspaces/" + parent.room.asset)
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                opacity: parent.modelData.active ? 0.72 : (workspaceMouse.containsMouse ? 0.62 : 0.46)
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0.0; color: "#22000000" }
                                    GradientStop { position: 0.54; color: "#46000000" }
                                    GradientStop { position: 1.0; color: "#ED050505" }
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 7
                                text: modelData.id === 10 ? "0" : modelData.id
                                color: modelData.active ? TenebrisTheme.bone : TenebrisTheme.silver
                                font.family: TenebrisTheme.contentFont
                                font.pixelSize: TenebrisTheme.typeLead
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 7
                                text: modelData.count
                                color: modelData.count > 0 ? TenebrisTheme.text : TenebrisTheme.border
                                font.family: TenebrisTheme.contentFont
                                font.pixelSize: TenebrisTheme.typeCaption
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                text: parent.room.name
                                color: modelData.active ? TenebrisTheme.bone : TenebrisTheme.silver
                                font.family: TenebrisTheme.contentFont
                                font.pixelSize: TenebrisTheme.typeBody
                                font.bold: modelData.active
                                font.letterSpacing: 0.8
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: workspaceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.focusWorkspace(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        Column {
            id: rightColumn
            anchors.right: parent.right
            anchors.rightMargin: 13
            anchors.top: parent.top
            anchors.topMargin: 48
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: Math.max(250, parent.width * 0.18)
            spacing: root.compactHeight ? 8 : 10

            ArchiveFrame {
                width: parent.width
                height: root.compactHeight ? 240 : 276
                title: "VITALS"
                subtitle: root.hostName
                textured: !root.cleanMode

                Column {
                    anchors.fill: parent
                    spacing: 11

                    MetricBar {
                        width: parent.width
                        label: "CORE"
                        value: root.cpuUsage
                        valueText: Math.round(root.cpuUsage) + "%  ·  " + root.cpuTemp + "°C"
                        critical: root.cpuTemp >= 85
                    }
                    MetricBar { width: parent.width; label: "MEMORY"; value: root.ramUsage; valueText: root.ramText }
                    MetricBar { width: parent.width; label: "VAULT"; value: root.diskUsage; valueText: root.diskText }

                    OrnamentDivider { width: parent.width; textured: !root.cleanMode }

                    Row {
                        width: parent.width
                        Text { text: "VIGIL"; color: TenebrisTheme.textMuted; font.family: TenebrisTheme.contentFont; font.pixelSize: TenebrisTheme.typeMeta }
                        Text { width: parent.width - 40; text: root.uptime; color: TenebrisTheme.text; font.family: TenebrisTheme.contentFont; font.pixelSize: TenebrisTheme.typeMeta; horizontalAlignment: Text.AlignRight }
                    }
                }
            }

            ArchiveFrame {
                width: parent.width
                height: root.compactHeight ? 160 : 190
                title: "SEALED CORRESPONDENCE"
                subtitle: "LINK"
                textured: !root.cleanMode

                Item {
                    anchors.fill: parent

                    Item {
                        id: dispatchRelic
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 106

                        Rectangle {
                            id: correspondenceEnvelope
                            x: 7
                            y: 16
                            width: 84
                            height: 57
                            color: "#C411100F"
                            border.color: TenebrisTheme.border
                            border.width: 1

                            Canvas {
                                anchors.fill: parent
                                anchors.margins: 1
                                antialiasing: true

                                onPaint: {
                                    const context = getContext("2d");
                                    context.clearRect(0, 0, width, height);

                                    // A single closed flap: no lower fold lines run
                                    // beneath the wax seal or collide at the centre.
                                    context.beginPath();
                                    context.moveTo(5.5, 7.5);
                                    context.lineTo(width * 0.5, height * 0.55);
                                    context.lineTo(width - 5.5, 7.5);
                                    context.strokeStyle = "#4B4843";
                                    context.lineWidth = 1;
                                    context.stroke();

                                    const markX = width * 0.5;
                                    const markY = 10.5;
                                    context.beginPath();
                                    context.moveTo(markX, markY - 3);
                                    context.lineTo(markX + 3, markY);
                                    context.lineTo(markX, markY + 3);
                                    context.lineTo(markX - 3, markY);
                                    context.closePath();
                                    context.fillStyle = "#8A867F";
                                    context.fill();
                                }
                            }
                        }

                        Image {
                            anchors.left: correspondenceEnvelope.left
                            anchors.leftMargin: 50
                            anchors.top: correspondenceEnvelope.top
                            anchors.topMargin: 35
                            width: 46
                            height: 52
                            source: Quickshell.shellPath("assets/wax_seal_round@2x.png")
                            sourceClipRect: Qt.rect(0, 0, 172, 190)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            opacity: root.ipAddress === "SEALED" ? 0.42 : 0.88
                        }

                    }

                    Item {
                        anchors.left: dispatchRelic.right
                        anchors.leftMargin: 9
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        Text {
                            id: networkNameText
                            anchors.left: parent.left
                            anchors.right: linkStateIndicator.left
                            anchors.rightMargin: 10
                            anchors.top: parent.top
                            text: root.networkName
                            color: root.ipAddress === "SEALED"
                                ? TenebrisTheme.bloodBright : TenebrisTheme.bone
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeBody
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.2
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            id: linkStateIndicator
                            anchors.right: parent.right
                            // Share the exact centre line of the VAULT route node.
                            anchors.rightMargin: correspondenceRoute.nodeInset
                                + correspondenceRoute.nodeSize / 2 - width / 2
                            anchors.verticalCenter: networkNameText.verticalCenter
                            width: 7
                            height: 7
                            rotation: 45
                            color: root.ipAddress === "SEALED"
                                ? TenebrisTheme.bloodDark : TenebrisTheme.blood
                            border.color: root.ipAddress === "SEALED"
                                ? TenebrisTheme.bloodBright : TenebrisTheme.silver
                            border.width: 1
                        }

                        Text {
                            id: addressText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: networkNameText.bottom
                            anchors.topMargin: 2
                            text: root.ipAddress
                            color: root.ipAddress === "SEALED"
                                ? TenebrisTheme.bloodBright : TenebrisTheme.silver
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeMeta
                            font.letterSpacing: 0.25
                            elide: Text.ElideRight
                        }

                        Text {
                            id: networkMetaText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: addressText.bottom
                            anchors.topMargin: 2
                            text: {
                                const parts = [root.networkKind];
                                if (root.networkBand.length > 0)
                                    parts.push(root.networkBand);
                                if (root.networkSignal !== "--")
                                    parts.push(root.networkSignal);
                                return parts.join("  ·  ");
                            }
                            color: TenebrisTheme.textMuted
                            font.family: TenebrisTheme.contentFont
                            font.pixelSize: TenebrisTheme.typeMicro
                            font.letterSpacing: 0.25
                            elide: Text.ElideRight
                        }

                        Item {
                            id: correspondenceRoute
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: networkMetaText.bottom
                            anchors.topMargin: 3
                            height: 30

                            readonly property real nodeInset: 4
                            readonly property real nodeSize: 8
                            readonly property real lineInset: 8

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: correspondenceRoute.lineInset
                                anchors.rightMargin: correspondenceRoute.lineInset
                                anchors.verticalCenter: parent.verticalCenter
                                height: 1
                                color: TenebrisTheme.borderDim
                                z: 0
                            }

                            Repeater {
                                model: [
                                    { ratio: 0.0, label: "GATE" },
                                    { ratio: 0.5, label: "RELAY" },
                                    { ratio: 1.0, label: "VAULT" }
                                ]

                                Item {
                                    required property var modelData
                                    x: correspondenceRoute.nodeInset
                                        + modelData.ratio * (correspondenceRoute.width
                                            - correspondenceRoute.nodeInset * 2 - width)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: correspondenceRoute.nodeSize
                                    height: correspondenceRoute.nodeSize
                                    z: 2

                                    Rectangle {
                                        anchors.fill: parent
                                        rotation: 45
                                        color: "#171615"
                                        border.color: TenebrisTheme.silver
                                        border.width: 1
                                    }

                                    Text {
                                        anchors.top: parent.bottom
                                        anchors.topMargin: 4
                                        x: modelData.ratio === 0.0
                                            ? 0 : (modelData.ratio === 1.0 ? -28 : -16)
                                        width: 40
                                        text: modelData.label
                                        color: TenebrisTheme.textMuted
                                        font.family: TenebrisTheme.contentFont
                                        font.pixelSize: TenebrisTheme.typeMicro
                                        font.letterSpacing: 0.6
                                        horizontalAlignment: modelData.ratio === 0.0
                                            ? Text.AlignLeft
                                            : (modelData.ratio === 1.0 ? Text.AlignRight : Text.AlignHCenter)
                                    }
                                }
                            }

                            Rectangle {
                                id: routePulse
                                visible: root.ipAddress !== "SEALED"
                                anchors.verticalCenter: parent.verticalCenter
                                readonly property real travelStart: correspondenceRoute.lineInset
                                readonly property real travelEnd: Math.max(travelStart,
                                    correspondenceRoute.width - correspondenceRoute.lineInset - width)
                                readonly property real travelProgress: travelEnd > travelStart
                                    ? (x - travelStart) / (travelEnd - travelStart) : 0
                                width: 14
                                height: 2
                                color: TenebrisTheme.bloodBright
                                opacity: {
                                    const edgeFade = 0.14;
                                    const fadeIn = Math.min(1,
                                        Math.max(0, routePulse.travelProgress / edgeFade));
                                    const fadeOut = Math.min(1,
                                        Math.max(0, (1 - routePulse.travelProgress) / edgeFade));
                                    return 0.92 * Math.min(fadeIn, fadeOut);
                                }
                                z: 1

                                NumberAnimation on x {
                                    running: root.archiveVisible && routePulse.visible
                                    loops: Animation.Infinite
                                    from: routePulse.travelStart
                                    to: routePulse.travelEnd
                                    duration: 2600
                                    easing.type: Easing.Linear
                                }
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 28
                            spacing: 10

                            Column {
                                width: (parent.width - parent.spacing) / 2
                                spacing: 2
                                Text { text: "DESCENT"; color: TenebrisTheme.textMuted; font.family: TenebrisTheme.contentFont; font.pixelSize: TenebrisTheme.typeMicro; font.letterSpacing: 0.6 }
                                Text { text: root.netDown; color: TenebrisTheme.silver; font.family: TenebrisTheme.contentFont; font.pixelSize: TenebrisTheme.typeCaption }
                            }

                            Column {
                                width: (parent.width - parent.spacing) / 2
                                spacing: 2
                                Text { text: "ASCENT"; color: TenebrisTheme.textMuted; font.family: TenebrisTheme.contentFont; font.pixelSize: TenebrisTheme.typeMicro; font.letterSpacing: 0.6 }
                                Text { text: root.netUp; color: TenebrisTheme.silver; font.family: TenebrisTheme.contentFont; font.pixelSize: TenebrisTheme.typeCaption }
                            }
                        }
                    }
                }
            }

            ArchiveFrame {
                width: parent.width
                height: root.compactHeight
                    ? Math.max(170, rightColumn.height - 416)
                    : Math.max(190, rightColumn.height - 486)
                title: "THE UNSEEN SEAL"
                subtitle: ""
                textured: !root.cleanMode

                Image {
                    visible: !root.cleanMode
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: Math.min(parent.width * 0.72, 150)
                    height: width * 1.23
                    source: Quickshell.shellPath("assets/hanging_banners.png")
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.10
                }

                Image {
                    visible: !root.cleanMode
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 38
                    height: 94
                    source: Quickshell.shellPath("assets/candle.png")
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.62
                }

                AsciiSigil {
                    anchors.fill: parent
                }
            }
        }
    }
}
