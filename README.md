# Morphin

It's morphin' time!

A dynamic-island shell for [Hyprland](https://hypr.land), built on [Quickshell](https://quickshell.org).

## Contents

- [Prerequisites](#prerequisites)
- [Install](#install)
- [Start it with Hyprland](#start-it-with-hyprland)
- [Keybinds](#keybinds)
- [Themes and wallpapers](#themes-and-wallpapers)
- [Settings](#settings)
- [IPC reference](#ipc-reference)
- [Development](#development)

---

## Prerequisites

**Required**

| Package | Why |
|---|---|
| `hyprland` (0.56+, Lua config) | compositor; the shell uses Hyprland IPC and `hyprctl eval` |
| `hyprpaper` | draws the wallpaper (morphin falls back to drawing it itself) |
| `hyprsunset` | Night Light |
| `quickshell` (0.3.1+) | the runtime |
| `qt6-declarative`, `qt6-imageformats` | QML and effects (blur); webp and other image formats |
| `ttf-nerd-fonts-symbols` | icons (Symbols Nerd Font) |
| `networkmanager` | Wi-Fi page |
| `bluez`, `bluez-utils` | Bluetooth page |
| `pipewire`, `wireplumber` | Audio control and page, and volume |
| `upower` | Battery ring |
| `brightnessctl` | built-in display brightness |
| `power-profiles-daemon` | Power Mode (Power Saver / Balanced / Performance) |
| any MPRIS player | the media card and album art |
| `cava` | the audio pulse around the album art |
| `curl` | colour sampling for players that serve art over https (Spotify) |

On Arch:

```sh
paru -S quickshell \
    hyprland hyprpaper hyprsunset \
    qt6-declarative qt6-imageformats \
    ttf-nerd-fonts-symbols \
    networkmanager \
    bluez bluez-utils \
    pipewire wireplumber \
    upower power-profiles-daemon \
    brightnessctl \
    cava \
    curl
```

---

## Install

It's plain QML, so there's nothing to compile: installing copies the files and sets up a launcher.

**Arch (AUR-style package):** `dist/arch/PKGBUILD` builds `morphin-git` from the repository:

```sh
cd dist/arch && makepkg -si
```

**Anywhere else, with make:**

```sh
sudo make install            # to /usr/local
make install PREFIX=~/.local # just for you (make sure ~/.local/bin is on PATH)
```

Either way you get:

| Installed | What it is |
|---|---|
| `bin/morphin` | the launcher: `morphin`, `morphin -d`, `morphin ipc call …`, `morphin kill`, `morphin log` |
| `share/morphin/` | the shell itself |
| `lib/systemd/user/morphin.service` | optional autostart |
| `share/doc/morphin/`, `share/licenses/morphin/` | this README and the licence |

`make uninstall` (with the same `PREFIX`) removes it.

---

## Start it with Hyprland

Either start it from `~/.config/hypr/hyprland.lua`:

```lua
hl.exec_cmd("morphin -d")
```

or, if your session starts `graphical-session.target` (for example under [uwsm](https://github.com/Vladimir-csp/uwsm)), let systemd run it, which also restarts it if it crashes:

```sh
systemctl --user enable --now morphin.service
```

Restart it without logging out:

```sh
morphin kill; morphin -d
# or: systemctl --user restart morphin
```

---

## Keybinds

A set to start from, in Hyprland's Lua syntax:

```lua
local mainMod  = "SUPER" -- Sets "Windows" key as main modifier
local morphinTime = "morphin ipc call"
local bind = function(keys, cmd, opts) hl.bind(keys, hl.dsp.exec_cmd(morphinTime .. " " .. cmd), opts) end

bind(mainMod .. " + Space",  "launcher toggle")             -- app launcher
bind(mainMod .. " + C",      "island toggle controlcenter") -- control center
bind(mainMod .. " + W",      "wallpaper toggle")            -- wallpaper picker
bind(mainMod .. " + T",      "theme toggle")                -- theme picker
bind(mainMod .. " + comma",  "settings toggle")             -- settings window
bind(mainMod .. " + L",      "lock lock")                   -- lock screen
bind(mainMod .. " + Escape", "power toggle")                -- power menu
bind(mainMod .. " + G",      "gamemode toggle")             -- Game mode

-- Hardware keys: these also show the level in the island.
local held = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume",        "volume up",       held)
bind("XF86AudioLowerVolume",        "volume down",     held)
bind("XF86AudioMute",               "volume mute",     held)
bind("XF86MonBrightnessUp",         "brightness up",   held)
bind("XF86MonBrightnessDown",       "brightness down", held)
bind("XF86AudioPlay",               "media playPause", { locked = true })
bind("XF86AudioNext",               "media next",      { locked = true })
bind("XF86AudioPrev",               "media previous",  { locked = true })
bind(mainMod .. " + XF86AudioPlay", "media cycle") -- switch player
```

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

All commands take the form `morphin ipc call <target> <function> [argument]`.

| Target | Functions |
|---|---|
| `island` | `toggle <panel>` (media, calendar, controlcenter, launcher, power, wallpapers, themes) · `page <name>` (wifi, bluetooth, audio, display, power, system) · `close` |
| `launcher` | `toggle` |
| `power` | `toggle` |
| `wallpaper` | `toggle` · `next` · `previous` · `set <path>` · `get` |
| `theme` | `toggle` · `set <name>` · `get` |
| `settings` | `toggle` · `open <page>` (island, clock, appearance, motion, launcher, notifications, controlcenter, lock, system) |
| `lock` | `lock` |
| `lockscreen` | `preview` |
| `volume` | `up` · `down` · `mute` |
| `brightness` | `up` · `down` (focused monitor) |
| `keyboard` | `up` · `down` · `toggle` · `get` (keyboard backlight) |
| `media` | `playPause` · `next` · `previous` · `cycle` · `cycleBack` · `players` (lists them; `*` marks the selected one) |
| `power-mode` | `set <saver\|balanced\|performance>` · `cycle` · `get` · `page` |
| `gamemode` | `toggle` |

list everything live:

```sh
morphin ipc show
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

Run from the checkout with `qs -p quickshell` (the QML lives in `quickshell/`); Quickshell reloads it as you save.

`make check` installs a copy into `.check/` and starts it for a few seconds under a separate name and separate XDG folders. It fails if the configuration doesn't load, and shows the errors. It needs a running Wayland session, and a second island shows briefly while it runs. QML errors only show up when it's loaded, so run it before committing.
