#!/bin/bash -e

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh"

# Usage function
show_usage() {
    echo "Usage: $0 [-k kernel_image] [-r initrd_image] [--add-suffix=string]"
    echo ""
    echo "Creates boot.img from kernel and initrd with dynamic ramdisk offset calculation"
    echo ""
    echo "Options:"
    echo "  -k, --kernel PATH     Path to kernel Image (default: vendor/<project>/kernel.img or error)"
    echo "  -r, --ramdisk PATH    Path to initrd image (default: vendor/<project>/initrd.img or error)"
    echo "  --add-suffix=STRING   Add suffix to output name: boot_STRING.img"
    echo "  -h, --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 -k vendor/sm-t580/kernel.img -r vendor/sm-t580/initrd.img"
    echo "  $0 --add-suffix=debug -k out/kernel/Image"
    echo "  $0 --add-suffix=custom -k /path/to/kernel -r /path/to/initrd"
    echo ""
    echo "Output:"
    echo "  Boot image will be created at: $OUT_IMAGE/boot.img (or boot_suffix.img)"
}

# Initialize variables
KERNEL_IMAGE=""
INITRD_IMAGE=""
SUFFIX=""

# Parse parameters
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -k|--kernel)
            KERNEL_IMAGE="$2"
            shift 2
            ;;
        -r|--ramdisk)
            INITRD_IMAGE="$2"
            shift 2
            ;;
        --add-suffix=*)
            SUFFIX="${1#*=}"
            shift
            ;;
        *)
            echo "Error: Unknown option '$1'"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Set defaults if not specified - prefer vendor directory
if [ -z "$KERNEL_IMAGE" ]; then
    if [ -f "$VENDOR_HOME/kernel.img" ]; then
        KERNEL_IMAGE="$VENDOR_HOME/kernel.img"
    else
        echo "Error: No kernel specified and vendor kernel not found at $VENDOR_HOME/kernel.img"
        echo "Please specify kernel with -k option or run extract_bootimg.sh first"
        exit 1
    fi
fi

if [ -z "$INITRD_IMAGE" ]; then
    if [ -f "$VENDOR_HOME/initrd.img" ]; then
        INITRD_IMAGE="$VENDOR_HOME/initrd.img"
    else
        echo "Error: No initrd specified and vendor initrd not found at $VENDOR_HOME/initrd.img"
        echo "Please specify initrd with -r option or run extract_bootimg.sh first"
        exit 1
    fi
fi

# Resolve paths relative to repository root if not absolute
if [[ "$KERNEL_IMAGE" != /* ]]; then
    KERNEL_IMAGE="$HOME_ROOT/$KERNEL_IMAGE"
fi

if [[ "$INITRD_IMAGE" != /* ]]; then
    INITRD_IMAGE="$HOME_ROOT/$INITRD_IMAGE"
fi

# Display source files
echo "Source files:"
echo "  Kernel: $KERNEL_IMAGE"
echo "  Initrd: $INITRD_IMAGE"

# Verify input files exist
if [ ! -f "$KERNEL_IMAGE" ]; then
    echo "Error: Kernel image not found: $KERNEL_IMAGE"
    exit 1
fi

if [ ! -f "$INITRD_IMAGE" ]; then
    echo "Error: Initrd image not found: $INITRD_IMAGE"
    exit 1
fi

# Setup AIK directory
AIK_DIR="$HOME_ROOT/external_tools/aik"
SPLIT_IMG_DIR="$AIK_DIR/split_img"

echo "Step 1: Cleaning up AIK directory..."
cd "$AIK_DIR" || exit 1
./cleanup.sh > /dev/null 2>&1 || true

echo "Step 2: Extracting original boot.img to get parameters..."
VENDOR_BOOT="$VENDOR_IMAGE/boot.img"
if [ -f "$VENDOR_BOOT" ]; then
    ./unpackimg.sh "$VENDOR_BOOT" > /dev/null 2>&1 || {
        echo "Error: Failed to extract vendor boot.img"
        exit 1
    }
    echo "Original boot.img extracted successfully"
else
    echo "Error: Original boot.img not found at $VENDOR_BOOT"
    exit 1
fi

echo "Step 3: Reading boot image parameters..."
BASE_ADDRESS=$(cat "$SPLIT_IMG_DIR/boot.img-base")
KERNEL_OFFSET=$(cat "$SPLIT_IMG_DIR/boot.img-kernel_offset")
SECOND_OFFSET=$(cat "$SPLIT_IMG_DIR/boot.img-second_offset")
TAGS_OFFSET=$(cat "$SPLIT_IMG_DIR/boot.img-tags_offset")
PAGESIZE=$(cat "$SPLIT_IMG_DIR/boot.img-pagesize")
BOARD=$(cat "$SPLIT_IMG_DIR/boot.img-board")
CMDLINE=$(cat "$SPLIT_IMG_DIR/boot.img-cmdline")
OS_VERSION=$(cat "$SPLIT_IMG_DIR/boot.img-os_version" 2>/dev/null || echo "8.0.0")
OS_PATCH_LEVEL=$(cat "$SPLIT_IMG_DIR/boot.img-os_patch_level" 2>/dev/null || echo "2018-01")

echo "Original boot parameters:"
echo "  Base: $BASE_ADDRESS, Kernel offset: $KERNEL_OFFSET"
echo "  Page size: $PAGESIZE, Board: '$BOARD'"
echo "  Command line: $CMDLINE"

echo "Step 4: Calculating new ramdisk offset based on kernel size..."
KERNEL_SIZE=$(stat -c%s "$KERNEL_IMAGE")
echo "New kernel size: $KERNEL_SIZE bytes ($((KERNEL_SIZE/1024/1024))MB)"

# Calculate dynamic ramdisk offset
# The ramdisk should be placed after kernel + buffer, aligned to boundary
BUFFER_SICUREZZA=$((4 * 1024 * 1024))  # 4MB buffer
ALLINEAMENTO=$((1 * 1024 * 1024))      # 1MB alignment

# Convert hex values to decimal for calculation
KERNEL_OFFSET_DEC=$((KERNEL_OFFSET))
BASE_ADDRESS_DEC=$((BASE_ADDRESS))

# Calculate kernel end position: kernel_offset + kernel_size + buffer
KERNEL_END=$((KERNEL_OFFSET_DEC + KERNEL_SIZE + BUFFER_SICUREZZA))

# Round up to alignment boundary
ALIGNED_RAMDISK_POS=$(( (KERNEL_END + ALLINEAMENTO - 1) / ALLINEAMENTO * ALLINEAMENTO ))

# The ramdisk offset is relative to base address
RAMDISK_OFFSET_DEC=$ALIGNED_RAMDISK_POS
RAMDISK_OFFSET=$(printf "0x%08x" $RAMDISK_OFFSET_DEC)

echo "Calculation details:"
echo "  Kernel offset: $KERNEL_OFFSET ($KERNEL_OFFSET_DEC)"
echo "  Kernel size: $KERNEL_SIZE bytes"  
echo "  Buffer: $BUFFER_SICUREZZA bytes"
echo "  Kernel end + buffer: $KERNEL_END"
echo "  Aligned position: $ALIGNED_RAMDISK_POS"

echo "New calculated ramdisk offset: $RAMDISK_OFFSET"

echo "Step 5: Injecting new kernel and initrd..."

# Replace kernel with new one
echo "Replacing kernel: $(basename "$KERNEL_IMAGE")"
cp "$KERNEL_IMAGE" "$SPLIT_IMG_DIR/boot.img-kernel"

# Replace initrd with new one and detect compression
echo "Replacing initrd: $(basename "$INITRD_IMAGE")"
if file "$INITRD_IMAGE" | grep -q "gzip compressed"; then
    echo "gzip" > "$SPLIT_IMG_DIR/boot.img-ramdiskcomp"
    # Remove old ramdisk files
    rm -f "$SPLIT_IMG_DIR/boot.img-ramdisk.cpio"* 2>/dev/null || true
    cp "$INITRD_IMAGE" "$SPLIT_IMG_DIR/boot.img-ramdisk.cpio.gz"
    echo "Detected gzip compressed initrd"
elif file "$INITRD_IMAGE" | grep -q "LZ4 compressed"; then
    echo "lz4" > "$SPLIT_IMG_DIR/boot.img-ramdiskcomp"
    # Remove old ramdisk files
    rm -f "$SPLIT_IMG_DIR/boot.img-ramdisk.cpio"* 2>/dev/null || true
    cp "$INITRD_IMAGE" "$SPLIT_IMG_DIR/boot.img-ramdisk.cpio.lz4"
    echo "Detected LZ4 compressed initrd"
else
    echo "uncompressed" > "$SPLIT_IMG_DIR/boot.img-ramdiskcomp"
    # Remove old ramdisk files
    rm -f "$SPLIT_IMG_DIR/boot.img-ramdisk.cpio"* 2>/dev/null || true
    cp "$INITRD_IMAGE" "$SPLIT_IMG_DIR/boot.img-ramdisk.cpio"
    echo "Detected uncompressed initrd"
fi

echo "Step 6: Updating ramdisk offset..."
# Update only the ramdisk offset, keep all other original parameters
echo "$RAMDISK_OFFSET" > "$SPLIT_IMG_DIR/boot.img-ramdisk_offset"

# Use AIK repackimg to create boot.img
echo "Step 7: Creating new boot.img using AIK..."
cd "$AIK_DIR" || exit 1
./repackimg.sh > /dev/null 2>&1 || {
    echo "Error: Failed to create boot image"
    exit 1
}

# Determine output filename
if [ -n "$SUFFIX" ]; then
    OUTPUT_FILE="$OUT_IMAGE/boot_${SUFFIX}.img"
else
    OUTPUT_FILE="$OUT_IMAGE/boot.img"
fi

# Create output directory and copy boot image
mkdir -p "$OUT_IMAGE"
if [ -f "$AIK_DIR/image-new.img" ]; then
    cp "$AIK_DIR/image-new.img" "$OUTPUT_FILE"
    echo "Boot image created successfully: $OUTPUT_FILE"
    
    # Display boot image info
    BOOT_SIZE=$(stat -c%s "$OUTPUT_FILE")
    echo ""
    echo "Boot image details:"
    echo "  File: $(basename "$OUTPUT_FILE")"
    echo "  Size: $((BOOT_SIZE/1024/1024))MB"
    echo "  Base address: $BASE_ADDRESS"
    echo "  Kernel offset: $KERNEL_OFFSET"
    echo "  Ramdisk offset: $RAMDISK_OFFSET (dynamically calculated)"
    echo "  Page size: $PAGESIZE"
else
    echo "Error: Boot image creation failed - image-new.img not found"
    exit 1
fi

# Keep AIK data for reference
echo ""
echo "AIK data kept in: $AIK_DIR for reference"