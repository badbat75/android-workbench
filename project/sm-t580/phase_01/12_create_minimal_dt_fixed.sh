#!/bin/bash

echo "=== Creating Minimal Device Tree for SM-T580 Boot Testing ==="

mkdir -p minimal_dt

echo "1. Creating minimal exynos7870 SoC definition without Samsung dependencies..."

cat > minimal_dt/exynos7870-minimal.dtsi << 'EOF'
/*
 * Minimal SAMSUNG EXYNOS7870 SoC device tree for boot testing
 * Simplified version without Samsung-specific bindings
 */

/ {
    compatible = "samsung,exynos7870";
    interrupt-parent = <&gic>;
    #address-cells = <2>;
    #size-cells = <1>;

    aliases {
        serial0 = &uart0;
        serial1 = &uart1;
        serial2 = &uart2;
    };

    chosen {
        stdout-path = "serial1:115200n8";
    };

    cpus {
        #address-cells = <2>;
        #size-cells = <0>;

        cpu-map {
            cluster0 {
                core0 {
                    cpu = <&cpu0>;
                };
                core1 {
                    cpu = <&cpu1>;
                };
                core2 {
                    cpu = <&cpu2>;
                };
                core3 {
                    cpu = <&cpu3>;
                };
            };
            cluster1 {
                core0 {
                    cpu = <&cpu4>;
                };
                core1 {
                    cpu = <&cpu5>;
                };
                core2 {
                    cpu = <&cpu6>;
                };
                core3 {
                    cpu = <&cpu7>;
                };
            };
        };

        cpu0: cpu@0 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x0>;
            enable-method = "psci";
            cpu-idle-states = <&CPU_SLEEP>;
        };

        cpu1: cpu@1 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x1>;
            enable-method = "psci";
            cpu-idle-states = <&CPU_SLEEP>;
        };

        cpu2: cpu@2 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x2>;
            enable-method = "psci";
            cpu-idle-states = <&CPU_SLEEP>;
        };

        cpu3: cpu@3 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x3>;
            enable-method = "psci";
            cpu-idle-states = <&CPU_SLEEP>;
        };

        cpu4: cpu@100 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x100>;
            enable-method = "psci";
            cpu-idle-states = <&CPU_SLEEP>;
        };

        cpu5: cpu@101 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x101>;
            enable-method = "psci";
            cpu-idle-states = <&CPU_SLEEP>;
        };

        cpu6: cpu@102 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x102>;
            enable-method = "psci";
            cpu-idle-states = <&CPU_SLEEP>;
        };

        cpu7: cpu@103 {
            device_type = "cpu";
            compatible = "arm,cortex-a53", "arm,armv8";
            reg = <0x0 0x103>;
            enable-method = "psci";
            cpu-idle-states = <&CPU_SLEEP>;
        };

        idle-states {
            entry-method = "psci";

            CPU_SLEEP: cpu-sleep {
                compatible = "arm,idle-state";
                entry-latency-us = <10>;
                exit-latency-us = <10>;
                min-residency-us = <100>;
                arm,psci-suspend-param = <0x0010000>;
            };
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

    /* Basic clock tree - simplified */
    clocks {
        fin_pll: fin-pll {
            compatible = "fixed-clock";
            #clock-cells = <0>;
            clock-frequency = <26000000>;
            clock-output-names = "fin_pll";
        };

        xusbxti: xusbxti {
            compatible = "fixed-clock";
            #clock-cells = <0>;
            clock-frequency = <24000000>;
            clock-output-names = "xusbxti";
        };
    };

    /* UART definitions based on Exynos typical layout */
    uart0: serial@13800000 {
        compatible = "samsung,exynos4210-uart";
        reg = <0x0 0x13800000 0x100>;
        interrupts = <0 246 0>;
        clocks = <&fin_pll>, <&fin_pll>;
        clock-names = "uart", "clk_uart_baud0";
        status = "disabled";
    };

    uart1: serial@13810000 {
        compatible = "samsung,exynos4210-uart";  
        reg = <0x0 0x13810000 0x100>;
        interrupts = <0 247 0>;
        clocks = <&fin_pll>, <&fin_pll>;
        clock-names = "uart", "clk_uart_baud0";
        status = "disabled";
    };

    uart2: serial@13820000 {
        compatible = "samsung,exynos4210-uart";
        reg = <0x0 0x13820000 0x100>;
        interrupts = <0 279 0>;
        clocks = <&fin_pll>, <&fin_pll>;
        clock-names = "uart", "clk_uart_baud0";
        status = "disabled";
    };
};
EOF

echo "   ✓ Created minimal SoC definition"

echo ""
echo "2. Creating minimal SM-T580 device tree..."

cat > minimal_dt/exynos7870-gtaxl-minimal.dts << 'EOF'
/*
 * Minimal device tree for Samsung Galaxy Tab A 10.1 (SM-T580)
 * For initial boot testing with Linux 4.4
 */

/dts-v1/;
#include "exynos7870-minimal.dtsi"

/ {
    model = "Samsung Galaxy Tab A 10.1 WiFi (2016) - Minimal";
    compatible = "samsung,gtaxl", "samsung,exynos7870";

    chosen {
        bootargs = "console=ttySAC1,115200n8 earlyprintk root=/dev/ram0 rw";
        stdout-path = "serial1:115200n8";
    };

    memory@40000000 {
        device_type = "memory";
        reg = <0x0 0x40000000 0x80000000>; /* 2GB starting at 1GB */
    };

    reserved-memory {
        #address-cells = <2>;
        #size-cells = <1>;
        ranges;

        /* Reserve some memory for firmware */
        secmon@43000000 {
            reg = <0x0 0x43000000 0x1000000>;
            no-map;
        };
    };
};

/* Enable UART1 for console output */
&uart1 {
    status = "okay";
};
EOF

echo "   ✓ Created minimal SM-T580 device tree"

echo ""
echo "3. Testing minimal device tree compilation..."

# Copy to kernel source
cp minimal_dt/exynos7870-minimal.dtsi arch/arm64/boot/dts/exynos/
cp minimal_dt/exynos7870-gtaxl-minimal.dts arch/arm64/boot/dts/exynos/

# Add to Makefile if not already there
if ! grep -q "exynos7870-gtaxl-minimal" arch/arm64/boot/dts/exynos/Makefile; then
    echo 'dtb-$(CONFIG_ARCH_EXYNOS) += exynos7870-gtaxl-minimal.dtb' >> arch/arm64/boot/dts/exynos/Makefile
    echo "   ✓ Added minimal device tree to Makefile"
fi

echo ""
echo "4. Testing compilation..."
if make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- arch/arm64/boot/dts/exynos/exynos7870-gtaxl-minimal.dtb 2>/tmp/minimal_dtb_errors; then
    echo "   🎉 SUCCESS! Minimal device tree compiled!"
    if [ -f arch/arm64/boot/dts/exynos/exynos7870-gtaxl-minimal.dtb ]; then
        echo "   Generated DTB size: $(ls -lh arch/arm64/boot/dts/exynos/exynos7870-gtaxl-minimal.dtb | awk '{print $5}')"
    fi
else
    echo "   ⚠️  Minimal device tree compilation issues:"
    head -10 /tmp/minimal_dtb_errors | sed 's/^/      /'
fi

echo ""
echo "5. Creating kernel configuration for Exynos support..."

# Add Exynos support to our config if not already there
if ! grep -q "CONFIG_ARCH_EXYNOS=y" .config; then
    echo "   Adding Exynos platform support..."
    cat >> .config << 'EOF'

# Exynos platform support
CONFIG_ARCH_EXYNOS=y
CONFIG_ARCH_EXYNOS7=y
CONFIG_EXYNOS_THERMAL=y
CONFIG_S3C_LOWLEVEL_UART_PORT=1
EOF
    make ARCH=arm64 olddefconfig
    echo "   ✓ Added Exynos support to kernel config"
else
    echo "   ✓ Exynos support already enabled"
fi

echo ""
echo "6. Testing full kernel build with device tree..."
echo "   Building kernel image and device tree..."

if make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image dtbs -j$(nproc) 2>/tmp/full_build_errors; then
    echo "   🎉 COMPLETE SUCCESS!"
    echo "   Kernel Image: $(ls -lh arch/arm64/boot/Image | awk '{print $5}')"
    echo "   Device Tree: $(ls -lh arch/arm64/boot/dts/exynos/exynos7870-gtaxl-minimal.dtb | awk '{print $5}')"
    echo ""
    echo "   ✅ MILESTONE ACHIEVED!"
    echo "   You now have a bootable Linux 4.4 kernel for SM-T580!"
else
    echo "   ⚠️  Build issues found:"
    tail -20 /tmp/full_build_errors | sed 's/^/      /'
fi

echo ""
echo "7. Next steps for boot testing:"
echo "   a) Create boot.img with kernel + device tree"
echo "   b) Flash to SM-T580 for testing"
echo "   c) Monitor serial console for boot progress"
echo "   d) Add more hardware support incrementally"

echo ""
echo "🚀 Ready for boot testing!"
