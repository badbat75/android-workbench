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
    DRIVE_ARGS="-drive index=0,id=drive-virtio-disk0,if=none,format=raw,file=$MMC_DISK"
    DRIVE_ARGS+=" -device virtio-blk-pci-non-transitional,drive=drive-virtio-disk0,id=virtio0,bootindex=0,serial=MMC0"
else
    # Use individual disk images as separate drives
    DRIVE_ARGS=""
    drive_index=0
    for basename in "${PARTITION_BASENAMES[@]}"; do
        image_file="$OUT_IMAGE/${basename}.img"
        if [ -f "$image_file" ]; then
            DRIVE_ARGS="$DRIVE_ARGS -drive index=$drive_index,id=drive-virtio-disk$drive_index,if=none,format=raw,file=$image_file,aio=threads"
            DRIVE_ARGS+=" -device virtio-blk-pci-non-transitional,drive=drive-virtio-disk$drive_index,id=virtio$drive_index,bootindex=$drive_index,serial=${basename^^}"
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
    DISPLAY_ARGS="-display gtk,show-cursor=on"
    DISPLAY_ARGS+=" -device virtio-gpu-pci,id=gpu0"
    CMDLINE+=" console=ttyAMA0,115200 earlyprintk=ttyAMA0 fbcon=map:0 drm.debug=0x1e"
else
    DISPLAY_ARGS="-nographic"
    CMDLINE+=" console=ttyAMA0,115200 earlyprintk=ttyAMA0"
fi

function run_qemu {
    set -x
    qemu-system-aarch64 \
        -uuid 699acfc4-c8c4-11e7-882b-5065f31dc101 \
        -name guest=cvd-1,debug-threads=on \
        -machine virt,gic-version=2,mte=on,usb=off,dump-guest-core=off  \
        -cpu max \
        -smp 4,cores=4,threads=1 \
        -m "$MEMORY" \
        -overcommit mem-lock=off \
        -device virtio-balloon-pci-non-transitional,id=balloon0 \
        -rtc base=utc \
        -boot strict=on \
        $DRIVE_ARGS \
        -device i6300esb -watchdog-action reset \
        -netdev user,id=mynet \
	    -device virtio-net-pci,netdev=mynet \
        -object rng-random,id=objrng0,filename=/dev/urandom \
            -device virtio-rng-pci-non-transitional,rng=objrng0,id=rng0,max-bytes=1024,period=2000 \
        -audiodev pipewire,id=audio0 \
        -device AC97,audiodev=audio0 \
        -device qemu-xhci \
        -device usb-kbd \
        -device usb-mouse \
        $VIRTFS_ARGS \
        $DISPLAY_ARGS \
        -serial mon:stdio \
        -no-reboot -nodefaults -no-user-config \
        -kernel "$KERNEL" \
        -initrd "$INITRD" \
        -append "$CMDLINE" \
        | tee "$LOG"
    set +x
}

run_qemu

#        -bios /home/emiliano/git/AOSP/build/out/target/product/vsoc_arm64_only/bootloader.qemu \
#        -cpu "$CPU" \

