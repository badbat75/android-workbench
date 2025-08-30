#!/bin/bash -e

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh"

# Show usage if no parameter provided
show_usage() {
    echo "Usage: $0 <initrd_image_file>"
    echo ""
    echo "Examples:"
    echo "  $0 $OUT_KERNEL/boot/initrd-qemu.img"
    echo "  $0 $OUT_KERNEL/boot/initrd_debug.img"
    echo "  $0 /path/to/custom/initrd.img"
    echo ""
}

if [ -z "$1" ]; then
    echo "Error: No initrd image file specified"
    echo ""
    show_usage
    exit 1
fi

INITRD_FILE="$(realpath "$1")"

if [ ! -f "$INITRD_FILE" ]; then
    echo "Error: File not found: $INITRD_FILE"
    exit 1
fi

echo "Scanning initrd content: $INITRD_FILE"
echo "========================================"

if file "$INITRD_FILE" | grep -q gzip; then
    gunzip -c "$INITRD_FILE" | cpio -tv 2>/dev/null
else
    cpio -tv < "$INITRD_FILE" 2>/dev/null
fi
