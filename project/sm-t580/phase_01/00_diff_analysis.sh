#!/bin/bash
# Unified Diff Analyzer for Samsung SM-T580 Kernel
# Works with "diff -Naur" format

DIFF_FILE="$1"
OUTPUT_DIR="unified_analysis_$(date +%Y%m%d_%H%M%S)"

if [ ! -f "$DIFF_FILE" ]; then
    echo "Usage: $0 <samsung_unified_diff.txt>"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "=== Samsung SM-T580 Unified Diff Analysis ==="
echo "Diff file: $DIFF_FILE"
echo "Output directory: $OUTPUT_DIR"

# Extract file list from unified diff format
echo -e "\n=== EXTRACTING FILE LIST ==="
grep "^diff -" "../$DIFF_FILE" | awk '{print $4}' | sed 's|samsung/||' | sort > all_changed_files.txt

echo "Total files changed: $(wc -l < all_changed_files.txt)"

# Show first 20 files to verify extraction
echo -e "\nFirst 20 changed files:"
head -20 all_changed_files.txt

# Categorize files by subsystem
echo -e "\n=== SUBSYSTEM ANALYSIS ==="

# Device Tree files (Critical)
grep -E "\.(dts|dtsi)$" all_changed_files.txt > devicetree_files.txt
DT_COUNT=$(wc -l < devicetree_files.txt)
echo "Device Tree files: $DT_COUNT"
if [ $DT_COUNT -gt 0 ]; then
    echo "  Device tree files found:"
    cat devicetree_files.txt | sed 's/^/    /'
fi

# Android-specific configs
grep "android.*configs" all_changed_files.txt > android_configs.txt
echo "Android config files: $(wc -l < android_configs.txt)"

# Drivers by category
grep "^drivers/video" all_changed_files.txt > display_files.txt
grep "^drivers/gpu" all_changed_files.txt >> display_files.txt
echo "Display drivers: $(wc -l < display_files.txt)"

grep "^sound/" all_changed_files.txt > audio_files.txt
grep "^drivers/media/" all_changed_files.txt >> audio_files.txt  
echo "Audio/Media drivers: $(wc -l < audio_files.txt)"

grep "^drivers/input/" all_changed_files.txt > input_files.txt
echo "Input drivers: $(wc -l < input_files.txt)"

grep "^drivers/power/" all_changed_files.txt > power_files.txt
grep "^drivers/battery/" all_changed_files.txt >> power_files.txt
echo "Power/Battery drivers: $(wc -l < power_files.txt)"

grep "^arch/arm/" all_changed_files.txt > arch_files.txt
echo "ARM architecture files: $(wc -l < arch_files.txt)"

grep "^drivers/clk/" all_changed_files.txt > clock_files.txt
echo "Clock drivers: $(wc -l < clock_files.txt)"

grep "^drivers/net/wireless/" all_changed_files.txt > wireless_files.txt
echo "Wireless drivers: $(wc -l < wireless_files.txt)"

# Look for Samsung/Exynos specific files
echo -e "\n=== SAMSUNG/EXYNOS SPECIFIC ==="
grep -i "exynos\|samsung" all_changed_files.txt > samsung_specific.txt
echo "Samsung/Exynos specific files: $(wc -l < samsung_specific.txt)"
if [ -s samsung_specific.txt ]; then
    echo "  Key Samsung files:"
    head -10 samsung_specific.txt | sed 's/^/    /'
fi

# Look for SM-T580 specific references
grep -i "t580\|gtaxl" all_changed_files.txt > t580_specific.txt
echo "SM-T580 specific files: $(wc -l < t580_specific.txt)"
if [ -s t580_specific.txt ]; then
    echo "  SM-T580 files:"
    cat t580_specific.txt | sed 's/^/    /'
fi

# Extract important patches manually for unified diff
echo -e "\n=== EXTRACTING KEY PATCHES ==="

# Function to extract unified diff section for specific files
extract_unified_patch() {
    local pattern="$1"
    local output_file="$2"
    local description="$3"
    
    echo "Extracting $description..."
    awk -v pat="$pattern" '
    BEGIN { printing=0 }
    /^diff -/ { 
        if ($4 ~ pat) {
            printing=1
            print
        } else {
            printing=0
        }
    }
    printing==1 && !/^diff -/ { print }
    ' "../$DIFF_FILE" > "$output_file"
    
    local lines=$(wc -l < "$output_file")
    echo "  -> $output_file ($lines lines)"
    return $lines
}

# Extract Android configs (these show what features Samsung enabled)
extract_unified_patch "android.*configs" "01_android_configs_CRITICAL.patch" "Android configuration changes"

# Extract device tree if any
if [ -s devicetree_files.txt ]; then
    extract_unified_patch "\.(dts|dtsi)$" "02_devicetree_CRITICAL.patch" "Device tree changes"
fi

# Extract architecture files
if [ -s arch_files.txt ]; then
    extract_unified_patch "^arch/arm/" "03_architecture_HIGH.patch" "ARM architecture changes"
fi

# Extract display drivers
if [ -s display_files.txt ]; then
    extract_unified_patch "drivers/(video|gpu)" "04_display_HIGH.patch" "Display driver changes"
fi

# Extract clock drivers
if [ -s clock_files.txt ]; then
    extract_unified_patch "drivers/clk" "05_clock_HIGH.patch" "Clock driver changes"
fi

# Extract audio drivers
if [ -s audio_files.txt ]; then
    extract_unified_patch "(sound|drivers/media)" "06_audio_MEDIUM.patch" "Audio/media driver changes"
fi

# Extract input drivers
if [ -s input_files.txt ]; then
    extract_unified_patch "drivers/input" "07_input_MEDIUM.patch" "Input driver changes"
fi

# Extract power management
if [ -s power_files.txt ]; then
    extract_unified_patch "drivers/(power|battery)" "08_power_MEDIUM.patch" "Power management changes"
fi

# Look for Samsung-specific additions
echo -e "\n=== ANALYZING SAMSUNG ADDITIONS ==="

# Count new files vs modified files
NEW_FILES=$(grep -c "1970-01-01" "../$DIFF_FILE")
echo "New files added by Samsung: $NEW_FILES"

# Look for Android-specific features in the main config
echo -e "\nAndroid features enabled by Samsung:"
if [ -f "01_android_configs_CRITICAL.patch" ]; then
    grep "^+CONFIG_" "01_android_configs_CRITICAL.patch" | head -20 | sed 's/^+/  /'
fi

# Generate analysis summary
echo -e "\n=== ANALYSIS SUMMARY ==="
cat > SAMSUNG_ANALYSIS_SUMMARY.md << EOF
# Samsung SM-T580 Kernel Analysis Summary

## Key Findings:
- **Total files changed**: $(wc -l < all_changed_files.txt)
- **New files added by Samsung**: $NEW_FILES  
- **Device tree files**: $(wc -l < devicetree_files.txt)
- **Samsung/Exynos specific files**: $(wc -l < samsung_specific.txt)
- **SM-T580 specific files**: $(wc -l < t580_specific.txt)

## Extracted Patches (by priority):
1. **01_android_configs_CRITICAL.patch** - Android configuration changes
2. **02_devicetree_CRITICAL.patch** - Hardware definitions  
3. **03_architecture_HIGH.patch** - ARM/Exynos platform code
4. **04_display_HIGH.patch** - Display controller drivers
5. **05_clock_HIGH.patch** - Clock management
6. **06_audio_MEDIUM.patch** - Audio subsystem
7. **07_input_MEDIUM.patch** - Touch and input devices
8. **08_power_MEDIUM.patch** - Power and battery management

## Next Steps for Modern Kernel Port:
1. **Start with Android configs** - understand what Samsung enabled
2. **Extract hardware info** from device tree changes
3. **Focus on platform code** - Exynos 7870 specific initialization
4. **Adapt display drivers** - likely most complex porting task

## Key Files to Examine First:
EOF

# Add top Samsung-specific files to summary
if [ -s samsung_specific.txt ]; then
    echo "- Samsung/Exynos files:" >> SAMSUNG_ANALYSIS_SUMMARY.md
    head -5 samsung_specific.txt | sed 's/^/  - /' >> SAMSUNG_ANALYSIS_SUMMARY.md
fi

if [ -s t580_specific.txt ]; then
    echo "- SM-T580 specific files:" >> SAMSUNG_ANALYSIS_SUMMARY.md
    cat t580_specific.txt | sed 's/^/  - /' >> SAMSUNG_ANALYSIS_SUMMARY.md
fi

echo "Analysis complete!"
echo "Key outputs:"
echo "  - SAMSUNG_ANALYSIS_SUMMARY.md (overview)"
echo "  - 01_android_configs_CRITICAL.patch (what Samsung enabled)"
echo "  - Individual subsystem patches for detailed analysis"

echo -e "\nRecommended next steps:"
echo "1. cat SAMSUNG_ANALYSIS_SUMMARY.md"
echo "2. less 01_android_configs_CRITICAL.patch"
echo "3. Examine device tree and architecture patches"
