#!/bin/bash
# Launcher for MCU8051 IDE on macOS.
# Run ./macos_setup.sh once before using this script.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect Homebrew prefix (Apple Silicon vs Intel)
if [ -d "/opt/homebrew" ]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

TCL_PREFIX="$BREW_PREFIX/opt/tcl-tk@8"
TCLSH="$TCL_PREFIX/bin/tclsh8.6"
PACKAGES_DIR="$SCRIPT_DIR/macos_packages"

if [ ! -x "$TCLSH" ]; then
    echo "Error: Tcl/Tk 8.6 not found at $TCLSH"
    echo "Please run:  ./macos_setup.sh"
    exit 1
fi

# ── Build TCLLIBPATH ──────────────────────────────────────────────────────────
# Tcl reads TCLLIBPATH as a list of directories to prepend to auto_path.
# We include each package directory explicitly so Tcl can find pkgIndex.tcl.

TCLLIBPATH_LIST=""

add_path() {
    local dir="$1"
    if [ -d "$dir" ]; then
        TCLLIBPATH_LIST="$TCLLIBPATH_LIST $dir"
    fi
}

# itcl4 needs ITCL_LIBRARY so its init code can find itcl.tcl at runtime.
# (package require Itcl 3.4 will fail with itcl4, but main.tcl's fallback
# on Tcl ≥ 8.6 retries with no version requirement, which succeeds.)
export ITCL_LIBRARY="$PACKAGES_DIR/itcl/lib/itcl4.3.6"

# BWidget (installed by Homebrew bwidget — pure Tcl scripts)
add_path "$BREW_PREFIX/share/bwidget"

# itcl4 (built from source against Tcl 8.6)
add_path "$PACKAGES_DIR/itcl/lib"

# tdom (built from source against Tcl 8.6)
add_path "$PACKAGES_DIR/tdom/lib"

# md5 from tcllib (pure Tcl)
add_path "$PACKAGES_DIR/tcllib/md5"

# img::png stub (Tk 8.6 has built-in PNG support)
add_path "$SCRIPT_DIR/macos_stubs/img_png_stub"

export TCLLIBPATH="$TCLLIBPATH_LIST"

# ── Launch ────────────────────────────────────────────────────────────────────
exec "$TCLSH" "$SCRIPT_DIR/lib/main.tcl" "$@"
