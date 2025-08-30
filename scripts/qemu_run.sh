#!/bin/bash

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh"

# Use kernel from build output
KERNEL="$OUT_KERNEL/boot/Image"
CPU=${CPU:-cortex-a57}
MEMORY=${MEMORY:-2048}

# Determine disk mode and setup storage
if [ "${VOLUME_TYPE:-partition}" = "partition" ]; then
    # Use combined MMC disk with partitions
    MMC_DISK="$OUT_IMAGE/mmc_disk.img"
    DRIVE_ARGS="-drive index=0,id=mmc0,if=none,format=raw,file=$MMC_DISK -device virtio-blk-device,drive=mmc0"
else
    # Use individual disk images as separate drives
    DRIVE_ARGS=""
    drive_index=0
    for basename in "${PARTITION_BASENAMES[@]}"; do
        image_file="$OUT_IMAGE/${basename}.img"
        if [ -f "$image_file" ]; then
            DRIVE_ARGS="$DRIVE_ARGS -drive index=$drive_index,id=${basename},if=none,format=raw,file=$image_file -device virtio-blk-device,drive=${basename},serial=${basename^^}"
            ((drive_index++))
        fi
    done
fi

# Check for --recovery parameter
if [ "$1" = "--recovery" ]; then
    INITRD="$OUT_KERNEL/boot/initrd_debug.img"
    VIRTFS_ARGS="-virtfs local,path=$PROJECT_HOME,mount_tag=hostqemu,security_model=passthrough,id=hostqemu"
    echo "Using debug initrd with shell as rdinit"
    echo "Host scripts/qemu will be available at mount tag 'hostqemu'"
    "$HOME_ROOT"/scripts/build_initrd.sh debug
    LOG="$OUT_QEMU_LOGS/qemu_debug.log"
else
    INITRD="$OUT_KERNEL/boot/initrd-qemu.img"
    VIRTFS_ARGS=""
    "$HOME_ROOT"/scripts/build_initrd.sh qemu
    LOG="$OUT_QEMU_LOGS/qemu.log"
fi

[ ! -d "$OUT_QEMU_LOGS" ] && mkdir -p "$OUT_QEMU_LOGS"

# Determine display mode and kernel command line
if [ "$QEMU_GRAPHIC" = "yes" ] || [ "$QEMU_GRAPHIC" = "1" ] || [ "$QEMU_GRAPHIC" = "true" ]; then
    DISPLAY_ARGS="-display gtk,show-cursor=on -device bochs-display"
    CMDLINE+=" console=tty0 console=ttyAMA0,115200 earlyprintk=ttyAMA0 fbcon=map:0 drm.debug=0x1e"
else
    DISPLAY_ARGS="-nographic"
    CMDLINE+=" console=ttyAMA0,115200 earlyprintk=ttyAMA0"
fi

function run_qemu {
    set -x
    qemu-system-aarch64 -machine type=virt \
        -cpu "$CPU" \
        -m "$MEMORY" \
        -kernel "$KERNEL" \
        -initrd "$INITRD" \
        $DRIVE_ARGS \
        -device i6300esb -watchdog-action reset \
        -netdev user,id=mynet \
	    -device virtio-net-pci,netdev=mynet \
        -object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0 \
        -audiodev pipewire,id=audio0 \
        -device AC97,audiodev=audio0 \
        -device qemu-xhci \
        -device usb-kbd \
        -device usb-mouse \
        $VIRTFS_ARGS \
        -append "$CMDLINE" \
        $DISPLAY_ARGS \
        -serial mon:stdio \
        -no-reboot -nodefaults \
        -object memory-backend-file,id=ram-mem,size="${MEMORY}"M,mem-path="$OUT_IMAGE"/ram.img,share=on \
        -L /run/media/emiliano/AndroidSources/12/prebuilts/android-emulator/linux-x86_64/lib/pc-bios \
        | tee "$LOG"
    set +x
}

run_qemu