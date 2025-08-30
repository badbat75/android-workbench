#!/bin/bash

echo "=== Diagnosing and Fixing Build Errors ==="

echo "1. Investigating ARM64 assembly error..."
echo "   Error location: arch/arm64/mm/proc.S:155"
echo "   Error: junk at end of line, first unrecognized character is '#'"

# Check the problematic line
if [ -f "arch/arm64/mm/proc.S" ]; then
    echo ""
    echo "   Lines around error (150-160):"
    sed -n '150,160p' arch/arm64/mm/proc.S | nl -v150
    echo ""
    
    echo "   Looking for the specific error..."
    # Check for any unusual characters or syntax issues
    sed -n '155p' arch/arm64/mm/proc.S | cat -A
else
    echo "   ⚠️  proc.S file not found"
fi

echo ""
echo "2. Checking cross-compiler compatibility..."
echo "   Cross-compiler: ${CROSS_COMPILE}aarch64-linux-gnu-gcc"

if command -v aarch64-linux-gnu-gcc > /dev/null 2>&1; then
    echo "   Compiler version: $(aarch64-linux-gnu-gcc --version | head -1)"
    echo "   ✓ Cross-compiler available"
else
    echo "   ❌ Cross-compiler not found - this could be the issue!"
    echo "   Installing cross-compiler..."
    
    # Check what package manager is available
    if command -v apt > /dev/null 2>&1; then
        sudo apt update && sudo apt install -y gcc-aarch64-linux-gnu
    elif command -v dnf > /dev/null 2>&1; then
        sudo dnf install -y gcc-aarch64-linux-gnu
    elif command -v yum > /dev/null 2>&1; then
        sudo yum install -y gcc-aarch64-linux-gnu
    else
        echo "   Please install gcc-aarch64-linux-gnu manually"
    fi
fi

echo ""
echo "3. Checking kernel configuration for assembly issues..."

# Look for any config options that might cause assembly problems
echo "   Checking for problematic config options..."
if grep -q "CONFIG_THUMB2_KERNEL=y" .config; then
    echo "   ⚠️  THUMB2 enabled - this could cause ARM64 assembly issues"
    sed -i 's/CONFIG_THUMB2_KERNEL=y/# CONFIG_THUMB2_KERNEL is not set/' .config
fi

if grep -q "CONFIG_ARM64_MODULE_PLTS=y" .config; then
    echo "   ✓ ARM64 module PLTs enabled - this is correct"
else
    echo "   Adding ARM64 module PLTs support..."
    echo "CONFIG_ARM64_MODULE_PLTS=y" >> .config
fi

echo ""
echo "4. Trying clean rebuild with fixed configuration..."

# Clean and try rebuilding
make ARCH=arm64 clean
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

echo "   Attempting kernel build with clean state..."
if make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image -j1 2>/tmp/clean_build_log; then
    echo "   ✅ Clean build succeeded!"
    echo "   Kernel Image: $(ls -lh arch/arm64/boot/Image | awk '{print $5}')"
else
    echo "   ⚠️  Clean build still failing. Checking errors..."
    
    # Show specific error
    echo "   Last 10 lines of build log:"
    tail -10 /tmp/clean_build_log | sed 's/^/      /'
    
    echo ""
    echo "   Checking if this is a known ARM64 issue..."
    
    # Check if the error is in a specific area
    if grep -q "proc.S.*Error" /tmp/clean_build_log; then
        echo "   Issue is in ARM64 memory management assembly"
        echo "   This might be a toolchain compatibility issue"
        
        # Try with different compiler flags
        echo "   Trying with compatible assembly flags..."
        make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CFLAGS_KERNEL="-mgeneral-regs-only" Image -j1 2>/tmp/compat_build_log
        
        if [ $? -eq 0 ]; then
            echo "   ✅ Compatible build succeeded!"
        else
            echo "   Still failing - checking alternative approach..."
        fi
    fi
fi

echo ""
echo "5. Fixing device tree syntax error..."

echo "   Checking device tree syntax..."
if [ -f "arch/arm64/boot/dts/exynos/exynos7870-gtaxl-minimal.dts" ]; then
    echo "   Current device tree content:"
    head -10 arch/arm64/boot/dts/exynos/exynos7870-gtaxl-minimal.dts
    
    echo ""
    echo "   Creating corrected device tree..."
    
    # Create a properly formatted device tree
    cat > arch/arm64/boot/dts/exynos/exynos7870-gtaxl-minimal.dts << 'EOF'
/dts-v1/;

/ {
    compatible = "samsung,gtaxl", "samsung,exynos7870";
    #address-cells = <2>;
    #size-cells = <1>;

    model = "Samsung Galaxy Tab A 10.1 WiFi (2016)";

    chosen {
        bootargs = "console=ttySAC1,115200n8 earlyprintk";
        stdout-path = "/soc/serial@13810000:115200n8";
    };

    memory@40000000 {
        device_type = "memory";
        reg = <0x0 0x40000000 0x80000000>;
    };

    cpus {
        #address-cells = <2>;
        #size-cells = <0>;

        cpu0: cpu@0 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x0>;
            enable-method = "psci";
        };

        cpu1: cpu@1 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x1>;
            enable-method = "psci";
        };

        cpu2: cpu@2 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x2>;
            enable-method = "psci";
        };

        cpu3: cpu@3 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x3>;
            enable-method = "psci";
        };

        cpu4: cpu@100 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x100>;
            enable-method = "psci";
        };

        cpu5: cpu@101 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x101>;
            enable-method = "psci";
        };

        cpu6: cpu@102 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x102>;
            enable-method = "psci";
        };

        cpu7: cpu@103 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x103>;
            enable-method = "psci";
        };
    };

    psci {
        compatible = "arm,psci-0.2";
        method = "smc";
    };

    timer {
        compatible = "arm,armv8-timer";
        interrupts = <1 13 0xff08>,
                     <1 14 0xff08>,
                     <1 11 0xff08>,
                     <1 10 0xff08>;
    };

    soc {
        compatible = "simple-bus";
        #address-cells = <2>;
        #size-cells = <1>;
        ranges;

        gic: interrupt-controller@12300000 {
            compatible = "arm,gic-400";
            #interrupt-cells = <3>;
            #address-cells = <0>;
            interrupt-controller;
            reg = <0x0 0x12301000 0x1000>,
                  <0x0 0x12302000 0x2000>,
                  <0x0 0x12304000 0x2000>,
                  <0x0 0x12306000 0x2000>;
            interrupts = <1 9 0xf04>;
        };

        serial@13810000 {
            compatible = "samsung,exynos4210-uart";  
            reg = <0x0 0x13810000 0x100>;
            interrupts = <0 247 0>;
            status = "okay";
        };
    };
};
EOF

    echo "   ✓ Created corrected device tree"
else
    echo "   ⚠️  Device tree file not found"
fi

echo ""
echo "6. Testing device tree compilation..."

# Remove the problematic Makefile entry and add a clean one
sed -i '/exynos7870.*minimal/d' arch/arm64/boot/dts/exynos/Makefile 2>/dev/null
echo 'dtb-\$(CONFIG_ARCH_EXYNOS) += exynos7870-gtaxl-minimal.dtb' >> arch/arm64/boot/dts/exynos/Makefile

# Test device tree compilation directly
echo "   Testing dtc compilation..."
if dtc -I dts -O dtb -o /tmp/test_minimal.dtb arch/arm64/boot/dts/exynos/exynos7870-gtaxl-minimal.dts 2>/tmp/dtc_test_log; then
    echo "   ✅ Device tree syntax is now correct!"
    echo "   Test DTB size: $(ls -lh /tmp/test_minimal.dtb | awk '{print $5}')"
    
    # Copy the working DTB
    cp /tmp/test_minimal.dtb arch/arm64/boot/dts/exynos/exynos7870-gtaxl-minimal.dtb
else
    echo "   ⚠️  Device tree still has issues:"
    cat /tmp/dtc_test_log | sed 's/^/      /'
fi

echo ""
echo "7. Creating working boot package..."

# Update boot package
mkdir -p boot_package_fixed

# Copy kernel if available
if [ -f "arch/arm64/boot/Image" ]; then
    cp arch/arm64/boot/Image boot_package_fixed/
    echo "   ✅ Kernel Image: $(ls -lh arch/arm64/boot/Image | awk '{print $5}')"
else
    echo "   ⚠️  Kernel Image still needs to be built"
fi

# Copy device tree if available
if [ -f "arch/arm64/boot/dts/exynos/exynos7870-gtaxl-minimal.dtb" ]; then
    cp arch/arm64/boot/dts/exynos/exynos7870-gtaxl-minimal.dtb boot_package_fixed/sm-t580.dtb
    echo "   ✅ Device Tree: $(ls -lh arch/arm64/boot/dts/exynos/exynos7870-gtaxl-minimal.dtb | awk '{print $5}')"
elif [ -f "/tmp/test_minimal.dtb" ]; then
    cp /tmp/test_minimal.dtb boot_package_fixed/sm-t580.dtb
    echo "   ✅ Device Tree (from test): $(ls -lh /tmp/test_minimal.dtb | awk '{print $5}')"
fi

# Copy working config
cp .config boot_package_fixed/kernel.config

echo ""
echo "8. Summary and next steps..."

echo "   Current status:"
if [ -f "boot_package_fixed/Image" ] && [ -f "boot_package_fixed/sm-t580.dtb" ]; then
    echo "   ✅ COMPLETE: Both kernel and device tree ready!"
    echo ""
    echo "   🎉 SUCCESS! Ready for hardware testing!"
elif [ -f "boot_package_fixed/sm-t580.dtb" ]; then
    echo "   ✅ Device tree fixed!"
    echo "   ⚠️  Kernel build needs resolution"
    echo ""
    echo "   Next: Fix kernel assembly issue"
else
    echo "   ⚠️  Both kernel and device tree need work"
    echo ""
    echo "   Next: Address assembly and syntax issues"
fi

echo ""
echo "   Debug information:"
echo "   - Build logs: /tmp/*build_log"
echo "   - Device tree test: /tmp/dtc_test_log"  
echo "   - Assembly error: arch/arm64/mm/proc.S:155"

echo ""
echo "   To continue:"
echo "   1. Check cross-compiler installation"
echo "   2. Review assembly error in detail"
echo "   3. Consider using different kernel version if toolchain incompatible"
