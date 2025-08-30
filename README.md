# Android Workbench

Build and test system for custom Android ROMs with QEMU emulation support.

## Features

- Custom Android ROM building
- QEMU emulation for testing
- Kernel modification and patching
- Initrd customization
- MMC disk creation

## Build Scripts

- **Kernel:** `./scripts/build_kernel.sh`
- **Initrd:** `./scripts/build_initrd.sh [all|qemu|debug]`
- **MMC disk:** `./scripts/create_mmc_disk.sh`

## QEMU Testing

- **Boot:** `./scripts/qemu_run.sh [--recovery]`
- **Show initrd:** `./scripts/show_initrd_content.sh <initrd_file>`

## Directory Structure

- **kernel/** - Kernel source code
- **out/** - Build artifacts
- **PROJECT_HOME/{overrides,inits,bin}** - Project files
- **doc/** - Documentation
- **scripts/** - Build and testing scripts

## Getting Started

1. Build the kernel: `./scripts/build_kernel.sh`
2. Create initrd: `./scripts/build_initrd.sh all`
3. Create MMC disk: `./scripts/create_mmc_disk.sh`
4. Test with QEMU: `./scripts/qemu_run.sh`