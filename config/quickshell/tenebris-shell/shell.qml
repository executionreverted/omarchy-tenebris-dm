import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shellRoot

    property bool ymcPlayerOpen: false

    // Scriptable presentation controls are useful for captures and keep the
    // same single YMC overlay instance used by the dashboard header button.
    IpcHandler {
        target: "tenebris.music"

        function openYmc(): string {
            Quickshell.execDetached([
                "python3", Quickshell.shellPath("music-player.py"), "select", "ymc"
            ]);
            shellRoot.ymcPlayerOpen = true;
            return "open";
        }

        function closeYmc(): string {
            shellRoot.ymcPlayerOpen = false;
            return "closed";
        }

        function toggleYmc(): string {
            shellRoot.ymcPlayerOpen = !shellRoot.ymcPlayerOpen;
            return shellRoot.ymcPlayerOpen ? "open" : "closed";
        }
    }

    TenebrisBar { }
    Dashboard {
        id: dashboard
        onWebPreviewRequested: spiderWeb.beginWeb(true)
        onMusicPlayerRequested: function(provider) {
            if (provider === "ymc") {
                Quickshell.execDetached([
                    "python3", Quickshell.shellPath("music-player.py"), "select", "ymc"
                ]);
                shellRoot.ymcPlayerOpen = !shellRoot.ymcPlayerOpen;
            } else {
                shellRoot.ymcPlayerOpen = false;
                Quickshell.execDetached([
                    "python3", Quickshell.shellPath("music-player.py"), "toggle", provider
                ]);
            }
        }
        onMusicPlayerDismissRequested: shellRoot.ymcPlayerOpen = false
    }
    SpiderWebScreensaver {
        id: spiderWeb
        webEnabled: dashboard.webScreensaverEnabled
        webDensity: dashboard.webDensity
        windStrength: dashboard.webWindStrength
        motionAmount: dashboard.webMotionAmount
        renderFps: dashboard.webFps
        renderScale: dashboard.webRenderScale
        idleSeconds: dashboard.webIdleSeconds
        weaveSeconds: dashboard.webWeaveSeconds
    }
    WebSettingsOverlay {
        open: dashboard.webSettingsOpen && dashboard.archiveVisible
        webEnabled: dashboard.webScreensaverEnabled
        webDensity: dashboard.webDensity
        windStrength: dashboard.webWindStrength
        motionAmount: dashboard.webMotionAmount
        renderFps: dashboard.webFps
        renderScale: dashboard.webRenderScale
        idleSeconds: dashboard.webIdleSeconds
        weaveSeconds: dashboard.webWeaveSeconds
        onCloseRequested: dashboard.webSettingsOpen = false
        onEnabledRequested: value => dashboard.setWebEnabled(value)
        onDensityRequested: value => dashboard.setWebDensity(value)
        onWindRequested: value => dashboard.setWebWind(value)
        onMotionRequested: value => dashboard.setWebMotion(value)
        onFpsRequested: value => dashboard.setWebFps(value)
        onRenderScaleRequested: value => dashboard.setWebRenderScale(value)
        onIdleRequested: value => dashboard.setWebIdle(value)
        onWeaveRequested: value => dashboard.setWebWeave(value)
        onPreviewRequested: {
            dashboard.webSettingsOpen = false;
            spiderWeb.beginWeb(true);
        }
    }
    FolderPickerOverlay {
        open: dashboard.projectPickerOpen && dashboard.archiveVisible
        initialPath: dashboard.projectRoot
        onCloseRequested: dashboard.projectPickerOpen = false
        onFolderSelected: function(path) {
            dashboard.setProjectRoot(path);
            dashboard.projectPickerOpen = false;
        }
    }
    YmcPlayerOverlay {
        open: shellRoot.ymcPlayerOpen && dashboard.archiveVisible
        playerTitle: dashboard.playerTitle
        playerArtist: dashboard.playerArtist
        playerAlbum: dashboard.playerAlbum
        playerStatus: dashboard.playerStatus
        playerPosition: dashboard.playerPosition
        playerLength: dashboard.playerLength
        playerRepeat: dashboard.playerRepeat
        onCloseRequested: shellRoot.ymcPlayerOpen = false
    }
    TerminalFrameOverlay {
        overlayActive: dashboard.terminalFrameVisible
        terminalReady: dashboard.terminalWorkspace === String(dashboard.dashboardWorkspace)
    }
}
