# Android Boot Process Analysis

## Root Filesystem Location
**Answer: The `/` (root) filesystem IS the initramfs itself**

The initramfs contains the complete Android root filesystem structure and serves as `/` during boot. It includes:
- `/init` - Android init binary
- `/system` - Symlink to real system partition (mounted later)
- `/data`, `/cache` - Mount points for data partitions
- `/dev`, `/proc`, `/sys` - Virtual filesystems
- All Android init scripts and configuration

## Boot Sequence

### Phase 1: Kernel Init
1. Kernel loads and extracts initramfs as root filesystem (`/`)
2. Kernel executes `/init` (Android init process) as PID 1
3. Init loads `/init.rc` and device-specific scripts

### Phase 2: Early Init (`on early-init`)
```bash
# Create essential directories and mount points
mkdir /mnt 0775 root system
mount cgroup none /acct cpuacct
mount cgroup none /dev/memcg memory
start ueventd  # Device node manager
```

### Phase 3: Filesystem Mount (`on fs`)
**Key line in `init.samsungexynos7870.rc:660`:**
```bash
mount_all /fstab.samsungexynos7870
```

This mounts all partitions according to fstab:
- `/dev/vda → /system` (ext4, read-only) - Android system
- `/dev/vdb → /cache` (ext4) - Temporary cache
- `/dev/vdc → /data` (ext4) - User data and apps

### Phase 4: System Services
```bash
# Mount additional virtual filesystems
mount tmpfs tmpfs /mnt mode=0755,uid=0,gid=1000
symlink /system/etc /etc
symlink /system/vendor /vendor
```

## Filesystem Hierarchy After Boot
```
/ (initramfs root)
├── init, init.rc, etc. (from initramfs)
├── /system → mounted from /dev/vda
├── /data → mounted from /dev/vdc  
├── /cache → mounted from /dev/vdb
├── /vendor → symlink to /system/vendor
├── /etc → symlink to /system/etc
├── /dev → devtmpfs (device nodes)
├── /proc → procfs (kernel info)
└── /sys → sysfs (kernel objects)
```
