#!/bin/bash -e

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh"

echo "Extracting initrd.img from boot.img..."

# Create output directories
mkdir -p "$OUT_KERNEL/vendor_binaries"
mkdir -p "$OUT_FILESYSTEM/vendor_initrd"

# Extract initrd.img from boot.img using abootimg
cd "$OUT_KERNEL/vendor_binaries" || exit 1
abootimg -x "$VENDOR_IMAGE/boot.img"

echo "Extracting initrd contents..."

# Remove existing contents to ensure clean extraction
rm -rf "$OUT_FILESYSTEM/vendor_initrd"/*

# Extract initrd.img contents
cd "$OUT_FILESYSTEM/vendor_initrd" || exit 1
gunzip -c "$OUT_KERNEL/vendor_binaries"/initrd.img | cpio -idmv

echo "Extraction complete."
echo "  initrd.img extracted to: $OUT_KERNEL/vendor_binaries/initrd.img"
echo "  Contents extracted to: $OUT_FILESYSTEM/vendor_initrd"