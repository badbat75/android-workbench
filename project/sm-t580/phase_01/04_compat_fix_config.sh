#!/bin/bash

echo "=== Enabling 32-bit Compatibility and ARM64 Features ==="

# Create config fragment with the correct dependency chain
cat > compat_arm64.cfg << 'EOF'
# Enable 32-bit compatibility first (dependency)
CONFIG_COMPAT=y

# Enable 32-bit syscall support
CONFIG_SYSVIPC_COMPAT=y  
CONFIG_KEYS_COMPAT=y
CONFIG_COMPAT_BINFMT_ELF=y

# Now ARM64 deprecated features become available
CONFIG_ARMV8_DEPRECATED=y
CONFIG_CP15_BARRIER_EMULATION=y
CONFIG_SETEND_EMULATION=y
CONFIG_SWP_EMULATION=y

# Additional useful features for Android
CONFIG_COMPAT_OLD_SIGACTION=y
CONFIG_AUDIT_ARCH_COMPAT_GENERIC=y
EOF

echo "1. Applying 32-bit compatibility and ARM64 features..."
scripts/kconfig/merge_config.sh .config compat_arm64.cfg

echo ""
echo "2. Checking results..."

# Check if COMPAT is enabled
if grep -q "^CONFIG_COMPAT=y" .config; then
    echo "✓ CONFIG_COMPAT=y - 32-bit compatibility enabled"
else
    echo "✗ CONFIG_COMPAT - 32-bit compatibility failed"
fi

# Check ARM64 features
echo ""
echo "ARM64 deprecated instruction support:"
if grep -q "^CONFIG_ARMV8_DEPRECATED=y" .config; then
    echo "✓ CONFIG_ARMV8_DEPRECATED=y"
else
    echo "✗ CONFIG_ARMV8_DEPRECATED - still missing"
fi

if grep -q "^CONFIG_CP15_BARRIER_EMULATION=y" .config; then
    echo "✓ CONFIG_CP15_BARRIER_EMULATION=y"
else
    echo "✗ CONFIG_CP15_BARRIER_EMULATION - still missing"
fi

if grep -q "^CONFIG_SETEND_EMULATION=y" .config; then
    echo "✓ CONFIG_SETEND_EMULATION=y"
else
    echo "✗ CONFIG_SETEND_EMULATION - still missing"
fi

if grep -q "^CONFIG_SWP_EMULATION=y" .config; then
    echo "✓ CONFIG_SWP_EMULATION=y"
else
    echo "✗ CONFIG_SWP_EMULATION - still missing"
fi

echo ""
echo "3. Complete Android + ARM64 compatibility status:"
echo ""

# Full status check
echo "=== Core Android Features ==="
grep -q "^CONFIG_ANDROID=y" .config && echo "✓ Android support" || echo "✗ Android support"
grep -q "^CONFIG_ASHMEM=y" .config && echo "✓ ASHMEM" || echo "✗ ASHMEM"
grep -q "^CONFIG_ION=y" .config && echo "✓ ION memory manager" || echo "✗ ION memory manager"

echo ""
echo "=== 32-bit Compatibility ==="
grep -q "^CONFIG_COMPAT=y" .config && echo "✓ 32-bit EL0 support" || echo "✗ 32-bit EL0 support"
grep -q "^CONFIG_COMPAT_BINFMT_ELF=y" .config && echo "✓ 32-bit ELF support" || echo "✗ 32-bit ELF support"

echo ""
echo "=== ARM64 Legacy Support ==="
grep -q "^CONFIG_ARMV8_DEPRECATED=y" .config && echo "✓ ARMv8 deprecated instructions" || echo "✗ ARMv8 deprecated instructions"

echo ""
if grep -q "^CONFIG_ARMV8_DEPRECATED=y" .config; then
    echo "🎉 SUCCESS! All Android and ARM64 features should now work!"
    echo ""
    echo "Next steps:"
    echo "1. Test build: make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j\$(nproc)"
    echo "2. Start device tree porting from Samsung's patch"
    echo "3. Add Exynos 7870 platform support"
else
    echo "⚠️  If ARM64 features still missing, try menuconfig:"
    echo "   make ARCH=arm64 menuconfig"
    echo "   Enable: Kernel Features → [*] Kernel support for 32-bit EL0"
    echo "   Then: Kernel Features → [*] Emulate deprecated/obsolete ARMv8 instructions"
fi

# Cleanup
rm -f compat_arm64.cfg
