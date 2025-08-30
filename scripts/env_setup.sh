#!/bin/bash
HOME_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORIGINAL_ROOT="$HOME_ROOT/original"
# shellcheck disable=SC2034
FS_ROOT="$ORIGINAL_ROOT/filesystems"
# shellcheck disable=SC2034
IMAGE_ROOT="$ORIGINAL_ROOT/images"

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/env.conf"

VENDOR_HOME="$HOME_ROOT"/vendor/"$PROJECT_NAME"
# shellcheck disable=SC2034
VENDOR_IMAGE="$VENDOR_HOME"/images

PROJECT_HOME="$HOME_ROOT"/project/"$PROJECT_NAME"
# shellcheck source=/dev/null
. "$PROJECT_HOME"/project.conf

# shellcheck disable=SC2034
KERNEL_SOURCE="$HOME_ROOT/kernel/$KERNEL_NAME"

OUT_HOME="$HOME_ROOT"/out/"$PROJECT_NAME"
# shellcheck disable=SC2034
OUT_IMAGE="$OUT_HOME"/images
# shellcheck disable=SC2034
OUT_FILESYSTEM="$OUT_HOME"/filesystems
# shellcheck disable=SC2034
OUT_KERNEL="$OUT_HOME"/kernel
# shellcheck disable=SC2034
OUT_QEMU_LOGS="$OUT_HOME"/qemu/log

# Default partition configuration
if [ -z "${PARTITION_BASENAMES+x}" ]; then
    PARTITION_BASENAMES=("system" "cache" "userdata")
fi

# Default QEMU graphic mode
if [ -z "${QEMU_GRAPHIC+x}" ]; then
    QEMU_GRAPHIC="yes"
fi