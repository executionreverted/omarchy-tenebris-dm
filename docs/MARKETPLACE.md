# Omarchy Plugin Marketplace Follow-up

Recorded on 29 August 2026 for a later release pass.

TENEBRIS is currently a complete Omarchy rice, not a single Marketplace
plugin. Keep the full desktop in this repository and publish the menu as a
separate plugin repository when the rice release is stable.

References:

- [Develop a custom plugin](https://omarchyplugins.com/develop.html)
- [Publish your plugin](https://omarchyplugins.com/publish.html)
- [Official Omarchy shell reference](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md)

## Menu plugin release

Extract `config/omarchy/plugins/tenebris.menu/` into its own public GitHub
repository and complete this checklist:

- Put `manifest.json`, README, LICENSE and the QML entry points at the repository
  root. Add an optional optimized `preview.png`.
- Give the plugin a permanent namespaced ID, such as
  `io.github.executionreverted.tenebris-menu`.
- Remove the development-only `omarchy.clonedFrom` field.
- Replace the hard-coded `omarchy.menu` module name and IPC routes with the
  permanent plugin ID.
- Add `"license": "MIT"` to the manifest and preserve the upstream Omarchy
  copyright notice for code derived from the built-in menu.
- Document every dependency, command, service, privilege boundary and asset
  license.
- Run `omarchy plugin validate`, `qmllint`, and manual open, close, Escape,
  disable, enable, shell-restart and removal tests.
- Submit the public repository URL, category and tags through the Marketplace
  issue form after validation passes on the current commit.

## Full desktop limitation

Marketplace plugins run inside Omarchy's one long-running Quickshell process.
They must not launch a second `qs -p` process, and the plugin installer does not
run package installers, hooks or privileged commands. The current dashboard,
theme, Hyprland snippets and optional player services therefore remain part of
the full-rice installer.

Moving the entire experience into the Marketplace later requires splitting it
into native `bar`, `menu`, `overlay` and possibly `service` plugin entry points.
