#!/bin/bash

echo "=== Force Enable COMPAT Method ==="

# Direct config file modification approach
echo "1. Backing up current config..."
cp .config .config.backup

echo "2. Directly modifying .config file..."
# Add COMPAT support directly to config file
cat >> .config << 'EOF'

# 32-bit compatibility support
CONFIG_COMPAT=y
CONFIG_SYSVIPC_COMPAT=y
CONFIG_KEYS_COMPAT=y
CONFIG_COMPAT_BINFMT_ELF=y
CONFIG_COMPAT_OLD_SIGACTION=y

# ARM64 deprecated instruction emulation
CONFIG_ARMV8_DEPRECATED=y
CONFIG_CP15_BARRIER_EMULATION=y
CONFIG_SETEND_EMULATION=y
CONFIG_SWP_EMULATION=y
EOF

echo "3. Running olddefconfig to resolve dependencies..."
make ARCH=arm64 olddefconfig

echo "4. Checking results..."
if grep -q "^CONFIG_COMPAT=y" .config; then
    echo "✓ CONFIG_COMPAT=y - Success!"
else
    echo "✗ CONFIG_COMPAT still missing"
    echo "   Restoring backup and recommending fresh start"
    cp .config.backup .config
fi

echo ""
echo "5. Final status check:"
echo "   COMPAT: $(grep '^CONFIG_COMPAT=' .config || echo 'not found')"
echo "   ARM64 deprecated: $(grep '^CONFIG_ARMV8_DEPRECATED=' .config || echo 'not found')"
echo "   Android: $(grep '^CONFIG_ANDROID=' .config || echo 'not found')"

if grep -q "^CONFIG_COMPAT=y" .config && grep -q "^CONFIG_ARMV8_DEPRECATED=y" .config; then
    echo ""
    echo "🎉 SUCCESS! All features enabled!"
    echo "   Ready to test build and start device tree porting"
else
    echo ""
    echo "⚠️  If this still fails, we need to start fresh:"
    echo "   1. make ARCH=arm64 mrproper"
    echo "   2. make ARCH=arm64 defconfig" 
    echo "   3. Re-apply all configs step by step"
fi
