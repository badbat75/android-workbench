#!/bin/bash

# Test Android configuration compatibility with Linux 4.4 LTS
echo "=== Testing Android Config Compatibility with Linux 4.4 ==="

# First, let's see what happened with the config merge
echo "1. Checking if merge_config.sh ran successfully..."
if [ -f .config ]; then
    echo "✓ .config file exists"
else
    echo "✗ .config file missing - merge_config.sh may have failed"
    echo "Let's create a basic config first:"
    make ARCH=arm64 defconfig
fi

echo ""
echo "2. Creating Android config for testing..."

# Create a test Android config file
cat > android_test.cfg << 'EOF'
# Core Android Features - Testing compatibility
CONFIG_ANDROID=y
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ASHMEM=y
CONFIG_ANDROID_LOW_MEMORY_KILLER=y

# ARM64 Features
CONFIG_ARMV8_DEPRECATED=y
CONFIG_CP15_BARRIER_EMULATION=y
CONFIG_SETEND_EMULATION=y
CONFIG_SWP_EMULATION=y

# Power Management
CONFIG_PM_AUTOSLEEP=y
CONFIG_PM_WAKELOCKS=y

# Memory
CONFIG_ION=y

# Security
CONFIG_SECURITY=y
CONFIG_SECURITY_SELINUX=y

# Device Mapper
CONFIG_DM_CRYPT=y
CONFIG_DM_VERITY=y
EOF

echo "3. Testing merge with verbose output..."
echo "Running: scripts/kconfig/merge_config.sh -r .config android_test.cfg"
scripts/kconfig/merge_config.sh -r .config android_test.cfg

echo ""
echo "4. Checking which Android features are available..."

# Function to check config option
check_config() {
    local config_name="$1"
    local description="$2"
    
    if grep -q "^$config_name=y" .config; then
        echo "✓ $config_name - $description"
    elif grep -q "^# $config_name is not set" .config; then
        echo "○ $config_name - $description (available but disabled)"
    else
        echo "✗ $config_name - $description (NOT AVAILABLE)"
    fi
}

echo ""
echo "=== Android Core Features ==="
check_config "CONFIG_ANDROID" "Android support"
check_config "CONFIG_ANDROID_BINDER_IPC" "Binder IPC"
check_config "CONFIG_ASHMEM" "Anonymous shared memory"
check_config "CONFIG_ANDROID_LOW_MEMORY_KILLER" "Low memory killer"

echo ""
echo "=== ARM64 Compatibility ==="
check_config "CONFIG_ARMV8_DEPRECATED" "ARMv8 deprecated features"
check_config "CONFIG_CP15_BARRIER_EMULATION" "CP15 barrier emulation"
check_config "CONFIG_SETEND_EMULATION" "SETEND emulation"
check_config "CONFIG_SWP_EMULATION" "SWP emulation"

echo ""
echo "=== Power Management ==="
check_config "CONFIG_PM_AUTOSLEEP" "Autosleep"
check_config "CONFIG_PM_WAKELOCKS" "Wakelocks"
check_config "CONFIG_PM_RUNTIME" "Runtime PM"

echo ""
echo "=== Memory Management ==="
check_config "CONFIG_ION" "ION memory manager"
check_config "CONFIG_KSM" "Kernel samepage merging"
check_config "CONFIG_COMPACTION" "Memory compaction"

echo ""
echo "=== Security ==="
check_config "CONFIG_SECURITY" "Security framework"
check_config "CONFIG_SECURITY_SELINUX" "SELinux"
check_config "CONFIG_DM_CRYPT" "Device mapper crypto"
check_config "CONFIG_DM_VERITY" "Device mapper verity"

echo ""
echo "=== Potential Issues Check ==="

# Check for known problematic configs
echo "Checking for Android-specific features that might be missing..."

if ! grep -q "CONFIG_ANDROID" arch/arm64/Kconfig* drivers/*/Kconfig* 2>/dev/null; then
    echo "⚠️  Android support may not be available in this kernel version"
fi

# Check if ION is available
if ls drivers/staging/android/ion* 2>/dev/null >/dev/null; then
    echo "✓ ION driver found in staging"
else
    echo "⚠️  ION driver not found - may need to be backported"
fi

# Check for Android staging drivers
if [ -d "drivers/staging/android" ]; then
    echo "✓ Android staging drivers directory exists"
    echo "   Available Android drivers:"
    ls drivers/staging/android/ 2>/dev/null | sed 's/^/   - /'
else
    echo "⚠️  Android staging drivers directory missing"
fi

echo ""
echo "=== Summary ==="
echo "To proceed with the SM-T580 port:"
echo "1. Fix any missing Android features (✗ items above)"
echo "2. Enable required options (○ items above)" 
echo "3. Start porting device tree from Samsung's patch"
echo "4. Add Exynos 7870 platform support"

# Cleanup
rm -f android_test.cfg
