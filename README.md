# Quickly

A small, fast, native macOS app launcher. No accounts, no cloud, no file
indexing, no extension store. Press a hotkey, type a few letters, hit return.

What it does:

- **Launch apps** from `/Applications`, `/System/Applications`, `~/Applications`
  and the usual system utility folders. Folders are watched, so new installs
  show up without a restart.
- **Open System Settings panes** directly: "disp" → Displays, "blue" → Bluetooth,
  "night shift" → Displays, "dark mode" → Appearance.
- **System commands**: Lock Screen, Sleep, Sleep Display, Empty Trash, Toggle
  Dark Mode, Log Out…, Restart…, Shut Down… (the last three use the normal
  macOS confirmation dialog).
- **Time zone conversion** as the one built-in extension: `3pm in tokyo`,
  `9:30am pst to ist`, `time in london`, `sf to berlin`. Return copies the result.
- Learns what you use: frequently and recently launched items rank first and
  show as suggestions when the field is empty.

## Install

**Download:** grab `Quickly-x.y.z.zip` from the
[latest release](https://github.com/naveen/quickly/releases/latest), unzip, and
drag `Quickly.app` to `/Applications`. The app is not notarized, so the first
time macOS will say it can't verify the developer: right-click the app, choose
Open, and confirm once. Or clear the flag from a terminal:

```sh
xattr -d com.apple.quarantine /Applications/Quickly.app
```

**Build from source:** requires Xcode command line tools (Swift 5.9+), macOS 13+.

```sh
make install     # builds, copies to /Applications, launches
```

Press **⌘ Space**. Spotlight owns that key by default; Quickly warns on launch
if it is still enabled and offers to open System Settings → Keyboard →
Keyboard Shortcuts → Spotlight, where you can turn off "Show Spotlight search".
Other targets: `make run` (build and launch from `build/`), `make test`,
`make dist` (zip for a GitHub release), `make uninstall`.

## Releases

Each release on the [Releases page](https://github.com/naveen/quickly/releases)
carries a zipped `Quickly.app` built by GitHub Actions from the tagged commit.
To cut one, bump `CFBundleShortVersionString` in `Support/Info.plist`, then:

```sh
git tag v0.2.0 && git push origin v0.2.0
```

## Keys

| Key | Action |
| --- | --- |
| ⌘ Space | Toggle Quickly |
| ↑ ↓ | Move selection |
| ↩ | Open selected item |
| ⌘ ↩ | Alternate action (apps: reveal in Finder) |
| ⌘ 1–9 | Open the nth result |
| Esc | Clear the query, then close |

## Configuration

Everything lives in `defaults`:

```sh
# Change the hotkey (restart Quickly after). Modifiers: cmd, option, ctrl, shift.
defaults write com.naveen.quickly hotkey "option+space"   # keep ⌘Space for Spotlight
defaults write com.naveen.quickly hotkey "ctrl+\`"

# Hide the menu bar icon (also toggleable from the menu).
defaults write com.naveen.quickly showMenuBarIcon -bool false
```

"Launch at Login" is in the menu bar menu. The app also answers URL commands,
handy from other tools: `open quickly://toggle`, `quickly://show`,
`quickly://hide`, `quickly://rescan`.

Usage history is a small JSON file at
`~/Library/Application Support/Quickly/usage.json`. Delete it to reset ranking.

## Layout

- `Sources/QuicklyCore` — Foundation-only logic: app scanning, fuzzy matching
  and ranking, usage history, the System Settings catalog, time zone parsing.
  Fully unit tested.
- `Sources/Quickly` — the AppKit app: floating panel, global hotkey (Carbon,
  no Accessibility permission needed), menu bar item, commands.
- `Support/` — `Info.plist` and the script that draws the app icon.

Adding an extension means implementing `QueryExtension` (one method: query in,
items out) and listing it in `LauncherController`.
