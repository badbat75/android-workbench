#!/bin/bash -e

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh"

# Check VOLUME_TYPE - default to "partition" if not set
VOLUME_TYPE="${VOLUME_TYPE:-partition}"

# Create temporary directory for converted filesystems
TEMP_FS_DIR=$(mktemp -d -t mmc_filesystems.XXXXXX)
echo "Using temporary directory: $TEMP_FS_DIR"

# Cleanup function to remove temporary directory
cleanup() {
    echo "Cleaning up temporary directory..."
    rm -rf "$TEMP_FS_DIR"
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Partition configuration is set in env_setup.sh
IMAGE_SUFFIX=".img"

# Generate image filenames and partition names from baseline
IMAGES=()
PARTITION_NAMES=()
for basename in "${PARTITION_BASENAMES[@]}"; do
    IMAGES+=("${basename}${IMAGE_SUFFIX}")
    # Capitalize first letter using parameter expansion
    PARTITION_NAMES+=("${basename^}")
done

[ ! -d "$OUT_IMAGE" ] && mkdir -p "$OUT_IMAGE"

# Function to check if image is Android sparse format
is_sparse_image() {
    local file="$1"
    file "$file" 2>/dev/null | grep -q "Android sparse image"
}

# Function to convert sparse images to raw format
convert_sparse_to_raw() {
    local src_dir="$1"
    local dst_dir="$2"
    local images=("${!3}")
    
    for image in "${images[@]}"; do
        if is_sparse_image "$src_dir/$image"; then
            echo "Converting $image from sparse to raw..."
            simg2img "$src_dir/$image" "$dst_dir/$image"
        else
            echo "$image is already in raw format, copying..."
            cp "$src_dir/$image" "$dst_dir/$image"
        fi
    done
}

# Handle disk mode - just convert and copy volumes
if [ "$VOLUME_TYPE" = "disk" ]; then
    echo "VOLUME_TYPE=disk: Converting sparse images to raw format and copying to $OUT_IMAGE..."
    
    convert_sparse_to_raw "$VENDOR_IMAGE" "$OUT_IMAGE" IMAGES[@]
    
    echo "Disk mode complete. Converted images are in $OUT_IMAGE:"
    for image in "${IMAGES[@]}"; do
        echo "  $OUT_IMAGE/$image"
    done
    exit 0
fi

# Continue with partition mode (original behavior)
MMC_DISK="$OUT_IMAGE/mmc_disk.img"

echo "VOLUME_TYPE=partition: Creating combined MMC disk with partitions..."

# Convert sparse images to raw for partition mode
convert_sparse_to_raw "$VENDOR_IMAGE" "$TEMP_FS_DIR" IMAGES[@]

# Function to round up to next 4KB boundary and convert to MB with proper overhead
round_up_4kb_with_overhead() {
    local size=$1
    local sector_size=4096
    # Add 5% overhead for filesystem metadata and round up to next 4KB boundary
    local size_with_overhead=$(( size + (size / 20) ))
    local aligned_size=$(( ((size_with_overhead + sector_size - 1) / sector_size) * sector_size ))
    # Convert to MB and round up
    echo $(( (aligned_size + 1024*1024 - 1) / 1024 / 1024 ))
}

# Calculate sizes and partitions in a single loop
PARTITION_SIZES=()
PARTITION_MBS=()
PARTITION_TOTAL_MB=0

for image in "${IMAGES[@]}"; do
    size=$(stat -c%s "$TEMP_FS_DIR"/"$image")
    PARTITION_SIZES+=("$size")
    mb=$(round_up_4kb_with_overhead "$size")
    PARTITION_MBS+=("$mb")
    PARTITION_TOTAL_MB=$((PARTITION_TOTAL_MB + mb))
done
echo "Total space needed for partitions: ${PARTITION_TOTAL_MB}MB"

# Round total disk size up to next power of 2 for SDHCI compatibility
TOTAL_MB=1
while [ $TOTAL_MB -lt $PARTITION_TOTAL_MB ]; do
    TOTAL_MB=$((TOTAL_MB * 2))
done

echo "Disk size rounded to power of 2: ${TOTAL_MB}MB"


echo "Image sizes (bytes):"
for i in "${!PARTITION_NAMES[@]}"; do
    name="${PARTITION_NAMES[$i]}"
    size="${PARTITION_SIZES[$i]}"
    echo "  $name:   $size bytes ($((size / 1024 / 1024)) MiB)"
done

echo ""
echo "Partition sizes (with 5% overhead and 4KB alignment):"
for i in "${!PARTITION_NAMES[@]}"; do
    name="${PARTITION_NAMES[$i]}"
    mb="${PARTITION_MBS[$i]}"
    echo "  $name:   ${mb}MB"
done
echo "  Total:    ${TOTAL_MB}MB"

# Create empty disk image
echo "Creating ${TOTAL_MB}MB disk image..."
dd if=/dev/zero of="$MMC_DISK" bs=1M count=$TOTAL_MB status=progress

# Create partition table
echo "Creating partition table..."
parted "$MMC_DISK" --script mklabel gpt

# Create partitions and calculate positions in a single loop
echo "Creating partitions..."
current_start=1
PARTITION_STARTS=()

for i in "${!PARTITION_NAMES[@]}"; do
    name="${PARTITION_NAMES[$i]}"
    name_lower="${PARTITION_BASENAMES[$i]}"
    mb="${PARTITION_MBS[$i]}"
    end=$((current_start + mb))
    
    PARTITION_STARTS+=("$current_start")
    echo "  $name:   ${current_start}MB to ${end}MB (${mb}MB)"
    parted "$MMC_DISK" --script mkpart "$name_lower" ext4 "${current_start}MB" "${end}MB"
    
    current_start=$end
done

# Setup loop device for the disk
echo "Setting up loop device..."
LOOP_DEV=$(sudo losetup --find --show "$MMC_DISK")
echo "Using loop device: $LOOP_DEV"

# Wait for partition devices to be created
sleep 1
sudo partprobe "$LOOP_DEV"
sleep 1

# Copy data to partitions
for i in "${!IMAGES[@]}"; do
    image="${IMAGES[$i]}"
    partition_name="${PARTITION_BASENAMES[$i]}"
    partition_num=$((i + 1))
    echo "Copying $partition_name partition..."
    sudo dd if="$TEMP_FS_DIR/$image" of="${LOOP_DEV}p$partition_num" bs=1M status=progress
done

# Clean up loop device
echo "Cleaning up..."
sudo losetup -d "$LOOP_DEV"

echo "MMC disk created successfully: $MMC_DISK"
echo "Partitions:"
for i in "${!PARTITION_BASENAMES[@]}"; do
    partition_num=$((i + 1))
    partition_name="${PARTITION_BASENAMES[$i]}"
    echo "  /dev/mmcblk0p${partition_num} -> $partition_name"
done