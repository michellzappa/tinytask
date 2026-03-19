# TinyTask

A minimal, fast task manager for macOS.

![macOS](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Plain-text tasks** — one task per line, stored as `.md`, `.txt`, or `.todo` files
- **Sections** — organize tasks with headers
- **Checkbox toggle** — click or press Space to complete tasks
- **Drag & drop reorder** — move tasks with the mouse or keyboard
- **Auto-save** — saves as you type
- **Multiple windows** — each window has independent state
- **Font size control** — Cmd+/Cmd- to adjust, Cmd+0 to reset
- **Light & dark mode** — follows system appearance
- **Status bar** — task count and completion stats
- **Open from Finder** — double-click task files to open in TinyTask

## Requirements

- macOS 26.0+
- Xcode 26+ (to build)

## Build

```bash
xcodebuild clean build \
  -project TinyTask.xcodeproj \
  -scheme TinyTask \
  -configuration Release \
  -derivedDataPath /tmp/tinybuild/tinytask \
  CODE_SIGN_IDENTITY="-"

cp -R /tmp/tinybuild/tinytask/Build/Products/Release/TinyTask.app /Applications/
```

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+N | New file |
| Cmd+O | Open file |
| Cmd+S | Save |
| Cmd+Return | New task |
| Cmd+Shift+Return | New section |
| Cmd+Up/Down | Move task up/down |
| Cmd+Backspace | Delete task |
| Space | Toggle complete |
| Cmd+F | Find |
| Cmd+= / Cmd+- | Font size |
| Cmd+0 | Reset font size |

## Tech

Built with SwiftUI and TinyKit.

## License

MIT
