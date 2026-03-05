# MCU 8051 IDE — macOS Port (v1.4.9-mt)

A maintained fork of [MCU 8051 IDE](http://mcu8051ide.sourceforge.net/) — an integrated development environment for MCS-51 based microcontrollers (8051 family). Written in Tcl/Tk.

This fork adds full **macOS support** as a self-contained `.app` bundle, along with a number of macOS-specific bug fixes accumulated during porting.

> **Status:** The macOS port is functional but not exhaustively tested. There are likely bugs in less-travelled code paths that have not yet been encountered. Testing, bug reports, and pull requests are welcome.

---

## Download

Pre-built universal binaries (Apple Silicon + Intel) are available on the [Releases](../../releases) page.

1. Download `MCU8051IDE-1.4.9.dmg` from the latest release
2. Open the DMG and drag **MCU8051IDE** to your Applications folder
3. On first launch, right-click → **Open** to bypass Gatekeeper

That's it — no Homebrew, no Tcl installation, no build steps required. SDCC must be installed separately if you want to compile C code: `brew install sdcc`

---

## macOS — Quick Start

### Prerequisites

- macOS 12 (Monterey) or later
- [Homebrew](https://brew.sh)
- SDCC (if you want to compile C code): `brew install sdcc`

### 1. Install dependencies (one time)

```bash
./macos_setup.sh
```

This installs Homebrew packages (`tcl-tk@8`, `bwidget`) and builds `itcl` and `tdom` from source into `macos_packages/` (gitignored). Takes a few minutes.

### 2. Build the app bundle

```bash
./build_app.sh
```

This produces `build/MCU8051IDE.app` — a fully self-contained bundle. No Tcl/Tk installation is required on the target machine. SDCC must be installed separately.

**Universal binary (arm64 + x86_64):** If you have Intel Homebrew installed under Rosetta 2, `macos_setup.sh` will build x86_64 versions of `itcl` and `tdom` automatically, and `build_app.sh` will detect them and produce a universal binary that runs natively on both Apple Silicon and Intel Macs. To install Intel Homebrew:

```bash
arch -x86_64 /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
arch -x86_64 /usr/local/bin/brew install tcl-tk@8
```

Then re-run `./macos_setup.sh` and `./build_app.sh`. Without Intel Homebrew, the bundle is arm64-only and Intel Macs must use Rosetta 2.

### 3. Install / run

Drag `build/MCU8051IDE.app` to `/Applications`, then right-click → **Open** on first launch (Gatekeeper bypass for ad-hoc signed apps).

---

## macOS — What Works

The following features have been tested and confirmed working on macOS in dark mode and light mode:

| Feature | Status |
|---|---|
| App launch, window management, menus | Working |
| Code editor (syntax highlighting, line numbers, icon border) | Working |
| macOS keyboard shortcuts (Cmd+C / Cmd+V / Cmd+X / Cmd+Z / Cmd+A) | Working |
| Project management (open, close, save, recent files) | Working |
| Simulator — step, step-over, run, animate, stop | Working |
| Simulator — breakpoints, SFR watch, stack monitor | Working |
| PALE virtual hardware — LED panel | Working |
| PALE virtual hardware — LED display, LED matrix | Working |
| PALE virtual hardware — Multiplexed LED display | Working |
| PALE virtual hardware — Matrix keypad, Simple keypad | Working |
| PALE virtual hardware — LCD HD44780 (4-bit and 8-bit) | Working |
| PALE virtual hardware — DS1620 temperature sensor | Working |
| Compiler integration — SDCC (C compiler) | Working |
| Compiler integration — ASEM-51, ASL assemblers | Working |
| Help menu — project page, bug report, SDCC manual, ASEM-51 manual | Working |
| Dark mode — all canvas labels and widget text visible | Working |
| Dock icon — static, correct icon throughout app lifetime | Working |
| Menu bar app name — shows "MCU8051IDE" (not "tclsh") | Working |
| User config stored in `~/.mcu8051ide/` (fresh for new users) | Working |

## macOS — Known Limitations

| Feature | Status |
|---|---|
| Embedded terminal panel (requires `urxvt`, X11-only) | Not available |
| Spell checker (requires `send` IPC, X11-only) | Disabled |
| "Aqua" widget style in preferences | Hidden (incompatible with app color scheme) |
| TclX / signal handling | Skipped (optional, app runs without it) |

---

## macOS — Changes from Upstream

### New files
- `macos_setup.sh` — one-time dependency installer
- `build_app.sh` — builds the self-contained `.app` bundle
- `run_macos.sh` — run directly from the repo without building the bundle
- `macos_stubs/img_png_stub/` — satisfies `package require img::png`; Tk 8.6 has native PNG support

### Bug fixes applied

**Event loop / AppKit**
- All bare `update` calls changed to `update idletasks` to prevent AppKit reentrancy — except the three simulation run-loop sites in `engine_control.tcl` which must use bare `update` to deliver Stop-button click events
- PALE `update idletasks` guarded by `sim_run_in_progress` to prevent thousands of Core Animation passes per second during fast simulation
- LCD HD44780 hot path fully guarded: `write_to_log`, `update_entry_boxes`, `adjust_status_leds`, DDRAM/CGRAM hex editor updates, canvas pixel ops all skip during `sim_run`
- LCD canvas refactored from 1280+ individual rectangle items to two `PhotoImage` objects with scratch-buffer/flush pattern, eliminating per-pixel `Tk_ImageChanged` callbacks
- LCD pre-warm: first compositor pass (≈7 s on first `update`) triggered during config load, not during simulation

**UI / display**
- All PALE canvas `create text` items given explicit `-fill #000000` — without this, dark mode renders text as invisible (white on white)
- `wm iconphoto` overridden on Darwin to prevent dialog icon calls from replacing the dock tile
- Dock icon uses full-resolution `mcu8051ide.png`; `aqua` ttk theme filtered from preferences
- `wm iconphoto .` guard replaced with a high-res icon setter; `wm iconphoto` shim blocks all subsequent calls on Darwin

**Input / keyboard**
- Explicit `<Command-Key-v/x/c/z/Z/a>` bindings added to the editor for macOS clipboard and undo/redo
- XF86/ISO keysym filter extended to Darwin

**Dialogs / grabs**
- `update idletasks` added before `grab` calls throughout (window must be mapped before grab succeeds on Aqua)
- `grab` and `focus -force` calls wrapped in `catch`

**OS integration**
- `open_uri` uses macOS `open` command instead of `xdg-open`
- SDCC manual URL updated to current PDF location
- `ps -o pid --no-headers --ppid` (GNU-only) replaced with `pkill -KILL -P` / `pgrep -P` on Darwin
- `aqua` widget theme blocked at startup if previously saved in config

**Build / packaging**
- C launcher (`MCU8051IDE` binary) calls `Tcl_Main()` directly — never `exec`'s — keeping `NSProcessInfo.processName` as "MCU8051IDE" for the menu bar and dock association

---

## Original Project

- **Author:** Martin Ošmera
- **Homepage:** http://mcu8051ide.sourceforge.net
- **License:** GPLv2 (see `LICENSE`)
- **Supports:** AT89S, AT89C, AT89X, AT89LP series; DS89C4x0; Intel MCS-51 and compatible
