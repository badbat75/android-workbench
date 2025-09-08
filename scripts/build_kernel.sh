#!/bin/bash -e

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh"

# Configuration
JOBS=$(nproc)

KERNEL_IMAGE="arch/$ARCH/boot/$KERNEL_IMAGE_NAME"

echo "Building kernel..."

# Function to print status messages (minimal)
print_status() {
    echo "$1"
}

print_error() {
    echo "ERROR: $1" >&2
}

# Function to check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 not found. Please install required dependencies."
        exit 1
    fi
}

# Check dependencies quietly
check_command "${CROSS_COMPILE}gcc"
check_command make

# Setup ccache if CCACHE variable is set
if [ -n "$CCACHE" ]; then
    check_command "$CCACHE"
    export CC="$CCACHE ${CROSS_COMPILE}gcc"
    export CXX="$CCACHE ${CROSS_COMPILE}g++"
    export HOSTCC="$CCACHE gcc"
    export HOSTCXX="$CCACHE g++"
    print_status "Using ccache for compilation acceleration"
else
    export CC="${CROSS_COMPILE}gcc"
    export CXX="${CROSS_COMPILE}g++"
    export HOSTCC="gcc"
    export HOSTCXX="g++"
fi

# Verify kernel directory exists
if [ ! -f "$KERNEL_SOURCE/Makefile" ] || [ ! -d "$KERNEL_SOURCE/arch/arm64" ]; then
    print_error "Kernel source not found at $KERNEL_SOURCE"
    exit 1
fi

if [ -n "$KERNEL_CONFIG_DEVEL" ]; then
    cp "$PROJECT_HOME/kernel-devel/$KERNEL_CONFIG_DEVEL" "$KERNEL_SOURCE/.config"
fi

# Fix previous configs
make -C "${KERNEL_SOURCE}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="$CC" HOSTCC="$HOSTCC" olddefconfig

if [ "$1" == "--nconfig" ]
then
    print_status "Launching menuconfig..."
    make -C "${KERNEL_SOURCE}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="$CC" HOSTCC="$HOSTCC" nconfig
    exit 0
fi

# Copying back adjusted config
cp "$KERNEL_SOURCE/.config" "$PROJECT_HOME/kernel-devel/$KERNEL_CONFIG_DEVEL"

if [ "$1" == "--defconfig" ]
then
    exit 0
fi

# Clean and build kernel
make -C "${KERNEL_SOURCE}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="$CC" HOSTCC="$HOSTCC" clean
print_status "Building kernel with ${JOBS} jobs..."
make -C "${KERNEL_SOURCE}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="$CC" HOSTCC="$HOSTCC" -j"${JOBS}" "$KERNEL_IMAGE_NAME"

# Check if kernel build succeeded
if [ ! -f "${KERNEL_SOURCE}/${KERNEL_IMAGE}" ]; then
    print_error "Kernel build failed - Image not found"
    exit 1
fi

# Check if modules are enabled in config
MODULES_ENABLED=false
if grep -q "^CONFIG_MODULES=y" "${KERNEL_SOURCE}/.config"; then
    MODULES_ENABLED=true
    print_status "Modules enabled in config, building modules..."
else
    print_status "Modules disabled in config, skipping module build..."
fi

# Build modules (if enabled) and dtbs
if [ "$MODULES_ENABLED" = true ]; then
    make -C "${KERNEL_SOURCE}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="$CC" HOSTCC="$HOSTCC" -j"${JOBS}" modules
fi
make -C "${KERNEL_SOURCE}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="$CC" HOSTCC="$HOSTCC" dtbs

# Create output directories
mkdir -p "$OUT_KERNEL/boot"
mkdir -p "$OUT_KERNEL/dtbs"

# Install build artifacts
if [ "$MODULES_ENABLED" = true ]; then
    make -C "${KERNEL_SOURCE}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="$CC" HOSTCC="$HOSTCC" INSTALL_MOD_PATH="$OUT_KERNEL/boot" modules_install
fi
make -C "${KERNEL_SOURCE}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="$CC" HOSTCC="$HOSTCC" INSTALL_DTBS_PATH="$OUT_KERNEL/dtbs" dtbs_install || {
    print_status "Warning: DTS install failed, continuing anyway..."
}

# Copy kernel image
cp "${KERNEL_SOURCE}/${KERNEL_IMAGE}" "$OUT_KERNEL/boot/"

KERNEL_SIZE=$(stat -c%s "${KERNEL_SOURCE}/${KERNEL_IMAGE}")
print_status "Kernel built successfully ($((KERNEL_SIZE/1024/1024))MB)"
print_status "Build artifacts in: $OUT_KERNEL/"