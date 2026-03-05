#!/bin/bash
# macOS setup script for MCU8051 IDE
# Run once to install all required dependencies.
#
# Requirements:
#   - Homebrew (https://brew.sh)
#   - Xcode Command Line Tools (xcode-select --install)
#   - git
#
# For a universal (arm64 + x86_64) build, also install Intel Homebrew under
# Rosetta 2 before running this script:
#
#   arch -x86_64 /bin/bash -c \
#     "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#   arch -x86_64 /usr/local/bin/brew install tcl-tk@8
#
# Then re-run this script.  If Intel Homebrew is not present, only an arm64
# bundle is built and Intel Macs must use Rosetta 2 to run it.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/macos_packages"

# ── Detect native (arm64) Homebrew prefix ─────────────────────────────────────
if [ -d "/opt/homebrew" ]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi
TCL_PREFIX="$BREW_PREFIX/opt/tcl-tk@8"

# ── Detect Intel (x86_64) Homebrew prefix ─────────────────────────────────────
INTEL_BREW=""
INTEL_TCL_PREFIX=""
if [ "$BREW_PREFIX" != "/usr/local" ] && [ -x "/usr/local/bin/brew" ]; then
    INTEL_BREW="/usr/local/bin/brew"
    INTEL_TCL_PREFIX="/usr/local/opt/tcl-tk@8"
fi

# macOS 26 Clang defaults to C23, which rejects old K&R function definitions
# as errors.  Force C17 and suppress the deprecation warning so tdom and itcl
# compile cleanly.
BASE_CFLAGS="-std=c17 -Wno-deprecated-non-prototype"
export CFLAGS="${CFLAGS:-} ${BASE_CFLAGS}"

echo "=== MCU8051 IDE — macOS Setup ==="
echo "Native Homebrew : $BREW_PREFIX"
if [ -n "$INTEL_BREW" ]; then
    echo "Intel  Homebrew : /usr/local  (universal build available)"
else
    echo "Intel  Homebrew : not found   (arm64 only; Intel Macs use Rosetta 2)"
fi
echo "Packages dir    : $PACKAGES_DIR"
echo ""

# ── Step 1: Tcl/Tk 8.6 (native) ──────────────────────────────────────────────
echo "Step 1: Installing Tcl/Tk 8.6 (tcl-tk@8)..."
if brew list tcl-tk@8 &>/dev/null; then
    echo "  Already installed."
else
    brew install tcl-tk@8
fi

TCLSH="$TCL_PREFIX/bin/tclsh8.6"
if [ ! -x "$TCLSH" ]; then
    echo "ERROR: tclsh8.6 not found at $TCLSH after install."
    exit 1
fi
echo "  tclsh8.6: $TCLSH"

# ── Step 2: BWidget (pure Tcl — architecture-independent) ────────────────────
echo ""
echo "Step 2: Installing BWidget..."
if brew list bwidget &>/dev/null; then
    echo "  Already installed."
else
    brew install bwidget
fi

# ── Step 3: itcl4 — native build ─────────────────────────────────────────────
echo ""
echo "Step 3: Building itcl4 against Tcl 8.6 (native)..."

ITCL_INSTALL_DIR="$PACKAGES_DIR/itcl"
ITCL_LIB_DIR="$ITCL_INSTALL_DIR/lib"
ITCL_BUILD_DIR="/tmp/mcu8051ide_itcl_build"

_build_itcl() {
    local build_dir="$1"
    local install_dir="$2"
    local tcl_lib_dir="$3"
    local arch_cflags="$4"

    mkdir -p "$build_dir"

    if [ ! -d "$build_dir/itcl/.git" ] || [ ! -f "$build_dir/itcl/tclconfig/install-sh" ]; then
        rm -rf "$build_dir/itcl"
        echo "  Cloning itcl..."
        git clone --recurse-submodules https://github.com/tcltk/itcl.git "$build_dir/itcl"
    fi

    cd "$build_dir/itcl"

    # Clean any previous build artifacts before reconfiguring for a different arch
    make distclean 2>/dev/null || true

    echo "  Configuring..."
    CFLAGS="${BASE_CFLAGS} ${arch_cflags}" ./configure \
        --with-tcl="$tcl_lib_dir" \
        --prefix="$install_dir" \
        --exec-prefix="$install_dir"

    echo "  Building..."
    CFLAGS="${BASE_CFLAGS} ${arch_cflags}" make -j"$(sysctl -n hw.ncpu)"

    mkdir -p ./tclconfig
    printf '#!/bin/sh\nexec /usr/bin/install "$@"\n' > ./tclconfig/install-sh
    chmod +x ./tclconfig/install-sh

    echo "  Installing to $install_dir..."
    make install

    cd "$SCRIPT_DIR"
}

if ls "$ITCL_LIB_DIR"/itcl*/pkgIndex.tcl 2>/dev/null | head -1 | grep -q pkgIndex; then
    echo "  Already built."
else
    _build_itcl "$ITCL_BUILD_DIR" "$ITCL_INSTALL_DIR" "$TCL_PREFIX/lib" ""
    echo "  itcl4 (native) built successfully."
fi

# ── Step 4: tdom — native build ───────────────────────────────────────────────
echo ""
echo "Step 4: Building tdom against Tcl 8.6 (native)..."

TDOM_INSTALL_DIR="$PACKAGES_DIR/tdom"
TDOM_LIB_DIR="$TDOM_INSTALL_DIR/lib"
TDOM_BUILD_DIR="/tmp/mcu8051ide_tdom_build"

_build_tdom() {
    local build_dir="$1"
    local install_dir="$2"
    local tcl_lib_dir="$3"
    local arch_cflags="$4"

    mkdir -p "$build_dir"

    if [ ! -d "$build_dir/tdom/.git" ] || [ ! -f "$build_dir/tdom/tclconfig/install-sh" ]; then
        rm -rf "$build_dir/tdom"
        echo "  Cloning tdom..."
        git clone --recurse-submodules https://github.com/tdom/tdom.git "$build_dir/tdom"
    fi

    cd "$build_dir/tdom"

    make distclean 2>/dev/null || true

    echo "  Configuring..."
    CFLAGS="${BASE_CFLAGS} ${arch_cflags}" ./configure \
        --with-tcl="$tcl_lib_dir" \
        --prefix="$install_dir" \
        --exec-prefix="$install_dir" \
        --enable-shared

    if grep -q '#ifdef _POSIX_SOURCE' ./generic/tclexpat.c; then
        echo "  Patching tclexpat.c (_POSIX_SOURCE guard)..."
        sed -i '' \
            -e 's|#ifdef _POSIX_SOURCE|#ifndef _MSC_VER /* patched: was _POSIX_SOURCE */|' \
            ./generic/tclexpat.c
    fi

    echo "  Building..."
    CFLAGS="${BASE_CFLAGS} ${arch_cflags}" make -j"$(sysctl -n hw.ncpu)"

    mkdir -p ./tclconfig
    printf '#!/bin/sh\nexec /usr/bin/install "$@"\n' > ./tclconfig/install-sh
    chmod +x ./tclconfig/install-sh

    echo "  Installing to $install_dir..."
    make install

    cd "$SCRIPT_DIR"
}

if ls "$TDOM_LIB_DIR"/tdom*/pkgIndex.tcl 2>/dev/null | head -1 | grep -q pkgIndex; then
    echo "  Already built."
else
    _build_tdom "$TDOM_BUILD_DIR" "$TDOM_INSTALL_DIR" "$TCL_PREFIX/lib" ""
    echo "  tdom (native) built successfully."
fi

# ── Step 5: x86_64 builds for universal binary (optional) ────────────────────
echo ""
if [ -n "$INTEL_BREW" ] && [ -d "$INTEL_TCL_PREFIX/lib" ]; then
    echo "Step 5: Building itcl4 and tdom for x86_64 (universal binary)..."

    ITCL_X86_INSTALL_DIR="$PACKAGES_DIR/itcl_x86_64"
    TDOM_X86_INSTALL_DIR="$PACKAGES_DIR/tdom_x86_64"
    ITCL_X86_BUILD_DIR="/tmp/mcu8051ide_itcl_x86_64_build"
    TDOM_X86_BUILD_DIR="/tmp/mcu8051ide_tdom_x86_64_build"

    ITCL_X86_LIB_DIR="$ITCL_X86_INSTALL_DIR/lib"
    TDOM_X86_LIB_DIR="$TDOM_X86_INSTALL_DIR/lib"

    if ls "$ITCL_X86_LIB_DIR"/itcl*/pkgIndex.tcl 2>/dev/null | head -1 | grep -q pkgIndex; then
        echo "  itcl4 x86_64: already built."
    else
        echo "  Building itcl4 for x86_64..."
        arch -x86_64 bash -c "
            export BASE_CFLAGS='${BASE_CFLAGS}'
            SCRIPT_DIR='${SCRIPT_DIR}'
            $(declare -f _build_itcl)
            _build_itcl '${ITCL_X86_BUILD_DIR}' '${ITCL_X86_INSTALL_DIR}' \
                '${INTEL_TCL_PREFIX}/lib' '-arch x86_64'
        "
        echo "  itcl4 x86_64 built successfully."
    fi

    if ls "$TDOM_X86_LIB_DIR"/tdom*/pkgIndex.tcl 2>/dev/null | head -1 | grep -q pkgIndex; then
        echo "  tdom x86_64: already built."
    else
        echo "  Building tdom for x86_64..."
        arch -x86_64 bash -c "
            export BASE_CFLAGS='${BASE_CFLAGS}'
            SCRIPT_DIR='${SCRIPT_DIR}'
            $(declare -f _build_tdom)
            _build_tdom '${TDOM_X86_BUILD_DIR}' '${TDOM_X86_INSTALL_DIR}' \
                '${INTEL_TCL_PREFIX}/lib' '-arch x86_64'
        "
        echo "  tdom x86_64 built successfully."
    fi
else
    echo "Step 5: Skipping x86_64 builds (Intel Homebrew not found)."
    echo "  To enable universal builds, install Intel Homebrew under Rosetta 2:"
    echo "    arch -x86_64 /bin/bash -c \\"
    echo "      \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo "    arch -x86_64 /usr/local/bin/brew install tcl-tk@8"
    echo "  Then re-run this script."
fi

# ── Step 6: md5 module from tcllib (pure Tcl) ─────────────────────────────────
echo ""
echo "Step 6: Installing md5 (tcllib module)..."

MD5_DIR="$PACKAGES_DIR/tcllib/md5"

if [ -f "$MD5_DIR/pkgIndex.tcl" ]; then
    echo "  Already installed."
else
    TCLLIB_BUILD_DIR="/tmp/mcu8051ide_tcllib_build"
    mkdir -p "$TCLLIB_BUILD_DIR"

    if [ ! -d "$TCLLIB_BUILD_DIR/tcllib/.git" ]; then
        echo "  Cloning tcllib..."
        git clone --depth 1 https://github.com/tcltk/tcllib.git "$TCLLIB_BUILD_DIR/tcllib"
    fi

    mkdir -p "$MD5_DIR"
    cp "$TCLLIB_BUILD_DIR/tcllib/modules/md5/md5.tcl"      "$MD5_DIR/"
    cp "$TCLLIB_BUILD_DIR/tcllib/modules/md5/md5x.tcl"     "$MD5_DIR/"
    cp "$TCLLIB_BUILD_DIR/tcllib/modules/md5/pkgIndex.tcl"  "$MD5_DIR/"
    echo "  md5 installed to $MD5_DIR"
fi

# ── Step 7: Verify ────────────────────────────────────────────────────────────
echo ""
echo "Step 7: Verifying packages..."

BWIDGET_DIR="$BREW_PREFIX/share/bwidget"

ITCL_LIBRARY="$ITCL_LIB_DIR/itcl4.3.6" "$TCLSH" << TCLEOF
set failures {}
proc try_pkg {name ver extra_paths} {
    global failures
    foreach p \$extra_paths { lappend ::auto_path \$p }
    set req [expr {\$ver eq "" ? \$name : "\$name \$ver"}]
    if {[catch {package require {*}[split \$req]} v]} {
        lappend failures \$req
        puts "  MISSING : \$req"
    } else {
        puts "  OK      : \$name \$v"
    }
}

try_pkg Tk      8.6  {}
try_pkg Itcl    ""   {$ITCL_LIB_DIR}
try_pkg BWidget 1.8  {$BWIDGET_DIR}
try_pkg tdom    0.8  {$TDOM_LIB_DIR}
try_pkg md5     2.0  {$MD5_DIR}

if {[llength \$failures]} {
    puts "\nSome packages are missing — see above."
    exit 1
} else {
    puts "\nAll required packages found."
}
TCLEOF

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== Setup complete ==="
echo "Launch the IDE with:  ./run_macos.sh"
echo "Build the .app with:  ./build_app.sh"
