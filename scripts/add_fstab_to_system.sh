#!/bin/bash

# Add fstab.qemu to system partition for second stage mounting using debugfs

set -euo pipefail

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh"

SYSTEM_IMG="$OUT_IMAGE/system.img"
FSTAB_SOURCE="$PROJECT_HOME/initrd-devel/overrides/fstab.qemu"
TEMP_MOUNT="/tmp/system_mount_$$"
TEMP_SYSTEM_BACKUP="$OUT_IMAGE/system.img.backup"

if [ ! -f "$SYSTEM_IMG" ]; then
    echo "ERROR: System image not found at $SYSTEM_IMG"
    exit 1
fi

if [ ! -f "$FSTAB_SOURCE" ]; then
    echo "ERROR: Source fstab not found at $FSTAB_SOURCE"
    exit 1
fi

echo "Creating backup of system.img..."
cp "$SYSTEM_IMG" "$TEMP_SYSTEM_BACKUP"

echo "Adding fstab.qemu to system partition using debugfs..."
TEMP_FSTAB="/tmp/fstab.qemu.$$"
cp "$FSTAB_SOURCE" "$TEMP_FSTAB"

# Use debugfs to write the file to /system/etc/fstab.qemu
echo "Writing fstab.qemu to system partition..."
{
    echo "cd /system/etc"
    echo "write $TEMP_FSTAB fstab.qemu"
    echo "quit"
} | sudo debugfs -w "$SYSTEM_IMG"

# Clean up temporary file
rm -f "$TEMP_FSTAB"

echo "Verifying fstab was added using debugfs..."
if sudo debugfs -R "ls /system/etc" "$SYSTEM_IMG" | grep -q "fstab.qemu"; then
    echo "✓ fstab.qemu successfully added to system partition"
    echo "Content:"
    sudo debugfs -R "cat /system/etc/fstab.qemu" "$SYSTEM_IMG"
else
    echo "✗ Failed to add fstab.qemu"
    exit 1
fi

echo "System partition updated successfully!"
echo "Backup available at: $TEMP_SYSTEM_BACKUP"