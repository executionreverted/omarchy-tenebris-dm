-- Open the Black Archive on workspace 1. The QML shell keeps its terminal alive.
o.exec_on_start([[hyprctl dispatch "hl.dsp.focus({ workspace = '1' })"]])
o.launch_on_start("qs -p " .. os.getenv("HOME") .. "/.config/quickshell/tenebris-shell")
