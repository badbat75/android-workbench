## Repository Description
Build and test system for custom Android ROMs. It can emulate ROM thorugh QEMU.

## CLAUDE rules
- When new facts are learnt update CLAUDE.md
- Keep CLAUDE.md as mush as small and synthetic as possible
- Do not create documentation or report if not asked
- Fact check before creating or launching new commands

## Development Rules
- Build synthetic scripts with minimal amount of output
- Every time you apply a change in the kernel code do diff -Naur kernel/original-sm-t580-3.18.14/<changedfile> kernel/sm-t580-3.18.14/<changedfile> >> project/sm-t580/kernel-devel/sm-t580-3.18.14/additional_exynos_0_1.patch   

### Build Scripts
- Kernel: `./scripts/build_kernel.sh`
- Initrd: `./scripts/build_initrd.sh [all|qemu|debug]`
- MMC disk: `./scripts/create_mmc_disk.sh`

### QEMU Testing
- Boot: `./scripts/qemu_run.sh [--recovery]`
- Show initrd: `./scripts/show_initrd_content.sh <initrd_file>`

### File Locations
- **Kernel source:** `kernel/`
- **Build artifacts:** `out/`
- **Project files:** `PROJECT_HOME/{overrides,inits,bin}`
- **Useful documentation:** `doc/`
