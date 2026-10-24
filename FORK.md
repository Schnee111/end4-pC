# About this fork

`Schnee111/end4-pC` is a fork of [`pctrade/end4-pC`](https://github.com/pctrade/end4-pC),
itself derived from [`end-4/dots-hyprland`](https://github.com/end-4/dots-hyprland) (GPL-3.0).
It is the Quickshell configuration used by the `end4` rice of
[`Schnee111/dotfiles`](https://github.com/Schnee111/dotfiles), which installs it at
`~/.config/quickshell/end4-pC` and pins an exact commit in `lib/shells.sh` (`END4PC_REV`).

This file records what differs from upstream, why, and how to keep it in sync. It describes
the fork at upstream `cbe1aad`.

## Rules for changes here

1. A fix that anyone running upstream would want goes **upstream first** (issue + PR on
   `pctrade/end4-pC`); it only stays in the fork until it is merged there.
2. A change that only makes sense for this setup stays in the fork, kept small and listed
   below so the next sync does not have to rediscover it.
3. Anything that calls into the dotfiles is listed under "Host integration".

## Syncing with upstream

```bash
git fetch upstream
git switch -c chore/sync-upstream-<yyyy-mm> main
git merge upstream/main          # a merge commit, never a rebase
```

Open the PR and merge it with **"Create a merge commit"**. Squashing or rebasing drops the
upstream ancestry and every later sync conflicts again. Do not rewrite `main` after the fact:
the dotfiles pin a commit of it (`tests/network/check-pins.sh` in that repository fails if a
pin stops being on `main`).

Conflict policy used so far:

| Area | Resolution |
|---|---|
| Upstream rewrites of a feature (dock, scrolling, settings pages) | Take upstream, then re-port any fork patch that still matters |
| Update Dots (`services/DotsUpdater.qml`, `settings/pages/About.qml`) | **Fork wins**: upstream's action deletes this checkout and re-clones `pctrade/end4-pC` |
| Left sidebar (`panelFamilies/IllogicalImpulseFamily.qml`, `ScreenCorners.qml`) | **Fork wins**: disabled |
| MPRIS player choice (`services/MprisController.qml`) | Keep the playing player first, on top of upstream's `manualPlayer` |
| `MaterialSymbol.qml` font | Keep the "Material Symbols Rounded" fallback |

After merging, run `tests/check-syntax.sh`, reload the shell and read `qs -c end4-pC log`
for `is not a type`, `unavailable` and `TypeError` before opening the PR. Then bump `END4PC_REV` in the dotfiles.

## What differs from upstream

Status of the upstream PRs is as of this writing.

| Area | Files | Why | Upstream |
|---|---|---|---|
| Session workspace layout and autostart | `modules/common/widgets/SessionLayoutEditor.qml`, `AutostartApps.qml`, `modules/common/panels/lock/LockScreen.qml`, `modules/common/Config.qml` (`hyprland.sessionAutostart`) | Deterministic window placement and autostart after unlock; needs the dotfiles | Fork-only |
| Update Dots disabled | `services/DotsUpdater.qml`, `modules/ii/settings/pages/About.qml` | See the conflict policy | Fork-only |
| Left sidebar disabled | `panelFamilies/IllogicalImpulseFamily.qml`, `modules/ii/screenCorners/ScreenCorners.qml` | Not used | Fork-only |
| Terminal and theme application | `scripts/colors/applycolor.sh`, `scripts/colors/switchwall.sh`, `scripts/colors/generate_colors_material.py`, `scripts/colors/terminal/kitty-theme.conf`, `services/MaterialThemeLoader.qml`, `GlobalStates.qml`, `modules/common/models/quickToggles/DarkModeToggle.qml` | Atomic kitty theme file, no escape sequences broadcast to every `/dev/pts/*`, readable `term8`, ignore an empty colors file, `toggleLightDark` shortcut, hooks into the dotfiles | Kitty zoom part: pctrade/end4-pC#239; the rest fork-only |
| Media (MPRIS) | `services/MprisController.qml`, `modules/ii/mediaControls/MediaControls.qml`, `modules/ii/sidebarRight/SidebarRightContent.qml` | Ignore idle "ghost" players, prefer the playing one | `abs` and `playbackState` part: pctrade/end4-pC#237; the rest fork-only |
| Notifications | `services/Notifications.qml`, `modules/common/widgets/NotificationAppIcon.qml`, `modules/ii/notificationPopup/NotificationPopup.qml` | Timer guard, icon fallback, no popups over a fullscreen window | Timer guard: pctrade/end4-pC#238; the rest fork-only |
| Dock | `modules/common/widgets/DragApps.qml`, `modules/ii/dock/Dock.qml`, `DockActiveApps.qml`, `services/TaskbarApps.qml` | Hover preview for unpinned apps, preview clamped to the screen, `kitty-*` windows grouped | Hover preview: pctrade/end4-pC#232; the rest fork-only |
| Hyprland state, fullscreen and output filtering | `modules/common/models/WorkspaceModel.qml`, `services/HyprlandBackend.qml`, `HyprlandData.qml`, `HyprlandConfig.qml`, `modules/ii/background/Background.qml`, `modules/ii/bar/DiOsd.qml`, `SystemIcons.qml`, `modules/ii/onScreenDisplay/*`, `modules/ii/screenTranslator/ScreenTranslator.qml` | Read workspace and fullscreen state from live Hyprland data; ignore the `HEADLESS-*` / `FALLBACK-*` outputs created while the display sleeps | Fork-only (depends on the headless output the dotfiles create) |
| Thumbnails | `modules/common/widgets/ThumbnailImage.qml` | Fall back to the source image when a thumbnail fails | Concurrency and quoting fix: pctrade/end4-pC#240 |
| CI | `.github/workflows/check.yml`, `tests/check-syntax.sh` | Parse every QML/JS, shell and Python file and run the icon theme manager tests on each PR | Fork-only (upstream has no CI) |
| Misc | `services/Idle.qml` (`systemd-inhibit` for keep-awake), `services/AppSearch.qml` (osu pin), `modules/common/widgets/MaterialSymbol.qml` (font fallback) | Personal preferences | Fork-only |

## Host integration

The fork is only half of a setup. These are the places where it reaches into, or is reached
by, the dotfiles (`rices/end4/` in that repository).

### Fork calls the host

| Where | Calls | Guarded? |
|---|---|---|
| `LockScreen.qml` | `bash ~/.config/hypr/scripts/autostart.sh`, once per session after unlock, only if `hyprland.sessionAutostart` | yes (`test -f`) |
| `SessionLayoutEditor.qml` | reads and writes `~/.config/hypr/custom/session_layout.json`; runs `~/.config/hypr/scripts/layout_engine.py --capture` and `--run` | no |
| `scripts/colors/applycolor.sh` | `~/.config/hypr/scripts/restore_kitty_fonts.py`, in the background, output discarded; puts `~/.local/bin` on `PATH` | no |
| `scripts/colors/switchwall.sh` | `~/.config/hypr/scripts/apply_adaptive_glass.sh <wallpaper>`, in the background; puts `~/.local/bin` on `PATH` | no |
| `modules/common/Config.qml` | default `volumeMixer` runs `~/.config/hypr/hyprland/scripts/launch_first_available.sh` | no |

Without the dotfiles these fail quietly or log an error line; none of them blocks the shell.

### Host calls the fork

| Where (dotfiles) | Calls |
|---|---|
| `rices/end4/hypr/scripts/apply_adaptive_glass.sh`, `opacity_toggle.sh` | `python3 ~/.config/quickshell/end4-pC/scripts/hyprland/hyprconfigurator.py --file <main.lua> --set <key> <value>` |
| `rices/end4/hypr/{custom,hyprland}/variables.lua`, `rices/end4/hypr/scripts/monitor_watcher.py` | the install directory name: `qsConfig=end4-pC`, `qs -c end4-pC` |
| `lib/rices/end4.sh` | links `rices/end4/illogical-impulse/config.json` to `~/.config/illogical-impulse/config.json` (the shell's state file) and checks out the pinned commit |
| `lib/common.sh` (`kitty_theme_source`) | reads the generated `~/.local/state/quickshell/user/generated/terminal/kitty-theme.conf` |

If you rename the install directory or the `--set`/`--file` interface, update those files in
the dotfiles in the same change.
