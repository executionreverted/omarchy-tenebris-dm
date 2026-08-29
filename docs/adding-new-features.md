# Adding New Features

This guide is for contributors and coding agents extending TENEBRIS without
breaking its visual language, clean-install behavior or Omarchy integration.

## Work from the source tree

Treat this repository as the source of truth. Do not develop inside the copies
under `~/.config`, and never edit `/usr/share/omarchy`.

The normal loop is:

1. Change files in this repository.
2. Run `./scripts/check.sh`.
3. Deploy with:

   ```bash
   ./install.sh --skip-packages --music-clients none \
     --display-mode keep --login-screen none
   ```

4. Inspect `hyprctl configerrors`, `qs list --all` and the Quickshell journal.
5. Test both the reference display and at least one compact resolution.

Do not commit caches, credentials, hostnames, SSIDs, IP addresses, private
project names or screenshots captured without `TENEBRIS_DEMO_MODE=1`.

## Architecture in one minute

- `Dashboard.qml` owns the Black Archive layout and UI state.
- Small visual components such as `ArchiveFrame.qml`, `ArchiveRail.qml` and
  `RasterIconButton.qml` keep repeated behavior consistent.
- `TenebrisTheme.qml` is the only authority for colors, typography, spacing and
  motion durations.
- `tenebris-state.py` produces one compact JSON snapshot for system, project,
  workspace and MPRIS state. Extend that snapshot instead of launching a new
  process from every delegate.
- Action helpers such as `music-player.py` and `project-action.py` perform work
  outside QML. Prefer argument arrays over interpolated shell commands.
- `settings.json` stores user-editable defaults. `Dashboard.qml` loads, clamps
  and writes those values.
- Runtime bitmap art lives in `config/quickshell/tenebris-shell/assets`.
- `install.sh` stages the repository into the user's configuration and records
  every replaced path. `uninstall.sh` must restore the same state.

The usual data path is:

```text
system/MPRIS/Hyprland → tenebris-state.py → Dashboard properties → component
component click       → helper script      → application/system command
```

## Example: add an application to the dock

The left dock is `ArchiveRail.qml`. Its full-art model starts near the middle
of the file. To add Obsidian, first create:

```text
config/quickshell/tenebris-shell/assets/rail_icon_obsidian.png
```

The file must be a centered `56×56` transparent PNG. Then append this object to
the full-art `Repeater` model:

```qml
{
    asset: "rail_icon_obsidian.png",
    label: "Notes",
    command: "uwsm app -- obsidian",
    active: false
}
```

Also add a readable fallback to the `cleanMode` column:

```qml
ArchiveButton {
    glyph: "󰂺"
    label: "Notes"
    onInvoked: root.commandRequested("uwsm app -- obsidian")
}
```

Use `omarchy launch <role>` when Omarchy already exposes a semantic launcher,
such as `omarchy launch browser` or `omarchy launch terminal`. Otherwise use
`uwsm app -- <executable>` so the application joins the desktop session
correctly. Verify the executable before adding it:

```bash
command -v obsidian
uwsm app -- obsidian
```

Dock command strings eventually pass through `sh -lc`; never place untrusted
metadata in them. Complex or dynamic behavior belongs in a Python helper that
receives an argument array.

Every full-art dock item consumes about 67 logical pixels. After adding an app,
check that the last item does not collide with the cross or wax seal at 720p.
If the rail outgrows the available height, convert the app group to a clipped
`ListView` rather than shrinking icons below their intended size.

## Add a Workbench action

Workbench actions are declared in `Dashboard.qml` and rendered by
`WorkbenchAction.qml`. Add a `48×48` transparent asset and a model entry:

```qml
{
    asset: "workbench_lazygit.png",
    label: "Open in Lazygit",
    action: "lazygit"
}
```

Handle the action in `project-action.py`. Keep project paths as individual
arguments; do not concatenate them into a command string. If an icon's visual
weight is asymmetric, use `iconOffsetX` or `iconOffsetY` in the model instead
of editing layout margins for every button.

## Add a panel or dashboard statistic

Use `ArchiveFrame` for a new region so corners, headers and panel opacity remain
consistent. Derive sizes from the available parent width and height and add a
compact branch when content cannot fit below 800 logical pixels.

For new system data:

1. Collect it in `tenebris-state.py` with a short timeout.
2. Add it to the single JSON result.
3. Add a typed property in `Dashboard.qml`.
4. Copy the value in `statePoll`'s JSON handler.
5. Render it with `TenebrisTheme.contentFont` and the existing type scale.

Do not add one repeating `Process` per row, icon or metric. Cache slow disk,
network and Git work; pause expensive polling while workspace 1 is hidden.

## Add a setting

An adjustable feature needs all four parts:

1. A default in `settings.json`.
2. A property and validated bounds in `Dashboard.qml`.
3. Persistence through the existing settings document and `saveSettings()`.
4. A control in the relevant settings overlay.

Preserve unknown keys when saving so upgrades do not erase settings introduced
by newer versions. Numerical values must be clamped before they affect shaders,
timers or geometry.

## Art direction

TENEBRIS is a monochrome dungeon interface, not a generic fantasy skin. New art
should feel like a physical object recovered from a ruined archive:

- medieval manuscript engraving, carved stone, wrought iron, tarnished silver,
  wax, scratched ink and dry parchment grain;
- narrow highlights, imperfect etched lines and restrained asymmetry;
- near-black mass with bone/silver edges;
- oxblood red only for active, dangerous or sealed states;
- a strong readable silhouette at the final on-screen size.

Avoid cartoon proportions, glossy mobile-game rendering, colored neon, soft
SaaS gradients, plastic 3D, bloom, large drop shadows, text baked into images
and rectangular backgrounds around icons.

The core palette is:

| Role | Color |
| --- | --- |
| Void | `#050505` |
| Surface | `#101010` |
| Bone | `#E1DBCF` |
| Silver | `#B8B2A7` |
| Border | `#66625B` |
| Oxblood | `#7C0E13` |
| Active blood | `#B51D24` |

### Generating a new image

Generate one isolated object, not a finished UI screenshot. Start larger than
the runtime target, keep a transparent background and downsample only after the
silhouette is correct. A useful image-generation prompt is:

```text
Single isolated [APP/OBJECT] glyph reinterpreted as a dark medieval dungeon
manuscript engraving, wrought iron and tarnished silver construction, dry
scratched ink texture, nearly monochrome bone-gray on transparent background,
one restrained oxblood accent, centered orthographic icon, strong readable
silhouette, 20 percent empty safe padding, handcrafted asymmetry, crisp edges,
no text, no frame, no rectangular background, no glow, no neon, no cartoon,
no glossy 3D, no mockup, no scenery.
```

Keep the application's recognizable silhouette, but translate its material and
line work into TENEBRIS. Do not paste a colored official logo into a gothic
frame.

After generation:

1. Remove stray pixels and confirm the alpha channel is genuinely transparent.
2. Center by visual mass, not merely by the source image's bounding box.
3. Leave enough safe padding for hover borders.
4. Downsample with a high-quality filter and inspect at 100% scale.
5. Compare beside every existing icon, both idle and hovered.

Useful target sizes:

| Asset | Runtime size |
| --- | ---: |
| Dock/rail icon | `56×56` transparent PNG |
| Workbench action | `48×48` transparent PNG |
| Frame corner | `64×64` transparent PNG |
| Workspace room | `192×190` PNG |
| Top-title ornament | `240×32` transparent PNG |
| Wallpaper | `1680×720` RGB PNG |

For a generated square icon, a typical mechanical finishing command is:

```bash
magick generated.png -trim -resize 44x44 -gravity center \
  -background none -extent 56x56 rail_icon_example.png
```

Inspect the result manually; `-trim` alone often centers shadows instead of the
actual emblem. Keep source sheets and rejected generations outside the public
repository. Commit only the final runtime PNG.

## Packages and installation

If a feature cannot work without a command, add the package to `core_packages`
and the executable to `required_commands` in `install.sh`. Optional applications
must remain optional, have an explicit installer choice and keep the desktop
functional when absent.

Any new deployed path requires:

- a first-install backup in `install.sh`;
- idempotent update behavior on repeated installs;
- matching restoration in `uninstall.sh`;
- a release assertion in `scripts/check.sh`.

Never install or replace Omarchy itself, never overwrite application
credentials and never restart SDDM from the installer.

## Release checklist

Run at minimum:

```bash
./scripts/check.sh
git diff --check
omarchy plugin validate config/omarchy/plugins/tenebris.menu
omarchy plugin validate config/omarchy/plugins/tenebris.lock
hyprctl configerrors
qs list --all
```

Then verify the feature on workspace 1, another normal workspace, 2560×1600,
1280×720 and one ultrawide layout. Check hover hitboxes, outside-click behavior,
keyboard escape paths, z-order, terminal stowing and idle CPU use. A feature is
not finished when it only looks correct in a static screenshot.
