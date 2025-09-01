#!/bin/bash -e

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh"

# Handle --list-bootimg parameter
if [ "$1" = "--list-bootimg" ]; then
    echo "Available boot images in $VENDOR_IMAGE/:"
    find "$VENDOR_IMAGE" -name "boot*.img" -type f 2>/dev/null | xargs -r basename -a | sort || echo "  No boot images found"
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
mkdir -p "$OUT_KERNEL/vendor_binaries"
mkdir -p "$OUT_FILESYSTEM/vendor_initrd"

# Create temporary directory for extraction
TEMP_BOOT_DIR=$(mktemp -d -t boot-extract.XXXXXX)

# Extract boot.img using unpack_bootimg
echo "Unpacking boot image..."
unpack_bootimg --boot_img "$BOOT_IMAGE_PATH" --out "$TEMP_BOOT_DIR"

# Copy extracted ramdisk to vendor_binaries
echo "Copying extracted ramdisk..."
cp "$TEMP_BOOT_DIR/ramdisk" "$OUT_KERNEL/vendor_binaries/initrd.img"

# Copy extracted kernel to boot directory
echo "Copying extracted kernel..."
mkdir -p "$OUT_KERNEL/boot"
KERNEL_EXTRACTED=false

# Check if kernel Image already exists
if [ -f "$OUT_KERNEL/boot/Image" ]; then
    echo "Warning: Kernel Image already exists at $OUT_KERNEL/boot/Image"
    read -p "Do you want to override it? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping kernel extraction."
    else
        cp "$TEMP_BOOT_DIR/kernel" "$OUT_KERNEL/boot/Image"
        echo "Kernel Image overridden."
        KERNEL_EXTRACTED=true
    fi
else
    cp "$TEMP_BOOT_DIR/kernel" "$OUT_KERNEL/boot/Image"
    echo "Kernel Image extracted."
    KERNEL_EXTRACTED=true
fi

echo "Extracting initrd contents..."

# Remove existing contents to ensure clean extraction
rm -rf "$OUT_FILESYSTEM/vendor_initrd"/*

# Extract initrd.img contents - detect compression format
cd "$OUT_FILESYSTEM/vendor_initrd" || exit 1
if file "$OUT_KERNEL/vendor_binaries/initrd.img" | grep -q "gzip compressed"; then
    echo "Decompressing gzip compressed initrd..."
    gunzip -c "$OUT_KERNEL/vendor_binaries/initrd.img" | cpio -idmv
elif file "$OUT_KERNEL/vendor_binaries/initrd.img" | grep -q "LZ4 compressed"; then
    echo "Decompressing LZ4 compressed initrd..."
    lz4 -dc "$OUT_KERNEL/vendor_binaries/initrd.img" | cpio -idmv
elif file "$OUT_KERNEL/vendor_binaries/initrd.img" | grep -q "cpio archive"; then
    echo "Extracting uncompressed cpio archive..."
    cpio -idmv < "$OUT_KERNEL/vendor_binaries/initrd.img"
else
    echo "Unknown compression format, trying as uncompressed cpio..."
    cpio -idmv < "$OUT_KERNEL/vendor_binaries/initrd.img"
fi

# Cleanup temporary directory
rm -rf "$TEMP_BOOT_DIR"

echo "Extraction complete."
if [ "$KERNEL_EXTRACTED" = true ]; then
    echo "  Kernel extracted to: $OUT_KERNEL/boot/Image"
fi
echo "  initrd.img extracted to: $OUT_KERNEL/vendor_binaries/initrd.img"
echo "  Contents extracted to: $OUT_FILESYSTEM/vendor_initrd"