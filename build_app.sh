#!/bin/bash
# build_app.sh — Build a self-contained MCU8051IDE.app bundle for macOS.
#
# Run from the repo root:  ./build_app.sh
#
# Prerequisites (installed by macos_setup.sh):
#   - Homebrew tcl-tk@8
#   - Homebrew bwidget
#   - macos_packages/itcl/  (itcl 4.3.6 built from source)
#   - macos_packages/tdom/  (tdom built from source vs Tcl 8.6)
#   - macos_packages/tcllib/md5/
#   - macos_stubs/img_png_stub/
#
# The resulting app bundles all dependencies except SDCC.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
APP_NAME="MCU8051IDE"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
LIB_DIR="${CONTENTS}/lib"
RESOURCES_DIR="${CONTENTS}/Resources"
APP_RES="${RESOURCES_DIR}/app"   # where lib/ data/ icons/ translations/ go

# ── Detect Homebrew prefix ────────────────────────────────────────────────────
if [ -d "/opt/homebrew" ]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

TCL_PREFIX="${BREW_PREFIX}/opt/tcl-tk@8"

# ── Detect Intel (x86_64) Homebrew (for universal binary) ─────────────────────
INTEL_TCL_PREFIX=""
INTEL_TCL_INCLUDE=""
INTEL_ITCL_DYLIB=""
INTEL_TDOM_DYLIB=""
BUILD_UNIVERSAL=false

if [ "${BREW_PREFIX}" != "/usr/local" ] && [ -x "/usr/local/bin/brew" ]; then
    _intel_tcl="/usr/local/opt/tcl-tk@8"
    # Use glob — x86_64 and arm64 builds may produce different version numbers
    _intel_itcl_dylib=$(ls "${SCRIPT_DIR}/macos_packages/itcl_x86_64/lib/itcl"*/libitcl*.dylib 2>/dev/null | head -1)
    _intel_tdom_dylib=$(ls "${SCRIPT_DIR}/macos_packages/tdom_x86_64/lib/tdom"*/libtdom*.dylib 2>/dev/null | head -1)
    _intel_inc=""
    for _d in "${_intel_tcl}/include" "${_intel_tcl}/include/tcl-tk"; do
        [ -f "${_d}/tcl.h" ] && _intel_inc="${_d}" && break
    done
    if [ -d "${_intel_tcl}/lib" ] && [ -n "${_intel_inc}" ] && \
       [ -n "${_intel_itcl_dylib}" ] && \
       [ -n "${_intel_tdom_dylib}" ]; then
        BUILD_UNIVERSAL=true
        INTEL_TCL_PREFIX="${_intel_tcl}"
        INTEL_TCL_INCLUDE="${_intel_inc}"
        INTEL_ITCL_DYLIB="${_intel_itcl_dylib}"
        INTEL_TDOM_DYLIB="${_intel_tdom_dylib}"
    fi
fi

# ── Verify prerequisites ──────────────────────────────────────────────────────
check() {
    if [ ! -e "$1" ]; then
        echo "ERROR: Missing: $1"
        echo "       Run ./macos_setup.sh first."
        exit 1
    fi
}
check "${TCL_PREFIX}/bin/tclsh8.6"
check "${TCL_PREFIX}/lib/libtcl8.6.dylib"
check "${TCL_PREFIX}/lib/libtk8.6.dylib"
# Headers may be in include/ or include/tcl-tk/ depending on Homebrew version
TCL_INCLUDE=""
for d in "${TCL_PREFIX}/include" "${TCL_PREFIX}/include/tcl-tk"; do
    [ -f "${d}/tcl.h" ] && TCL_INCLUDE="${d}" && break
done
if [ -z "${TCL_INCLUDE}" ]; then
    echo "ERROR: tcl.h not found under ${TCL_PREFIX}/include"
    echo "       Run ./macos_setup.sh first."
    exit 1
fi
# Find arm64 itcl/tdom package dirs and dylibs (version-agnostic)
ITCL_ARM64_PKG=$(ls -d "${SCRIPT_DIR}/macos_packages/itcl/lib/itcl"*/ 2>/dev/null | head -1)
if [ -z "${ITCL_ARM64_PKG}" ]; then
    echo "ERROR: Missing: macos_packages/itcl/lib/itcl*/"
    echo "       Run ./macos_setup.sh first."
    exit 1
fi
ITCL_ARM64_DYLIB=$(ls "${ITCL_ARM64_PKG}"libitcl*.dylib 2>/dev/null | head -1)
if [ -z "${ITCL_ARM64_DYLIB}" ]; then
    echo "ERROR: libitcl*.dylib not found in ${ITCL_ARM64_PKG}"
    echo "       Run ./macos_setup.sh first."
    exit 1
fi
TDOM_ARM64_PKG=$(ls -d "${SCRIPT_DIR}/macos_packages/tdom/lib/tdom"*/ 2>/dev/null | head -1)
if [ -z "${TDOM_ARM64_PKG}" ]; then
    echo "ERROR: Missing: macos_packages/tdom/lib/tdom*/"
    echo "       Run ./macos_setup.sh first."
    exit 1
fi
TDOM_ARM64_DYLIB=$(ls "${TDOM_ARM64_PKG}"libtdom*.dylib 2>/dev/null | head -1)
if [ -z "${TDOM_ARM64_DYLIB}" ]; then
    echo "ERROR: libtdom*.dylib not found in ${TDOM_ARM64_PKG}"
    echo "       Run ./macos_setup.sh first."
    exit 1
fi
check "${SCRIPT_DIR}/macos_packages/tcllib/md5/pkgIndex.tcl"
check "${SCRIPT_DIR}/macos_stubs/img_png_stub/pkgIndex.tcl"

BWIDGET_PKGINDEX=$(find "${BREW_PREFIX}/Cellar/bwidget" -maxdepth 4 \
    -name "pkgIndex.tcl" 2>/dev/null | head -1)
BWIDGET_DIR=""
if [ -n "${BWIDGET_PKGINDEX}" ]; then
    BWIDGET_DIR="$(dirname "${BWIDGET_PKGINDEX}")"
fi
if [ -z "${BWIDGET_DIR}" ] || [ ! -d "${BWIDGET_DIR}" ]; then
    echo "ERROR: BWidget not found under ${BREW_PREFIX}/Cellar/bwidget"
    echo "       Run:  brew install bwidget"
    exit 1
fi

# ── Report build mode ─────────────────────────────────────────────────────────
if [ "${BUILD_UNIVERSAL}" = true ]; then
    echo "==> Build mode: universal (arm64 + x86_64)"
else
    echo "==> Build mode: arm64 only"
    if [ "${BREW_PREFIX}" != "/usr/local" ] && [ -x "/usr/local/bin/brew" ]; then
        echo "    (Intel x86_64 packages not found — run macos_setup.sh for universal build)"
    else
        echo "    (Intel Homebrew not found — Intel Macs will use Rosetta 2)"
    fi
fi
echo ""

# ── Create directory structure ────────────────────────────────────────────────
echo "==> Cleaning build directory"
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${LIB_DIR}" "${APP_RES}"

# ── Compile C launcher ────────────────────────────────────────────────────────
# A compiled binary named MCU8051IDE ensures:
#   • NSProcessInfo.processName == "MCU8051IDE" (menu bar app name)
#   • macOS correctly associates the process with the bundle (dock icon)
# It calls Tcl_Main() directly and never exec's another process.
echo "==> Compiling C launcher"

LAUNCHER_C="${BUILD_DIR}/launcher.c"
mkdir -p "${BUILD_DIR}"

cat > "${LAUNCHER_C}" << 'C_SOURCE'
/*
 * MCU8051IDE launcher — compiled binary that:
 *   1. Derives bundle paths from its own executable path
 *   2. Sets TCL_LIBRARY, TK_LIBRARY, ITCL_LIBRARY, TCLLIBPATH env vars
 *   3. Prepends main.tcl as argv[1] and strips LaunchServices -psn_* args
 *   4. Calls Tcl_Main() — never exec's — so the process stays named
 *      "MCU8051IDE" for the duration of the app's lifetime
 */
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <mach-o/dyld.h>
#include <tcl.h>

static int AppInit(Tcl_Interp *interp) {
    if (Tcl_Init(interp) == TCL_ERROR) return TCL_ERROR;
    return TCL_OK;
}

int main(int argc, char *argv[]) {
    /* --- resolve our own executable path --- */
    char exe[4096];
    uint32_t sz = (uint32_t)sizeof(exe);
    if (_NSGetExecutablePath(exe, &sz) != 0) {
        fprintf(stderr, "MCU8051IDE: _NSGetExecutablePath failed\n");
        return 1;
    }
    char real[4096];
    if (!realpath(exe, real)) {
        strncpy(real, exe, sizeof(real) - 1);
    }

    /*
     * real is: .../MCU8051IDE.app/Contents/MacOS/MCU8051IDE
     * Strip filename + "MacOS" to get the Contents directory.
     */
    char contents[4096];
    strncpy(contents, real, sizeof(contents) - 1);
    char *slash = strrchr(contents, '/');
    if (slash) *slash = '\0';   /* remove "MCU8051IDE" */
    slash = strrchr(contents, '/');
    if (slash) *slash = '\0';   /* remove "MacOS"      */

    /* --- build per-bundle paths --- */
    char lib_dir[4096], tcl_lib[4096], tk_lib[4096];
    char itcl_lib[4096], main_tcl[4096], resources[4096];

    snprintf(lib_dir,   sizeof(lib_dir),   "%s/lib",                        contents);
    snprintf(tcl_lib,   sizeof(tcl_lib),   "%s/lib/tcl8.6",                 contents);
    snprintf(tk_lib,    sizeof(tk_lib),    "%s/lib/tk8.6",                  contents);
    snprintf(itcl_lib,  sizeof(itcl_lib),  "%s/lib/itcl4.3.6",              contents);
    snprintf(main_tcl,  sizeof(main_tcl),  "%s/Resources/app/lib/main.tcl", contents);
    snprintf(resources, sizeof(resources), "%s/Resources",                  contents);

    /* --- publish env vars before Tcl initialises --- */
    setenv("TCL_LIBRARY",          tcl_lib,   1);
    setenv("TK_LIBRARY",           tk_lib,    1);
    setenv("ITCL_LIBRARY",         itcl_lib,  1);
    setenv("TCLLIBPATH",           lib_dir,   1);
    /* MCU8051IDE_RESOURCES lets Tcl find bundled assets (e.g. dock icon PNG) */
    setenv("MCU8051IDE_RESOURCES", resources, 1);

    /*
     * macOS .app bundles launch with a minimal PATH (/usr/bin:/bin:/usr/sbin:/sbin).
     * The user's shell profile (~/.zshrc etc.) is never sourced, so tools installed
     * by Homebrew or MacPorts are invisible.  Prepend the standard locations so that
     * sdcc, asem, asl, make, etc. can be found without requiring the user to set
     * PATH manually.
     */
    {
        const char *cur_path = getenv("PATH");
        if (!cur_path) cur_path = "";
        char new_path[8192];
        snprintf(new_path, sizeof(new_path),
            "/opt/homebrew/bin:/opt/homebrew/sbin"
            ":/usr/local/bin:/usr/local/sbin"
            ":/opt/local/bin:/opt/local/sbin"
            ":%s",
            cur_path);
        setenv("PATH", new_path, 1);
    }

    /*
     * Build a new argv:
     *   argv[0]  = original argv[0]  (process name — already "MCU8051IDE")
     *   argv[1]  = path to main.tcl  (Tcl_Main uses argv[1] as the script)
     *   argv[2+] = pass-through user args, dropping any "-psn_*" inserted
     *              by LaunchServices when the app is double-clicked
     */
    char **nargv = (char **)malloc((size_t)(argc + 2) * sizeof(char *));
    if (!nargv) { fprintf(stderr, "MCU8051IDE: malloc failed\n"); return 1; }

    int nargc = 0;
    nargv[nargc++] = argv[0];
    nargv[nargc++] = main_tcl;
    for (int i = 1; i < argc; i++) {
        if (strncmp(argv[i], "-psn_", 5) != 0)
            nargv[nargc++] = argv[i];
    }
    nargv[nargc] = NULL;

    Tcl_Main(nargc, nargv, AppInit);
    return 0;
}
C_SOURCE

# Compile against the bundled Tcl headers and link the shared libtcl
if [ "${BUILD_UNIVERSAL}" = true ]; then
    # ── arm64 slice ───────────────────────────────────────────────────────────
    clang -arch arm64 \
        -I"${TCL_INCLUDE}" \
        -o "${BUILD_DIR}/launcher_arm64" \
        "${LAUNCHER_C}" \
        "${TCL_PREFIX}/lib/libtcl8.6.dylib" \
        -framework CoreFoundation
    _ref=$(otool -L "${BUILD_DIR}/launcher_arm64" \
        | awk '/libtcl8\.6\.dylib/{print $1}' | head -1)
    [ -z "${_ref}" ] && echo "ERROR: libtcl8.6.dylib ref not found (arm64)" && exit 1
    install_name_tool -change "${_ref}" \
        "@executable_path/../lib/libtcl8.6.dylib" "${BUILD_DIR}/launcher_arm64"

    # ── x86_64 slice ─────────────────────────────────────────────────────────
    clang -arch x86_64 \
        -I"${INTEL_TCL_INCLUDE}" \
        -o "${BUILD_DIR}/launcher_x86_64" \
        "${LAUNCHER_C}" \
        "${INTEL_TCL_PREFIX}/lib/libtcl8.6.dylib" \
        -framework CoreFoundation
    _ref=$(otool -L "${BUILD_DIR}/launcher_x86_64" \
        | awk '/libtcl8\.6\.dylib/{print $1}' | head -1)
    [ -z "${_ref}" ] && echo "ERROR: libtcl8.6.dylib ref not found (x86_64)" && exit 1
    install_name_tool -change "${_ref}" \
        "@executable_path/../lib/libtcl8.6.dylib" "${BUILD_DIR}/launcher_x86_64"

    # ── Merge into universal binary ───────────────────────────────────────────
    lipo -create "${BUILD_DIR}/launcher_arm64" "${BUILD_DIR}/launcher_x86_64" \
        -output "${MACOS_DIR}/MCU8051IDE"
else
    clang \
        -I"${TCL_INCLUDE}" \
        -o "${MACOS_DIR}/MCU8051IDE" \
        "${LAUNCHER_C}" \
        "${TCL_PREFIX}/lib/libtcl8.6.dylib" \
        -framework CoreFoundation

    # Repath the embedded libtcl reference so it finds the bundled copy
    LIBTCL_REF=$(otool -L "${MACOS_DIR}/MCU8051IDE" \
        | awk '/libtcl8\.6\.dylib/{print $1}' | head -1)
    if [ -z "${LIBTCL_REF}" ]; then
        echo "ERROR: Could not find libtcl8.6.dylib reference in compiled launcher"
        exit 1
    fi
    install_name_tool \
        -change "${LIBTCL_REF}" \
        "@executable_path/../lib/libtcl8.6.dylib" \
        "${MACOS_DIR}/MCU8051IDE"
fi

chmod +x "${MACOS_DIR}/MCU8051IDE"

# ── Copy dylibs ───────────────────────────────────────────────────────────────
echo "==> Copying dylibs"
if [ "${BUILD_UNIVERSAL}" = true ]; then
    lipo -create \
        "${TCL_PREFIX}/lib/libtcl8.6.dylib" \
        "${INTEL_TCL_PREFIX}/lib/libtcl8.6.dylib" \
        -output "${LIB_DIR}/libtcl8.6.dylib"
    # Tk's pkgIndex.tcl does: load [file join $dir .. libtk8.6.dylib]
    # so libtk8.6.dylib must sit one level up from tk8.6/, i.e. in LIB_DIR.
    lipo -create \
        "${TCL_PREFIX}/lib/libtk8.6.dylib" \
        "${INTEL_TCL_PREFIX}/lib/libtk8.6.dylib" \
        -output "${LIB_DIR}/libtk8.6.dylib"
else
    cp "${TCL_PREFIX}/lib/libtcl8.6.dylib" "${LIB_DIR}/"
    # Tk's pkgIndex.tcl does: load [file join $dir .. libtk8.6.dylib]
    # so libtk8.6.dylib must sit one level up from tk8.6/, i.e. in LIB_DIR.
    cp "${TCL_PREFIX}/lib/libtk8.6.dylib" "${LIB_DIR}/"
fi

# ── Copy Tcl/Tk standard library files ───────────────────────────────────────
echo "==> Copying Tcl/Tk standard libraries"
cp -R "${TCL_PREFIX}/lib/tcl8.6" "${LIB_DIR}/"
cp -R "${TCL_PREFIX}/lib/tcl8"   "${LIB_DIR}/"
cp -R "${TCL_PREFIX}/lib/tk8.6"  "${LIB_DIR}/"

# ── Copy Tcl packages ─────────────────────────────────────────────────────────
echo "==> Copying BWidget"
cp -R "${BWIDGET_DIR}" "${LIB_DIR}/bwidget"

echo "==> Copying Itcl"
cp -R "${ITCL_ARM64_PKG%/}" "${LIB_DIR}/"
if [ "${BUILD_UNIVERSAL}" = true ]; then
    _itcl_pkg=$(basename "${ITCL_ARM64_PKG%/}")
    _itcl_dylib=$(basename "${ITCL_ARM64_DYLIB}")
    lipo -create \
        "${ITCL_ARM64_DYLIB}" \
        "${INTEL_ITCL_DYLIB}" \
        -output "${LIB_DIR}/${_itcl_pkg}/${_itcl_dylib}"
fi

echo "==> Copying tdom"
cp -R "${TDOM_ARM64_PKG%/}" "${LIB_DIR}/"
if [ "${BUILD_UNIVERSAL}" = true ]; then
    _tdom_pkg=$(basename "${TDOM_ARM64_PKG%/}")
    _tdom_dylib=$(basename "${TDOM_ARM64_DYLIB}")
    lipo -create \
        "${TDOM_ARM64_DYLIB}" \
        "${INTEL_TDOM_DYLIB}" \
        -output "${LIB_DIR}/${_tdom_pkg}/${_tdom_dylib}"
fi

echo "==> Copying md5"
cp -R "${SCRIPT_DIR}/macos_packages/tcllib/md5" "${LIB_DIR}/"

echo "==> Copying img::png stub"
cp -R "${SCRIPT_DIR}/macos_stubs/img_png_stub" "${LIB_DIR}/"

# ── Copy app source ───────────────────────────────────────────────────────────
echo "==> Copying app source"
cp -R "${SCRIPT_DIR}/lib"         "${APP_RES}/"
cp -R "${SCRIPT_DIR}/data"        "${APP_RES}/"
cp -R "${SCRIPT_DIR}/icons"       "${APP_RES}/"
cp -R "${SCRIPT_DIR}/doc"         "${APP_RES}/"
[ -d "${SCRIPT_DIR}/translations" ] && cp -R "${SCRIPT_DIR}/translations" "${APP_RES}/"

# ── Create Info.plist ─────────────────────────────────────────────────────────
echo "==> Creating Info.plist"
cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MCU8051IDE</string>
    <key>CFBundleIdentifier</key>
    <string>com.mcu8051ide.app</string>
    <key>CFBundleName</key>
    <string>MCU8051IDE</string>
    <key>CFBundleDisplayName</key>
    <string>MCU 8051 IDE</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.4.9</string>
    <key>CFBundleShortVersionString</key>
    <string>1.4.9</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2007-2014 Martin Ošmera. GPLv2.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
PLIST

# ── Build app icon (.icns) ────────────────────────────────────────────────────
echo "==> Building app icon"
# Always use the square app icon from the repo root for the .icns
ICON_SRC="${SCRIPT_DIR}/mcu8051ide.png"
# Fallback to splash if root icon is somehow missing
[ -f "${ICON_SRC}" ] || ICON_SRC="${SCRIPT_DIR}/icons/other/splash.png"

# Copy the icon PNG into Resources so the Tcl code can load it for wm iconphoto
if [ -f "${SCRIPT_DIR}/mcu8051ide.png" ]; then
    cp "${SCRIPT_DIR}/mcu8051ide.png" "${RESOURCES_DIR}/mcu8051ide.png"
fi

if [ -f "${ICON_SRC}" ]; then
    ICONSET_DIR="${BUILD_DIR}/MCU8051IDE.iconset"
    mkdir -p "${ICONSET_DIR}"
    for SIZE in 16 32 64 128 256 512; do
        sips -z $SIZE $SIZE "${ICON_SRC}" \
            --out "${ICONSET_DIR}/icon_${SIZE}x${SIZE}.png" \
            > /dev/null 2>&1
        DOUBLE=$((SIZE * 2))
        sips -z $DOUBLE $DOUBLE "${ICON_SRC}" \
            --out "${ICONSET_DIR}/icon_${SIZE}x${SIZE}@2x.png" \
            > /dev/null 2>&1
    done
    iconutil -c icns -o "${RESOURCES_DIR}/MCU8051IDE.icns" "${ICONSET_DIR}"
    rm -rf "${ICONSET_DIR}"

    # Add icon reference to Info.plist
    /usr/libexec/PlistBuddy \
        -c "Add :CFBundleIconFile string MCU8051IDE" \
        "${CONTENTS}/Info.plist" 2>/dev/null || true
else
    echo "    (no source icon found — skipping)"
fi

# ── Ad-hoc code sign ─────────────────────────────────────────────────────────
echo "==> Code signing (ad-hoc)"
codesign --sign - --force --options runtime "${MACOS_DIR}/MCU8051IDE" 2>/dev/null || \
codesign --sign - --force "${MACOS_DIR}/MCU8051IDE"
# Sign the whole bundle
codesign --sign - --force --deep "${APP_BUNDLE}" 2>/dev/null || \
codesign --sign - --force --deep "${APP_BUNDLE}" 2>&1 | grep -v "replacing existing"

echo ""
if [ "${BUILD_UNIVERSAL}" = true ]; then
    echo "✓ Built (universal arm64 + x86_64): ${APP_BUNDLE}"
else
    echo "✓ Built (arm64 only; Intel Macs must use Rosetta 2): ${APP_BUNDLE}"
fi
echo ""
echo "To install: drag MCU8051IDE.app from build/ to /Applications"
echo "First launch: right-click → Open (Gatekeeper bypass for unsigned app)"
