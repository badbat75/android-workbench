#!/bin/bash

PATCH_DIR="../unified_analysis_20250813_002353"
DT_PATCH="$PATCH_DIR/02_devicetree_CRITICAL.patch"

echo "=== Extracting Samsung Device Tree Files ==="

# Create exynos directory structure
echo "1. Creating directory structure..."
mkdir -p arch/arm64/boot/dts/exynos
mkdir -p extracted_dt

echo "2. Extracting device tree files from patch..."

# Function to extract a specific file from the unified patch
extract_file() {
    local filename="$1"
    local output_path="$2"
    
    echo "   Extracting: $filename"
    
    # Find the start and end of this file in the patch
    local start_line=$(grep -n "^+++ samsung.*$filename" "$DT_PATCH" | cut -d: -f1)
    
    if [ -z "$start_line" ]; then
        echo "   ✗ File $filename not found in patch"
        return 1
    fi
    
    # Find the next file start (or end of patch)
    local next_start=$(tail -n +$((start_line + 1)) "$DT_PATCH" | grep -n "^diff -Naur\|^+++ samsung" | head -1 | cut -d: -f1)
    
    if [ -n "$next_start" ]; then
        local end_line=$((start_line + next_start - 1))
        sed -n "${start_line},${end_line}p" "$DT_PATCH" | grep "^+" | sed 's/^+//' > "$output_path"
    else
        # This is the last file in the patch
        tail -n +$start_line "$DT_PATCH" | grep "^+" | sed 's/^+//' > "$output_path"
    fi
    
    if [ -s "$output_path" ]; then
        local lines=$(wc -l < "$output_path")
        echo "   ✓ Extracted $lines lines to $output_path"
        return 0
    else
        echo "   ✗ Failed to extract $filename"
        return 1
    fi
}

echo ""
echo "3. Extracting core SoC files..."

# Extract main SoC definition
extract_file "exynos7870.dtsi" "extracted_dt/exynos7870.dtsi"

# Extract pinctrl
extract_file "exynos7870-pinctrl.dtsi" "extracted_dt/exynos7870-pinctrl.dtsi"

# Extract bus monitoring
extract_file "exynos7870-busmon.dtsi" "extracted_dt/exynos7870-busmon.dtsi"

# Extract memory configuration
extract_file "exynos7870-rmem-2000MB.dtsi" "extracted_dt/exynos7870-rmem-2000MB.dtsi"

echo ""
echo "4. Extracting SM-T580 tablet files..."

# Extract tablet common
extract_file "exynos7870-gtaxl_common.dtsi" "extracted_dt/exynos7870-gtaxl_common.dtsi"

# Extract main hardware variant
extract_file "exynos7870-gtaxlwifi_eur_open_00.dts" "extracted_dt/exynos7870-gtaxlwifi_eur_open_00.dts"

# Extract hardware revision variants
extract_file "exynos7870-gtaxlwifi_eur_open_04.dts" "extracted_dt/exynos7870-gtaxlwifi_eur_open_04.dts"
extract_file "exynos7870-gtaxlwifi_eur_open_05.dts" "extracted_dt/exynos7870-gtaxlwifi_eur_open_05.dts"

echo ""
echo "5. Extracting supporting files..."

# Extract GPIO configurations
extract_file "exynos7870-gtaxlwifi_eur_open_gpio_00.dtsi" "extracted_dt/exynos7870-gtaxlwifi_eur_open_gpio_00.dtsi"
extract_file "exynos7870-gtaxlwifi_eur_open_gpio_04.dtsi" "extracted_dt/exynos7870-gtaxlwifi_eur_open_gpio_04.dtsi"
extract_file "exynos7870-gtaxlwifi_eur_open_gpio_05.dtsi" "extracted_dt/exynos7870-gtaxlwifi_eur_open_gpio_05.dtsi"

# Extract battery configurations
extract_file "exynos7870-gtaxlwifi_eur_open_battery_00.dtsi" "extracted_dt/exynos7870-gtaxlwifi_eur_open_battery_00.dtsi"
extract_file "exynos7870-gtaxlwifi_eur_open_battery_04.dtsi" "extracted_dt/exynos7870-gtaxlwifi_eur_open_battery_04.dtsi"
extract_file "exynos7870-gtaxlwifi_eur_open_battery_05.dtsi" "extracted_dt/exynos7870-gtaxlwifi_eur_open_battery_05.dtsi"

echo ""
echo "6. Analysis of extracted files..."
echo "   Files extracted to extracted_dt/ directory:"
ls -la extracted_dt/ 2>/dev/null || echo "   No files extracted successfully"

echo ""
echo "7. Checking for dependencies..."
if [ -f "extracted_dt/exynos7870.dtsi" ]; then
    echo "   Checking includes in main SoC file:"
    grep "^#include" extracted_dt/exynos7870.dtsi | head -5
    
    echo ""
    echo "   File sizes:"
    wc -l extracted_dt/*.dtsi extracted_dt/*.dts 2>/dev/null | tail -1
fi

echo ""
echo "8. Next steps:"
echo "   a) Review extracted files for Linux 4.4 compatibility"
echo "   b) Check for missing includes (dt-bindings, etc.)"
echo "   c) Create minimal device tree for boot testing"
echo "   d) Copy files to proper kernel locations"
echo ""
echo "Commands to continue:"
echo "   # Review main SoC file"
echo "   less extracted_dt/exynos7870.dtsi"
echo ""
echo "   # Check for required clock bindings"
echo "   grep 'dt-bindings' extracted_dt/exynos7870.dtsi"
echo ""
echo "   # Copy to kernel source when ready"
echo "   # cp extracted_dt/exynos7870*.dtsi arch/arm64/boot/dts/exynos/"
