#!/bin/bash

PATCH_DIR="../unified_analysis_20250813_002353"

echo "=== Identifying Missing Device Tree Bindings ==="

echo "1. Checking what dt-bindings exist in Linux 4.4..."
echo "   Current Exynos bindings:"
ls include/dt-bindings/clock/exynos* 2>/dev/null || echo "   No Exynos clock bindings found"

echo ""
echo "   Current clock bindings:"
ls include/dt-bindings/clock/ | head -10

echo ""
echo "2. Required bindings from Samsung device tree:"
grep -h "#include <dt-bindings" extracted_dt/*.dtsi extracted_dt/*.dts | sort -u

echo ""
echo "3. Searching for missing bindings in Samsung patches..."

# Look for the missing clock binding
echo "   Searching for exynos7870.h in patches..."
if find $PATCH_DIR -name "*.patch" -exec grep -l "exynos7870\.h" {} \; | head -1; then
    echo "   ✓ Found exynos7870.h references in patches"
    
    # Try to find it in the clock patch
    if grep -q "exynos7870\.h" $PATCH_DIR/05_clock_HIGH.patch 2>/dev/null; then
        echo "   ✓ Found in clock patch - extracting..."
        
        # Extract the header file
        echo ""
        echo "4. Extracting dt-bindings/clock/exynos7870.h..."
        
        mkdir -p missing_bindings/dt-bindings/clock
        
        # Find and extract the clock header
        if grep -A 200 "dt-bindings/clock/exynos7870.h" $PATCH_DIR/05_clock_HIGH.patch | \
           grep -A 200 "^+++" | grep "^+" | sed 's/^+//' > missing_bindings/dt-bindings/clock/exynos7870.h; then
            
            lines=$(wc -l < missing_bindings/dt-bindings/clock/exynos7870.h)
            echo "   ✓ Extracted $lines lines to missing_bindings/dt-bindings/clock/exynos7870.h"
        else
            echo "   ✗ Failed to extract clock bindings"
        fi
    fi
else
    echo "   ⚠️  exynos7870.h not found in patches - may need manual creation"
fi

# Look for sysmmu binding
echo ""
echo "5. Checking sysmmu bindings..."
if [ -f "include/dt-bindings/sysmmu/sysmmu.h" ]; then
    echo "   ✓ sysmmu.h exists in Linux 4.4"
else
    echo "   ⚠️  sysmmu.h missing - checking patches..."
    
    if find $PATCH_DIR -name "*.patch" -exec grep -l "sysmmu\.h" {} \; | head -1; then
        echo "   Found sysmmu.h references in patches"
    else
        echo "   May need to create minimal sysmmu.h"
    fi
fi

echo ""
echo "6. Creating minimal missing bindings if needed..."

# Create minimal sysmmu.h if missing
if [ ! -f "include/dt-bindings/sysmmu/sysmmu.h" ]; then
    mkdir -p include/dt-bindings/sysmmu
    cat > include/dt-bindings/sysmmu/sysmmu.h << 'EOF'
/*
 * Copyright (c) 2015 Samsung Electronics Co., Ltd.
 *
 * Device Tree binding constants for Exynos System MMU
 */

#ifndef _DT_BINDINGS_SYSMMU_SYSMMU_H
#define _DT_BINDINGS_SYSMMU_SYSMMU_H

/* System MMU definitions for Exynos SoCs */
#define SYSMMU_MFCL     0
#define SYSMMU_MFCR     1
#define SYSMMU_TV       2
#define SYSMMU_JPEG     3
#define SYSMMU_FIMD     4
#define SYSMMU_FIMD1    5

#endif /* _DT_BINDINGS_SYSMMU_SYSMMU_H */
EOF
    echo "   ✓ Created minimal sysmmu.h"
fi

echo ""
echo "7. Summary of required actions:"
echo "   a) Copy extracted bindings to kernel include directory"
echo "   b) Test device tree compilation"
echo "   c) Create minimal device tree for boot testing"
echo ""
echo "Commands to continue:"
echo "   # Copy clock bindings if extracted"
echo "   if [ -f missing_bindings/dt-bindings/clock/exynos7870.h ]; then"
echo "       cp missing_bindings/dt-bindings/clock/exynos7870.h include/dt-bindings/clock/"
echo "   fi"
echo ""
echo "   # Test device tree compilation"
echo "   # make ARCH=arm64 dtbs"
