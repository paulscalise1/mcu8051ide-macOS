# MCU 8051 IDE for macOS (v1.4.9-mt)

MCU 8051 IDE is an integrated development environment for microcontrollers of the MCS-51 (8051) family. Martin Ošmera wrote the original application in Tcl/Tk for Linux. This fork gives full macOS support. The application installs as one self-contained `.app` bundle. This fork also contains many macOS bug fixes.

**Status:** The macOS port is functional. Some functions do not have full tests. Please report bugs. Pull requests are welcome.

---

## Download and installation

### With Homebrew

```bash
brew install --cask paulscalise1/mcu8051ide/mcu8051ide
```

### Manual download

1. Open the [Releases](../../releases) page.
2. Download the DMG file from the latest release.
3. Open the DMG file.
4. Move **MCU8051IDE** to the Applications folder.

To compile C code, install SDCC:

```bash
brew install sdcc
```

---

## Build from source

### Prerequisites

- macOS 12 (Monterey) or later
- [Homebrew](https://brew.sh)

### Step 1 — Install the dependencies

```bash
./scripts/macos_setup.sh
```

This script installs the Homebrew packages `tcl-tk@8` and `bwidget`. It also compiles `itcl` and `tdom` from source into `macos_packages/`. This step is necessary one time only.

### Step 2 — Build the application bundle

```bash
./scripts/build_app.sh
```

This script makes `build/MCU8051IDE.app`. The bundle is self-contained. The target machine does not need Tcl/Tk. The target machine needs SDCC only for C compilation.

### Step 3 — Install the application

Move `build/MCU8051IDE.app` to the Applications folder.

### Universal binary

The build makes a universal binary (Apple Silicon and Intel) when Intel Homebrew is available. To install Intel Homebrew:

```bash
arch -x86_64 /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
arch -x86_64 /usr/local/bin/brew install tcl-tk@8
```

Then do Step 1 and Step 2 again. Without Intel Homebrew, the bundle is arm64 only. Intel Macs then use Rosetta 2.

### Run from the repository

```bash
./scripts/run_macos.sh
```

This command starts the application without a bundle. Use it for development.

---

## Functions with tests on macOS

These functions have manual tests on macOS, in light mode and in dark mode:

| Function | Status |
|---|---|
| Application start, windows, and menus | Correct |
| Code editor: syntax highlight, line numbers, icon border | Correct |
| Code editor: cursor keys, selection keys, word-jump keys | Correct |
| Keyboard shortcuts: Cmd+C, Cmd+V, Cmd+X, Cmd+Z, Cmd+A | Correct |
| Context menus with a right-click or a two-finger tap | Correct |
| Mouse wheel and trackpad scroll in all panels | Correct |
| Spell check with the macOS system dictionaries | Correct |
| Project management: open, close, save, recent files | Correct |
| Simulator: step, step over, run, animate, stop | Correct |
| Simulator: breakpoints, SFR watches, stack monitor | Correct |
| Syntax validation level button | Correct |
| Virtual hardware: LED panel, LED display, LED matrix | Correct |
| Virtual hardware: multiplexed LED display | Correct |
| Virtual hardware: matrix keypad, simple keypad | Correct |
| Virtual hardware: LCD HD44780, 4-bit and 8-bit | Correct |
| Virtual hardware: DS1620 temperature sensor | Correct |
| Compilers: SDCC, ASEM-51, ASL | Correct |
| Help menu and handbook | Correct |
| Dock icon and menu bar name | Correct |
| User configuration in `~/.mcu8051ide/` | Correct |

## Known limitations

- The embedded terminal panel is not available. The panel needs `urxvt` and X11 window embedding. macOS does not have X11 window embedding.
- The "Aqua" widget style is not available in the preferences. The style does not agree with the application colors.
- The application does not use TclX signal handlers. The application operates correctly without them.
- The "Run doxywizard" function needs the Doxywizard application from [doxygen.nl](https://www.doxygen.nl). The Homebrew `doxygen` package does not contain Doxywizard.

---

## Changes from the upstream project

### New files

- `scripts/macos_setup.sh` — installs the dependencies
- `scripts/build_app.sh` — builds the application bundle
- `scripts/run_macos.sh` — starts the application from the repository
- `macos_stubs/img_png_stub/` — replaces the `img::png` package; Tk 8.6 reads PNG natively
- `lib/editor/macos_native_spell.js` — connects the spell checker to the macOS spell service
- `macos_icon.png`, `mcu8051ide2.jpg` — application icon and icon source art

### Fixes for macOS

**Input**
- The right mouse button and the middle mouse button operate correctly. Tk on macOS gives these buttons different numbers than X11.
- The mouse wheel and the trackpad scroll all panels and lists.
- The cursor keys, the selection keys, and the word-jump keys operate in the editor and in the hex editor. Tk 8.6 moved these functions to virtual events.
- Shift+F3 and Shift+Tab operate. X11 keysyms translate to their macOS equivalents.
- The Command key mirrors all Control shortcuts.

**Spell check**
- The spell checker connects to the macOS system spell service through `osascript`. It operates without Hunspell. When Hunspell and dictionaries are installed, the application can use them also.

**Display**
- The event loop does not stall during fast simulation. All display updates in the simulation hot path stay away from the AppKit compositor.
- The LCD display and the CGRAM viewer show the dot grid of the original renderer.
- Notebook pages show immediately after a fast tab change.
- Dark mode shows all canvas text.
- The Dock shows one icon at all times. The icon comes from the bundle only.

**Simulator speed**
- The virtual hardware interface stops when no virtual hardware is open. This makes free-run simulation faster.
- Port state conversion uses a precomputed table.

**Operating system**
- URLs open with the macOS `open` command.
- The serial port list shows `/dev/cu.*` devices.
- The file dialog shows `/Volumes` for removable media.
- The Help menu item "MCU8051IDE Help" opens the handbook.
- Links to the expired `moravia-microsystems.com` domain point to the SourceForge project page now. The expired domain serves unsafe redirects.

### Removed files

This fork does not contain the Linux and Windows packaging files. The removed files include the freedesktop launcher, the AppStream metadata, the MIME registration, the CMake build files, and the `pkgs/` directory.

---

## The original project

- **Author:** Martin Ošmera
- **Homepage:** http://mcu8051ide.sourceforge.net
- **License:** GPLv2 — see `LICENSE`
- **Supported microcontrollers:** AT89S, AT89C, AT89X, and AT89LP series; DS89C4x0; Intel MCS-51 and compatible types
