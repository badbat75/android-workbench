#!/bin/bash -e

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh"

# Handle --list-bootimg parameter
if [ "$1" = "--list-bootimg" ]; then
    echo "Available boot images in $VENDOR_IMAGE/:"
    find "$VENDOR_IMAGE" -name "boot*.img" -type f -print0 2>/dev/null | xargs -0 -r basename -a | sort || echo "  No boot images found"
    exit 0
fi

# Set boot image name from command line parameter
BOOT_IMAGE_NAME="${1:-boot.img}"
BOOT_IMAGE_PATH="$VENDOR_IMAGE/$BOOT_IMAGE_NAME"

# Check if boot image exists
if [ ! -f "$BOOT_IMAGE_PATH" ]; then
    echo "Error: Boot image not found: $BOOT_IMAGE_PATH"
    exit 1
fi

echo "Extracting kernel and initrd from $BOOT_IMAGE_NAME using unpack_bootimg..."

# Create output directories
mkdir -p "$OUT_FILESYSTEM/vendor_initrd"

# Setup AIK directory
AIK_DIR="$HOME_ROOT/external_tools/aik"

# Clean up any previous extraction in AIK
echo "Cleaning up previous AIK extraction..."
cd "$AIK_DIR" || exit 1
./cleanup.sh > /dev/null 2>&1 || true

# Extract boot.img using AIK unpackimg directly from source
echo "Unpacking boot image using AIK..."
./unpackimg.sh "$BOOT_IMAGE_PATH" > /dev/null 2>&1 || {
    echo "Error: Failed to unpack boot image"
    exit 1
}

# Copy extracted ramdisk to vendor directory
echo "Copying extracted ramdisk..."
if [ -f "$AIK_DIR/split_img/boot.img-ramdisk.cpio.gz" ]; then
    cp "$AIK_DIR/split_img/boot.img-ramdisk.cpio.gz" "$VENDOR_HOME/initrd.img"
elif [ -f "$AIK_DIR/split_img/boot.img-ramdisk.cpio" ]; then
    cp "$AIK_DIR/split_img/boot.img-ramdisk.cpio" "$VENDOR_HOME/initrd.img"
else
    echo "Error: Could not find extracted ramdisk"
    exit 1
fi
echo "Ramdisk copied to $VENDOR_HOME/initrd.img"

# Copy extracted kernel to vendor directory
echo "Copying extracted kernel to vendor directory..."
mkdir -p "$VENDOR_HOME"
cp "$AIK_DIR/split_img/boot.img-kernel" "$VENDOR_HOME/kernel.img"
echo "Kernel copied to $VENDOR_HOME/kernel.img"

# Return to original directory
cd - > /dev/null

echo "Extracting initrd contents..."

# Remove existing contents to ensure clean extraction
rm -rf "$OUT_FILESYSTEM/vendor_initrd"
mkdir -p "$OUT_FILESYSTEM/vendor_initrd"

# Copy extracted ramdisk contents from AIK
if [ -d "$AIK_DIR/ramdisk" ]; then
    echo "Copying ramdisk contents from AIK..."
    cp -a "$AIK_DIR/ramdisk/"* "$OUT_FILESYSTEM/vendor_initrd/" 2>/dev/null || true
else
    echo "Warning: No ramdisk directory found in AIK extraction"
fi

echo "Extraction complete."
echo "  AIK extraction data kept in: $AIK_DIR"
echo "  Kernel extracted to: $VENDOR_HOME/kernel.img"
echo "  initrd.img extracted to: $VENDOR_HOME/initrd.img"
echo "  Contents extracted to: $OUT_FILESYSTEM/vendor_initrd"