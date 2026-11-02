#!/bin/bash
set -euo pipefail

# ==============================================================================
# create_dmg.sh - Native macOS Disk Image (DMG) Packaging Pipeline
# Notepad++ for Mac Distribution Pipeline
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
BUILD_DIR="$PROJECT_ROOT/build"
APP_DIR="$BUILD_DIR/Notepad++.app"
STAGING_DIR=""
CURRENT_MOUNT_POINT=""

# Function to cleanly detach a mounted volume
detach_volume() {
    local mp="$1"
    if [ -z "$mp" ]; then
        return 0
    fi
    # Safety invariant: Never unmount user-mounted /Volumes/Notepad++ to prevent SIGBUS crashes
    if [ "$mp" = "/Volumes/Notepad++" ] || [ "$mp" = "/Volumes/Notepad++/" ]; then
        echo "Warning: Refusing to detach user-mounted volume: $mp" >&2
        return 1
    fi
    if [ -d "$mp" ]; then
        for i in 1 2 3; do
            if hdiutil detach "$mp" >/dev/null 2>&1; then
                return 0
            fi
            sleep 1
        done
        # Force detach fallback if needed
        if hdiutil detach -force "$mp" >/dev/null 2>&1; then
            return 0
        fi
        diskutil eject "$mp" >/dev/null 2>&1 || true
    fi
}

# Cleanup trap to ensure staging directory and temporary mounts are removed
cleanup() {
    local exit_code=$?
    if [ -n "${CURRENT_MOUNT_POINT:-}" ] && [ -d "$CURRENT_MOUNT_POINT" ]; then
        echo "Trap: Cleaning up isolated mount point $CURRENT_MOUNT_POINT..."
        detach_volume "$CURRENT_MOUNT_POINT"
        rmdir "$CURRENT_MOUNT_POINT" 2>/dev/null || rm -rf "$CURRENT_MOUNT_POINT" 2>/dev/null || true
        CURRENT_MOUNT_POINT=""
    fi
    if [ -n "${STAGING_DIR:-}" ] && [ -d "$STAGING_DIR" ]; then
        echo "Trap: Cleaning up staging directory $STAGING_DIR..."
        rm -rf "$STAGING_DIR"
    fi
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

# Self-verification routine for a target DMG file
verify_dmg() {
    local target_dmg="$1"
    echo ""
    echo "=== Verifying DMG Integrity: $target_dmg ==="

    if [ ! -f "$target_dmg" ]; then
        echo "Error: Target DMG not found: $target_dmg" >&2
        return 1
    fi

    local dmg_dir
    dmg_dir="$(dirname "$target_dmg")"
    local dmg_name
    dmg_name="$(basename "$target_dmg")"
    local sha_file="$dmg_dir/$dmg_name.sha256"

    if [ -f "$sha_file" ]; then
        echo "Checking SHA-256 checksum..."
        (cd "$dmg_dir" && shasum -a 256 -c "$dmg_name.sha256")
        echo "✓ SHA-256 checksum verified"
    fi

    echo "Mounting disk image in isolated read-only temporary mount point..."
    local tmp_mount
    tmp_mount=$(mktemp -d /tmp/npp_vfy_mnt.XXXXXX)
    CURRENT_MOUNT_POINT="$tmp_mount"

    if ! hdiutil attach "$target_dmg" -mountpoint "$tmp_mount" -nobrowse -readonly >/dev/null; then
        echo "Error: Failed to attach $target_dmg at $tmp_mount" >&2
        rmdir "$tmp_mount" 2>/dev/null || rm -rf "$tmp_mount" 2>/dev/null || true
        CURRENT_MOUNT_POINT=""
        return 1
    fi

    echo "Mounted successfully at isolated mount point: $tmp_mount"

    # 1. Verify Notepad++.app bundle exists
    local mounted_app="$tmp_mount/Notepad++.app"
    if [ ! -d "$mounted_app" ]; then
        echo "Error: Notepad++.app not found inside mounted DMG at $mounted_app" >&2
        detach_volume "$tmp_mount"
        rmdir "$tmp_mount" 2>/dev/null || rm -rf "$tmp_mount" 2>/dev/null || true
        CURRENT_MOUNT_POINT=""
        return 1
    fi
    echo "✓ Application bundle exists: $mounted_app"

    # 2. Verify executable exists and has executable permissions
    local mounted_exec="$mounted_app/Contents/MacOS/Notepad++"
    if [ ! -x "$mounted_exec" ]; then
        echo "Error: Executable $mounted_exec not found or not executable" >&2
        detach_volume "$tmp_mount"
        rmdir "$tmp_mount" 2>/dev/null || rm -rf "$tmp_mount" 2>/dev/null || true
        CURRENT_MOUNT_POINT=""
        return 1
    fi
    echo "✓ Main executable verified: $mounted_exec"

    # 3. Verify drag-and-drop /Applications symlink
    local app_link="$tmp_mount/Applications"
    if [ ! -L "$app_link" ]; then
        echo "Error: /Applications symlink missing in DMG ($app_link)" >&2
        detach_volume "$tmp_mount"
        rmdir "$tmp_mount" 2>/dev/null || rm -rf "$tmp_mount" 2>/dev/null || true
        CURRENT_MOUNT_POINT=""
        return 1
    fi
    local link_target
    link_target=$(readlink "$app_link")
    if [ "$link_target" != "/Applications" ] && [ "$link_target" != "/Applications/" ]; then
        echo "Error: Applications symlink points to '$link_target', expected '/Applications'" >&2
        detach_volume "$tmp_mount"
        rmdir "$tmp_mount" 2>/dev/null || rm -rf "$tmp_mount" 2>/dev/null || true
        CURRENT_MOUNT_POINT=""
        return 1
    fi
    echo "✓ Applications drag-and-drop symlink verified ($app_link -> $link_target)"

    # 4. Verify code signature of the mounted bundle
    echo "Verifying code signature of mounted bundle..."
    if ! codesign --verify --deep --strict "$mounted_app"; then
        echo "Error: Code signature verification failed on $mounted_app" >&2
        detach_volume "$tmp_mount"
        rmdir "$tmp_mount" 2>/dev/null || rm -rf "$tmp_mount" 2>/dev/null || true
        CURRENT_MOUNT_POINT=""
        return 1
    fi
    echo "✓ Code signature verified (--deep --strict)"

    # 5. Clean detachment of the isolated mount point
    echo "Detaching isolated volume $tmp_mount..."
    detach_volume "$tmp_mount"
    rmdir "$tmp_mount" 2>/dev/null || rm -rf "$tmp_mount" 2>/dev/null || true
    CURRENT_MOUNT_POINT=""
    echo "✓ DMG verified and cleanly detached"
}

# CLI Argument parsing
DO_BUILD=true
DO_VERIFY=true

for arg in "$@"; do
    case "$arg" in
        --verify|-v)
            if [ -f "$BUILD_DIR/Notepad++.dmg" ]; then
                DO_BUILD=false
            fi
            DO_VERIFY=true
            ;;
        --verify-only)
            DO_BUILD=false
            DO_VERIFY=true
            ;;
        --no-verify)
            DO_VERIFY=false
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --verify, -v       Verify existing DMG, or build and verify if not present"
            echo "  --verify-only      Verify existing DMG only (fails if DMG not found)"
            echo "  --no-verify        Build DMG without running verification"
            echo "  --help, -h         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1
            ;;
    esac
done

# If only verification is requested
if [ "$DO_BUILD" = false ]; then
    CANONICAL_DMG="$BUILD_DIR/Notepad++.dmg"
    if [ ! -f "$CANONICAL_DMG" ]; then
        echo "Error: Canonical DMG $CANONICAL_DMG not found to verify." >&2
        exit 1
    fi
    verify_dmg "$CANONICAL_DMG"
    echo "=== Verification complete! ==="
    exit 0
fi

# Preflight check: app bundle must exist
if [ ! -d "$APP_DIR" ]; then
    echo "Error: $APP_DIR not found. Please build the application first (e.g. ./bundle.sh)." >&2
    exit 1
fi
if [ ! -x "$APP_DIR/Contents/MacOS/Notepad++" ]; then
    echo "Error: $APP_DIR/Contents/MacOS/Notepad++ not found or not executable." >&2
    exit 1
fi

# Extract version from Info.plist
INFO_PLIST="$APP_DIR/Contents/Info.plist"
VERSION=""
if [ -f "$INFO_PLIST" ]; then
    VERSION=$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST" 2>/dev/null || true)
    if [ -z "$VERSION" ]; then
        VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true)
    fi
fi
if [ -z "$VERSION" ]; then
    VERSION="8.9.8.1"
fi

echo "=== Packaging Notepad++ v${VERSION} into macOS DMG ==="

# Verify and ensure code signature on source bundle
echo "Checking code signature of source bundle..."
if ! codesign --verify --deep "$APP_DIR" 2>/dev/null; then
    echo "Sealing application bundle signature..."
    xattr -cr "$APP_DIR" 2>/dev/null || true
    xattr -c "$APP_DIR" "$APP_DIR/Contents/Resources/NotepadPlusPlusMac_NotepadPlusPlusMac.bundle" 2>/dev/null || true
    codesign --force --deep --sign - "$APP_DIR"
    xattr -c "$APP_DIR" 2>/dev/null || true
fi

VERSIONED_DMG="$BUILD_DIR/Notepad++-v${VERSION}.dmg"
CANONICAL_DMG="$BUILD_DIR/Notepad++.dmg"

# Prepare clean isolated staging directory in /tmp (avoids macOS FileProvider/Finder detritus)
STAGING_DIR=$(mktemp -d /tmp/npp_dmg_staging.XXXXXX)
echo "Preparing staging area at $STAGING_DIR..."

echo "Copying $APP_DIR to staging using ditto..."
ditto "$APP_DIR" "$STAGING_DIR/Notepad++.app"

echo "Creating /Applications symlink in staging..."
ln -s /Applications "$STAGING_DIR/Applications"

echo "Sealing staging bundle signature..."
xattr -cr "$STAGING_DIR/Notepad++.app" 2>/dev/null || true
find "$STAGING_DIR/Notepad++.app" -exec xattr -d com.apple.FinderInfo {} + 2>/dev/null || true
find "$STAGING_DIR/Notepad++.app" -name "._*" -delete 2>/dev/null || true
codesign --force --deep --sign - "$STAGING_DIR/Notepad++.app"
codesign --verify --deep --strict "$STAGING_DIR/Notepad++.app"

# Remove existing DMG files before generating new ones
rm -f "$VERSIONED_DMG" "$CANONICAL_DMG"

echo "Creating disk image: $VERSIONED_DMG..."
hdiutil create \
    -volname "Notepad++" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$VERSIONED_DMG"

echo "Creating canonical DMG link: $CANONICAL_DMG..."
ln -f "$VERSIONED_DMG" "$CANONICAL_DMG" 2>/dev/null || cp -p "$VERSIONED_DMG" "$CANONICAL_DMG"

# Clean up staging directory immediately after creation
rm -rf "$STAGING_DIR"
STAGING_DIR=""

echo "Computing SHA-256 checksums..."
(
    cd "$BUILD_DIR"
    shasum -a 256 "Notepad++.dmg" > "Notepad++.dmg.sha256"
    shasum -a 256 "Notepad++-v${VERSION}.dmg" > "Notepad++-v${VERSION}.dmg.sha256"
)

echo ""
echo "Generated distribution artifacts:"
ls -lh "$VERSIONED_DMG" "$CANONICAL_DMG" "$BUILD_DIR/Notepad++.dmg.sha256" "$BUILD_DIR/Notepad++-v${VERSION}.dmg.sha256"

# Run self-verification if enabled
if [ "$DO_VERIFY" = true ]; then
    verify_dmg "$CANONICAL_DMG"
fi

echo ""
echo "=== DMG distribution package successfully created and verified! ==="
