# AGENTS.md

This repository is the publishable source of truth for TENEBRIS, an Omarchy
Quattro (4.x) desktop rice. Keep it installable on a clean Omarchy user account
and keep the public repository free of machine-specific data.

## Repository map

- `config/quickshell/tenebris-shell/` — dashboard, top bar, player overlay,
  web screensaver, helpers and runtime raster assets
- `config/omarchy/themes/tenebris/` — Omarchy palette, wallpapers, lock assets
  and application theme fragments
- `config/omarchy/plugins/tenebris.menu/` — cloned Omarchy menu presentation;
  its public plugin ID is `tenebris.menu`
- `config/gtk-3.0/` and `config/gtk-4.0/` — snippets inserted between markers
- `hypr/tenebris/` — Lua snippets inserted into the user's Omarchy config
- `systemd/user/` — optional YMC and cliamp companions
- `docs/MARKETPLACE.md` — deferred Marketplace split and publication checklist
- `install.sh`, `uninstall.sh` — reversible user-level deployment
- `scripts/check.sh` — release validation

## Install and development workflow

Never edit `/usr/share/omarchy`. Do not treat files under `~/.config` as source;
they are deployed copies.

1. Edit files in this repository.
2. Run `./scripts/check.sh`.
3. Test locally with `./install.sh --skip-packages` from an active Omarchy
   session.
4. Check `hyprctl configerrors`; it must be empty.
5. Check Quickshell with `qs list --all` and, when needed,
   `qs log -p ~/.config/quickshell/tenebris-shell`.
6. Use `./uninstall.sh` to verify restoration before a release.

The normal user install is:

```bash
git clone https://github.com/executionreverted/tenebris-omarchy.git
cd tenebris-omarchy
./install.sh
```

## Installer contract

- Run only as the desktop user; never as root.
- Require exactly the Omarchy Quattro generation (4.x), verify its shell/plugin
  contract before writing anything, and install missing core packages through
  `omarchy pkg add` unless `--skip-packages` is supplied.
- Back up a path before replacing it. Repeated installs must preserve the
  original pre-TENEBRIS state.
- Modify shared Hyprland and GTK files only inside the existing TENEBRIS marker
  blocks.
- Preserve monitor, scale, refresh-rate, keyboard, input and locale config by
  default. The installer may write a reversible monitor block only after the
  user explicitly selects a supported resolution/refresh profile; it must
  preserve the output's current scale, position and transform.
- Treat `ymc`, `cliamp`, `spt`, `code` and `codex` as optional.
- Do not overwrite player credentials. `spotify-tui/client.yml` is never part
  of this repository.
- Never redistribute the Argor font. The installer may import a user-supplied
  `ArgFlahm.ttf` or `~/Downloads/argor_flahm_scaqh.zip`, must verify its font
  family, and must restore the previous target on uninstall.
- Uninstall must restore the previous theme, menu, stock-bar flag, files and
  service enable/active state. Installed system packages remain.

## Asset policy

Keep only raster files referenced at runtime. Do not commit concept sheets,
duplicate exports, caches, editor files or generated `__pycache__` content.
Before adding screenshots or video, inspect every frame for usernames, SSIDs,
IP addresses, private project names, notifications and tokens. Launch the shell
with `TENEBRIS_DEMO_MODE=1` for sanitized network, host and Workbench data.
Shader source and its compiled `.qsb` must stay together.

The optional Argor display font is not redistributable here. Preserve the Noto
and JetBrains Mono fallbacks. Public videos must redact live Workbench names,
SSIDs and IP addresses before entering `media/`.

## Required release checks

`./scripts/check.sh` must pass. It checks Bash, Lua, QML, Python, JSON, TOML,
plugin metadata, raster references and known private/legacy strings. Also test:

```bash
omarchy plugin validate config/omarchy/plugins/tenebris.menu
git status --short
```

Do not publish local state, credentials, album-art caches or files copied from
the user's home directory.
