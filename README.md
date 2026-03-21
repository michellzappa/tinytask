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
- **On-device AI** — Cmd+K to ask questions about your tasks (CoreML, fully offline)
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
| Cmd+K | AI assistant |
| Cmd+F | Find |
| Cmd+= / Cmd+- | Font size |
| Cmd+0 | Reset font size |

## Tech

Built with SwiftUI and TinyKit.

## Part of [TinySuite](https://tinysuite.app)

Native macOS micro-tools that each do one thing well.

| App | What it does |
|-----|-------------|
| [TinyMark](https://github.com/michellzappa/tinymark) | Markdown editor with live preview |
| **TinyTask** | Plain-text task manager |
| [TinyJSON](https://github.com/michellzappa/tinyjson) | JSON viewer with collapsible tree |
| [TinyCSV](https://github.com/michellzappa/tinycsv) | Lightweight CSV/TSV table viewer |
| [TinyPDF](https://github.com/michellzappa/tinypdf) | PDF text extractor with OCR |
| [TinyLog](https://github.com/michellzappa/tinylog) | Log viewer with level filtering |
| [TinySQL](https://github.com/michellzappa/tinysql) | Native PostgreSQL browser |

## License

MIT
