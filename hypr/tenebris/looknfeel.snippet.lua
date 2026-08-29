-- TENEBRIS: compact iron geometry and deliberate motion.
hl.config({
  general = {
    gaps_in = 6,
    gaps_out = 10,
    border_size = 1,
  },
  decoration = {
    rounding = 2,
    dim_inactive = true,
    dim_strength = 0.08,
    shadow = { enabled = false },
    blur = { enabled = false },
  },
  cursor = {
    -- Omarchy defaults this to 1, which moves the pointer onto the dashboard
    -- terminal whenever workspace 1 is entered. Preserve the user's position.
    warp_on_change_workspace = 0,
  },
})

hl.curve("tenebrisHeavy", { type = "bezier", points = { { 0.22, 0.72 }, { 0.18, 1.0 } } })
hl.curve("tenebrisFade", { type = "bezier", points = { { 0.4, 0.0 }, { 0.2, 1.0 } } })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5.2, bezier = "tenebrisHeavy", style = "popin 98%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5.8, bezier = "tenebrisFade", style = "popin 98%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3.0, bezier = "tenebrisFade" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 5.8, bezier = "tenebrisFade" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 5.0, bezier = "tenebrisHeavy", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 5.5, bezier = "tenebrisFade", style = "fade" })
-- The archive is a fixed room, not a canvas sliding in behind its terminal.
hl.animation({ leaf = "workspaces", enabled = false })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.0, bezier = "tenebrisFade", style = "fade" })

-- Registered terminal aligned with the left-hand dashboard volume.
o.window("^tenebris-terminal$", {
  name = "tenebris-dashboard-terminal",
  float = true,
  workspace = "1 silent",
  -- Begin exactly on the carved header rule; the top layer redraws that one
  -- divider above the native surface without adding a terminal perimeter.
  -- This is a close first-map size. Once the client exists, the click-through
  -- QML frame applies the exact piecewise panel geometry (including the
  -- narrow-output right-column minimum) through place-dashboard-terminal.py.
  size = { "((monitor_w*0.4387)-102)", "((monitor_h*0.55)-104)" },
  move = { "131", "131" },
  tag = "-default-opacity",
  -- Let the terminal fade only its background; keep prompt glyphs crisp.
  opacity = "1.0 0.96",
  border_size = 0,
  rounding = 0,
  -- Full-size popin removes motion; only the 300ms fade tree remains.
  animation = "popin 100%",
})

-- cliamp uses the same one-window contract. It remains optional: the dashboard
-- only exposes this provider when the binary is installed.
o.window("^tenebris-cliamp$", {
  name = "tenebris-persistent-cliamp",
  float = true,
  workspace = "special:tenebris-cliamp silent",
  size = { "(monitor_w*0.68)", "(monitor_h*0.74)" },
  move = { "(monitor_w*0.16)", "(monitor_h*0.13)" },
  tag = "-default-opacity",
  opacity = "1.0 0.96",
  border_color = "rgb(B51D24) rgb(66625B)",
  border_size = 1,
  rounding = 0,
  animation = "fade",
})

o.window("^tenebris-codex$", {
  name = "tenebris-codex-console",
  float = true,
  size = { "(monitor_w*0.58)", "(monitor_h*0.70)" },
  center = true,
  opacity = "0.97 0.92",
  border_color = "rgb(B8B2A7) rgb(7C0E13)",
  border_size = 1,
  rounding = 2,
  animation = "popin 98%",
})
