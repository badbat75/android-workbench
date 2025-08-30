#!/bin/bash

echo "=== Cleaning and Validating Device Tree Files ==="

# Clean up the extracted files
echo "1. Cleaning patch headers from extracted files..."
for file in extracted_dt/*.dtsi extracted_dt/*.dts; do
    if [ -f "$file" ]; then
        # Remove the patch header line (starts with ++)
        sed -i '1{/^++.*samsung.*\.dt[si]/d;}' "$file"
        echo "   ✓ Cleaned $(basename $file)"
    fi
done

echo ""
echo "2. Validating cleaned files..."
for file in extracted_dt/*.dtsi extracted_dt/*.dts; do
    if [ -f "$file" ]; then
        # Check first few lines look like proper device tree
        if head -5 "$file" | grep -q "SAMSUNG\|compatible\|#include"; then
            echo "   ✓ $(basename $file) - Valid device tree format"
        else
            echo "   ⚠️  $(basename $file) - May need manual review"
            echo "      First lines:"
            head -3 "$file" | sed 's/^/         /'
        fi
    fi
done

echo ""
echo "3. Checking required dependencies..."

# Check what dt-bindings we need
echo "   Required dt-bindings header files:"
find extracted_dt/ -name "*.dtsi" -o -name "*.dts" | xargs grep "#include <dt-bindings" | \
    sed 's/.*#include <\(.*\)>.*/\1/' | sort -u | while read binding; do
    echo "   - $binding"
    
    # Check if it exists in current kernel
    if [ -f "include/dt-bindings/$binding" ]; then
        echo "     ✓ Available in Linux 4.4"
    else
        echo "     ✗ MISSING - Need to create/port"
    fi
done

echo ""
echo "4. Analyzing device tree structure..."
echo "   Main SoC file structure:"
if [ -f "extracted_dt/exynos7870.dtsi" ]; then
    echo "   - CPU cores: $(grep -c "cpu@" extracted_dt/exynos7870.dtsi)"
    echo "   - Clock controllers: $(grep -c "clock" extracted_dt/exynos7870.dtsi)"
    echo "   - GPIO controllers: $(grep -c "gpio" extracted_dt/exynos7870.dtsi)"
    echo "   - Serial ports: $(grep -c "serial" extracted_dt/exynos7870.dtsi)"
    echo "   - Memory controllers: $(grep -c "memory" extracted_dt/exynos7870.dtsi)"
fi

echo ""
echo "5. Creating cleaned copies for kernel integration..."
mkdir -p cleaned_dt

# Copy cleaned files
for file in extracted_dt/*.dtsi extracted_dt/*.dts; do
    if [ -f "$file" ]; then
        cp "$file" "cleaned_dt/$(basename $file)"
    fi
done

echo "   ✓ Cleaned files available in cleaned_dt/"

echo ""
echo "6. Testing device tree syntax..."
if command -v dtc > /dev/null 2>&1; then
    echo "   Testing basic syntax with dtc..."
    # Test the main SoC file (this will likely fail due to missing bindings, but shows syntax issues)
    if dtc -I dts -O dtb cleaned_dt/exynos7870.dtsi > /tmp/test.dtb 2>/tmp/dtc_errors; then
        echo "   ✓ Basic syntax appears correct"
    else
        echo "   ⚠️  Syntax errors or missing dependencies:"
        head -10 /tmp/dtc_errors | sed 's/^/      /'
        echo "      (This is expected due to missing includes)"
    fi
else
    echo "   ⚠️  dtc not available for syntax testing"
fi

echo ""
echo "7. Next steps for integration:"
echo "   a) Create missing dt-bindings header files"
echo "   b) Copy cleaned device tree files to kernel"
echo "   c) Add to device tree Makefile"
echo "   d) Test compilation"
echo ""
echo "Commands to continue:"
echo "   # Review cleaned main SoC file"
echo "   less cleaned_dt/exynos7870.dtsi"
echo ""
echo "   # Check missing bindings"
echo "   ls include/dt-bindings/clock/ | grep exynos"
echo ""
echo "   # Copy to kernel when ready"
echo "   # cp cleaned_dt/*.dtsi arch/arm64/boot/dts/exynos/"
echo "   # cp cleaned_dt/exynos7870-gtaxlwifi_eur_open_00.dts arch/arm64/boot/dts/exynos/"
