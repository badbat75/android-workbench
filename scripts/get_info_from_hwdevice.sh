#!/bin/bash

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh"

CONFIG_PATH=$VENDOR_HOME/configs/devicedump.txt
(
    # Check how init process is running
    adb shell ps -Z | grep init

    # Check root filesystem mount
    adb shell mount | grep " / "

    # Check init binary details
    adb shell ls -laZ /init

    # Check root directory contents with SELinux contexts
    adb shell ls -laZ /

    # Check SELinux status
    adb shell getenforce
    adb shell sestatus

    # Check init process details
    adb shell cat /proc/1/cmdline

    # Check what mounted the root filesystem
    adb shell cat /proc/mounts | grep " / "

    # Check initramfs or initrd details
    adb shell cat /proc/filesystems | grep tmpfs
    adb shell df /

    # Check if there's an initramfs
    adb shell ls -la /proc/1/root/

    # Check kernel command line that was used
    adb shell cat /proc/cmdline
) > "$CONFIG_PATH" 2>&1