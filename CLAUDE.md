## Repository Description
Build and test system for custom Android ROMs. It can emulate ROM thorugh QEMU.

## CLAUDE rules
- When new facts are learnt update CLAUDE.md
- Keep CLAUDE.md as mush as small and synthetic as possible
- Do not create documentation or report if not asked
- Fact check before creating or launching new commands

## Development Rules
- Build synthetic scripts with minimal amount of output
- Every time you apply a change in the kernel code do a diff -Naur to track the changes.
- Look at the scripts/env.conf and its related project.conf to have an environment setting.

### Build Scripts
- Kernel: `./scripts/build_kernel.sh`
- Initrd: `./scripts/build_initrd.sh [all|qemu|debug]`
- MMC disk: `./scripts/prepare_disks.sh`

### QEMU Testing
- Boot: `./scripts/qemu_run.sh [--recovery]`
- Show initrd: `./scripts/show_initrd_content.sh <initrd_file>`

### File Locations
- **Kernel source:** `kernel/`
- **Build artifacts:** `out/`
- **Project files:** `PROJECT_HOME/{overrides,inits,bin}`
- **Useful documentation:** `doc/`

## Known Issues
### Android 12 QEMU Boot Crash
- **Issue**: `android.hardware.security.keymint-service` crashes with "Check failed: status == STATUS_OK" causing `apexd-failed` reboot
- **Cause**: KeyMint service requires hardware TEE/HSM not available in QEMU emulation
- **Attempts**: Service overrides in init.rc don't prevent APEX-loaded services from starting
- **Status**: Unresolved - need vendor image modification or APEX service disable method

### QEMU FirstStageMount Boot Issue
- **Issue**: FirstStageMount fails with "partition(s) not found in /sys, waiting for their uevent(s): vda1"
- **Root Cause**: First stage init runs before any init.rc processing, so manual device creation happens too late
- **Key Discovery**: Virtio-blk devices ARE detected by kernel (fd00-fd04 = major 253:0-4) but need device nodes before first stage init
- **Attempts**: 
  - Manual mknod creation in early-init (too late - runs after first stage init)
  - Direct device paths /dev/block/vda1 in fstab (requires sysfs entries that don't exist)
  - Various kernel parameters and fstab locations
- **Current Status**: Need pre-built device nodes in initramfs or alternative init approach
