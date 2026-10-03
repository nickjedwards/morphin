# Morphin

A morphing-island shell for [Hyprland](https://hypr.land). It's morphin' time!

## Contents

- [Install](#install)
- [Start it with Hyprland](#start-it-with-hyprland)
- [Commands](#commands)
- [Keybinds](#keybinds)
- [Themes and wallpapers](#themes-and-wallpapers)
- [Settings](#settings)
- [IPC reference](#ipc-reference)
- [Development](#development)

## Install

The shell is plain QML; the one thing to compile is its binary, `morpher` (`morpher/`, in Rust, so building needs `cargo`). It is both the command you run and a small program the shell starts for itself (`morpher alpha`), which reads the process list and watches the backlights so the shell doesn't have to poll or start programs for them.

**Arch (AUR-style package):** `dist/arch/PKGBUILD` builds `morphin-git` from the repository:

```sh
cd dist/arch && makepkg -si
```

**Anywhere else, with make:**

```sh
make                         # build the binary (needs cargo)
sudo make install            # to /usr/local
make install PREFIX=~/.local # just for you (make sure ~/.local/bin is on PATH)
```

Either way you get:

| Installed | What it is |
|---|---|
| `bin/morpher` | the command: see [Commands](#commands) |
| `share/morphin/` | the shell itself |
| `lib/systemd/user/morphin.service` | optional autostart |
| `share/doc/morphin/`, `share/licenses/morphin/` | this README and the licence |

`make uninstall` (with the same `PREFIX`) removes it.

---

## Start it with Hyprland

Either start it from `~/.config/hypr/hyprland.lua`:

```lua
hl.exec_cmd("morpher its-morphin-time")
```

or, if your session starts `graphical-session.target` (for example under [uwsm](https://github.com/Vladimir-csp/uwsm)), let systemd run it, which also restarts it if it crashes:

```sh
systemctl --user enable --now morphin.service
```

Restart it without logging out:

```sh
morpher back-to-action
# or: systemctl --user restart morphin
```

---

## Commands

| Command | What it does |
|---|---|
| `morpher its-morphin-time` | start the shell, detached; does nothing if it's already running. `--stay` keeps it in the foreground |
| `morpher power-down` | stop it |
| `morpher back-to-action` | restart it |
| `morpher dinozord <target> <function> [argument]` | call the running shell: see the [IPC reference](#ipc-reference) |
| `morpher morphing-grid` | list everything `dinozord` can call |
| `morpher viewing-globe` | show the shell's log |
| `morpher roll-call` | list running instances |
| `morpher qs …` | run Quickshell itself on this shell, for anything not covered above |

Each is a [Quickshell](https://quickshell.org) command under another name, pointed at the installed shell. `morpher help` lists them.

---

## Keybinds

A set to start from, in Hyprland's Lua syntax:

```lua
local mainMod  = "SUPER"
local morphinTime = "morpher dinozord"

local morph = function(keys, cmd, opts)
    hl.bind(keys, hl.dsp.exec_cmd(morphinTime .. " " .. cmd), opts)
end

morph(mainMod .. " + Space",  "launcher toggle")             -- app launcher
morph(mainMod .. " + C",      "island toggle controlcenter") -- control center
morph(mainMod .. " + W",      "wallpaper toggle")            -- wallpaper picker
morph(mainMod .. " + T",      "theme toggle")                -- theme picker
morph(mainMod .. " + comma",  "settings toggle")             -- settings window
morph(mainMod .. " + L",      "lock lock")                   -- lock the session
morph(mainMod .. " + Escape", "power toggle")                -- power menu
morph(mainMod .. " + G",      "gamemode toggle")             -- Game mode

-- Hardware keys: these also show the level in the island.
local held = { locked = true, repeating = true }
morph("XF86AudioRaiseVolume",        "volume up",       held)
morph("XF86AudioLowerVolume",        "volume down",     held)
morph("XF86AudioMute",               "volume mute",     held)
morph("XF86MonBrightnessUp",         "brightness up",   held)
morph("XF86MonBrightnessDown",       "brightness down", held)
morph("XF86AudioPlay",               "media playPause", { locked = true })
morph("XF86AudioNext",               "media next",      { locked = true })
morph("XF86AudioPrev",               "media previous",  { locked = true })
morph(mainMod .. " + XF86AudioPlay", "media cycle") -- switch player
```

morphin has no lock screen of its own. Its Lock actions (the control-center button, the power menu, locking before suspend, and `lock lock`) ask the session to lock, so something has to be listening: for example [hypridle](https://wiki.hypr.land/Hypr-Ecosystem/hypridle/) with `lock_cmd = pidof hyprlock || hyprlock`.

---

## Themes and wallpapers

### Theme picker

Themes: ayu, catppuccin, cyberdream, dracula, embark, everforest, gruvbox, **gruvbox-material** (default), horizon, industrial, kanagawa, **material-you**, nightfox, nord, one-dark, rose-pine, solarized, tokyo-night, vesper.

**material-you** has no fixed colours; it takes them from the current wallpaper.

To add a theme, drop a JSON file in `~/.local/share/morphin/themes/` (`$XDG_DATA_HOME/morphin/themes/`). It shows up in the picker straight away, and a file using a built-in theme's id replaces that theme. A theme is a background, a foreground, an accent and six colours:

```json
{ "id": "my-theme", "bg": "#1a1b26", "fg": "#c0caf5", "accent": "#7aa2f7", "colors": ["#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff"] }
```

Every surface, text colour and highlight in the shell is derived from those.

### Wallpaper picker

1. By default: every image in the folder the current wallpaper is in.
2. Or a folder of your own: *Settings → Appearance → Wallpaper folder*.
3. If that folder has a **sub-folder named after the current theme** (for example `wallpapers/nord/`) with images in it, those are listed instead. That way each theme can bring its own set.

Each theme also **remembers the wallpaper last used with it** and switches back to it when you pick that theme again.

---

## Settings

Every change is saved immediately to `$XDG_CONFIG_HOME/morphin/config.json` (normally `~/.config/morphin/config.json`), which you can also edit by hand (the shell picks up edits live).

---

## IPC reference

All commands take the form `morpher dinozord <target> <function> [argument]`.

| Target | Functions |
|---|---|
| `island` | `toggle <panel>` (media, calendar, controlcenter, launcher, power, wallpapers, themes) · `page <name>` (wifi, bluetooth, audio, display, power, system) · `close` |
| `launcher` | `toggle` |
| `power` | `toggle` |
| `wallpaper` | `toggle` · `next` · `previous` · `set <path>` · `get` |
| `theme` | `toggle` · `set <name>` · `get` |
| `settings` | `toggle` · `open <page>` (island, clock, appearance, motion, launcher, notifications, controlcenter, system) |
| `lock` | `lock` (asks the session to lock: `loginctl lock-session`) |
| `volume` | `up` · `down` · `mute` |
| `brightness` | `up` · `down` (focused monitor) |
| `keyboard` | `up` · `down` · `toggle` · `get` (keyboard backlight) |
| `media` | `playPause` · `next` · `previous` · `cycle` · `cycleBack` · `players` (lists them; `*` marks the selected one) |
| `power-mode` | `set <saver\|balanced\|performance>` · `cycle` · `get` · `page` |
| `gamemode` | `toggle` |

list everything live:

```sh
morpher morphing-grid
```

---

## Files and directories

morphin follows the [XDG Base Directory spec](https://specifications.freedesktop.org/basedir-spec/latest/). Each location honours its variable and falls back to the default shown.

| What | Where | Notes |
|---|---|---|
| **Settings** | `$XDG_CONFIG_HOME/morphin/config.json` (`~/.config/…`) | everything in the settings window; edit by hand if you like, it reloads live |
| **Remembered state** | `$XDG_STATE_HOME/morphin/state.json` (`~/.local/state/…`) | the wallpaper last used with each theme; whether Focus and Night Light are on. Safe to delete. |
| **Your themes** | `$XDG_DATA_HOME/morphin/themes/*.json` (`~/.local/share/…`) | see [Themes](#themes-and-wallpapers) |
| **Cache** | `$XDG_CACHE_HOME/morphin/art/` (`~/.cache/…`) | cover art downloaded for colour sampling; keeps the 200 most recently used. Safe to delete. |
| **Runtime** | `$XDG_RUNTIME_DIR/morphin/` | files generated for this session (cava's config); private to you, gone at logout |
| **Wallpaper link** | `$XDG_CONFIG_HOME/wallpaper` | repointed when you change wallpaper, if it's a symlink, so hyprpaper and hyprlock follow |

---

## Development

Run `make` once, then run from the checkout with `qs -p quickshell` (the QML lives in `quickshell/`); Quickshell reloads it as you save.

The binary lives in `morpher/`; `make` builds it to `morpher/target/release/morpher`. Run from there it uses the checkout's QML, so `morpher/target/release/morpher dinozord …` works like the installed command. The shell needs it too: a shell run from the checkout starts it for itself (`morpher alpha`, from `common/Morpher.qml`; set `MORPHER` to point it at another binary), so run `make` before `qs -p quickshell`. The two speak lines of JSON on stdin/stdout; `morpher/src/main.rs` lists the messages. It isn't reloaded on save: restart the shell after rebuilding. `cargo test --manifest-path morpher/Cargo.toml` runs its tests.

`make check` installs a copy into `.check/` and starts it for a few seconds under a separate name and separate XDG folders. It fails if the configuration doesn't load, and shows the errors. It needs a running Wayland session, and a second island shows briefly while it runs. QML errors only show up when it's loaded, so run it before committing.
