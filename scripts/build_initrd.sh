#!/bin/bash -e

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/env_setup.sh"

OVERRIDES_ROOT="$PROJECT_HOME/initrd-devel/overrides"
INITS_ROOT="$PROJECT_HOME/initrd-devel/debug"
BINARIES_ROOT="$PROJECT_HOME/initrd-devel/binaries"

# Common cleanup function
cleanup() {
    if [[ -n "${TEMP_INITRD:-}" ]]; then
        rm -f "$TEMP_INITRD"
    fi
    if [[ -n "${TEMP_DIR:-}" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT


# Build QEMU initrd from vendor initrd
build_qemu_initrd() {
    echo "Building QEMU initrd from vendor initrd..."
    
    # Create temporary file for initrd processing
    TEMP_INITRD=$(mktemp -t initrd-qemu-build.XXXXXX)
    
    # Use vendor initrd from extracted binaries
    local vendor_initrd="$OUT_KERNEL/vendor_binaries/initrd.img"
    
    # Check if vendor initrd exists
    if [ ! -f "$vendor_initrd" ]; then
        echo "Warning: Vendor initrd not found at $vendor_initrd, creating empty initrd..."
        touch "$TEMP_INITRD"
    else
        # Detect compression format and decompress vendor initrd
        echo "Detecting vendor initrd compression format..."
        if file "$vendor_initrd" | grep -q "gzip compressed"; then
            echo "Decompressing gzip compressed initrd..."
            gunzip -c "$vendor_initrd" > "$TEMP_INITRD"
        elif file "$vendor_initrd" | grep -q "LZ4 compressed"; then
            echo "Decompressing LZ4 compressed initrd..."
            lz4 -dc "$vendor_initrd" > "$TEMP_INITRD"
        elif file "$vendor_initrd" | grep -q "cpio archive"; then
            echo "Initrd is already uncompressed (cpio archive)..."
            cp "$vendor_initrd" "$TEMP_INITRD"
        else
            echo "Unknown compression format, assuming uncompressed..."
            cp "$vendor_initrd" "$TEMP_INITRD"
        fi
    fi
    
    # Inject QEMU-specific overrides if present
    if [ -d "$OVERRIDES_ROOT" ] && [ "$(ls -A "$OVERRIDES_ROOT" 2>/dev/null)" ]; then
        echo "Injecting QEMU-specific overrides:"
        echo "Temp initrd size before injection: $(stat -c%s "$TEMP_INITRD") bytes"
        
        # Create a temporary directory to extract and merge
        TEMP_EXTRACT_DIR=$(mktemp -d -t initrd-extract.XXXXXX)
        cd "$TEMP_EXTRACT_DIR" || exit 1
        
        # Extract vendor initrd
        echo "Extracting vendor initrd..."
        cpio -i < "$TEMP_INITRD" 2>/dev/null
        
        # Copy overrides
        echo "Copying overrides..."
        cp -r "$OVERRIDES_ROOT"/* . 2>/dev/null || true
        
        # Recreate the archive
        echo "Recreating merged initrd..."
        find . | cpio -o -H newc --owner=0:0 > "$TEMP_INITRD" -v
        
        cd - > /dev/null
        rm -rf "$TEMP_EXTRACT_DIR"
        
        echo "Temp initrd size after injection: $(stat -c%s "$TEMP_INITRD") bytes"
        echo "Verifying injection by listing temp initrd contents:"
        cpio -t < "$TEMP_INITRD" | tail -10
    else
        echo "No overrides found in $OVERRIDES_ROOT, skipping injection..."
    fi
    
    echo "Final verification before compression:"
    echo "Listing all files in temp initrd:"
    cpio -t < "$TEMP_INITRD" | grep -E "(fstab|init.*.rc)" || echo "No fstab/default files found in temp initrd"
    
    echo "Compressing QEMU initrd..."
    
    # Create output directory and compress
    mkdir -p "$OUT_KERNEL/boot"
    gzip -9c "$TEMP_INITRD" > "$OUT_KERNEL/boot/initrd-qemu.img"
    
    echo "QEMU initrd built successfully: $OUT_KERNEL/boot/initrd-qemu.img"
}

# Build debug initrd from scratch
build_debug_initrd() {
    echo "Building debug initrd..."
    
    # Create temporary directories
    TEMP_DIR=$(mktemp -d -t debug-initrd.XXXXXX)
    TEMP_INITRD=$(mktemp -t debug-initrd-build.XXXXXX)
    
    cd "$TEMP_DIR" || exit 1
    
    # Copy all binaries from BINARIES_ROOT if it exists and has content
    if [ -d "$BINARIES_ROOT" ] && [ "$(ls -A "$BINARIES_ROOT" 2>/dev/null)" ]; then
        echo "Copying binaries from $BINARIES_ROOT..."
        mkdir -p bin
        cp -r "$BINARIES_ROOT"/* bin/ 2>/dev/null || {
            echo "Warning: Failed to copy some binaries, copying individual files..."
            find "$BINARIES_ROOT" -type f -executable -exec cp {} bin/ \; 2>/dev/null || true
        }
    else
        echo "Warning: No binaries found in $BINARIES_ROOT, skipping bin directory creation..."
    fi
    
    # Copy init script from inits directory if it exists
    if [ -f "$INITS_ROOT/init.debug.rc" ]; then
        cp "$INITS_ROOT/init.debug.rc" init
        chmod 755 init
    else
        echo "Warning: init.debug.rc not found in $INITS_ROOT, skipping init script..."
    fi
        
    # Set permissions for all binaries if bin directory exists
    if [ -d "bin" ] && [ "$(ls -A bin 2>/dev/null)" ]; then
        chmod 755 bin/* || true
    fi
    
    echo "Creating base debug initrd..."
    
    # Create initial initrd with root ownership (no overrides for debug)
    find . | cpio -o -H newc --owner=0:0 > "$TEMP_INITRD"
    
    echo "Compressing debug initrd..."
    
    # Create output directory and compress
    mkdir -p "$OUT_KERNEL/boot"
    gzip -9c "$TEMP_INITRD" > "$OUT_KERNEL/boot/initrd_debug.img"
    
    echo "Debug initrd built successfully: $OUT_KERNEL/boot/initrd_debug.img"
}

# Show usage
show_usage() {
    echo "Usage: $0 [qemu|debug]"
    echo ""
    echo "Parameters:"
    echo "  qemu    - Build QEMU initrd only"
    echo "  debug   - Build debug initrd only"
    echo "  (none)  - Build both QEMU and debug initrds"
    echo ""
}

# Main execution
case "${1:-all}" in
    "qemu")
        build_qemu_initrd
        ;;
    "debug")
        build_debug_initrd
        ;;
    "all"|"")
        build_qemu_initrd
        echo ""
        build_debug_initrd
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        echo "Error: Unknown parameter '$1'"
        echo ""
        show_usage
        exit 1
        ;;
esac

echo ""
echo "Build complete!"