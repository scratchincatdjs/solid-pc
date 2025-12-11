#!/bin/bash

# SOLID Ubuntu Migration Validation Script
# Run this inside a test VM to verify the migration was successful

echo "================================================"
echo "SOLID Ubuntu Migration Validation"
echo "================================================"
echo ""

PASS_COUNT=0
FAIL_COUNT=0

# Helper functions
pass() {
    echo "✓ $1"
    ((PASS_COUNT++))
}

fail() {
    echo "✗ $1"
    ((FAIL_COUNT++))
}

warn() {
    echo "⚠ $1"
}

# Check 1: Verify Ubuntu version
echo "Checking OS..."
if [ -f /etc/os-release ]; then
    source /etc/os-release
    if [[ "$ID" == "ubuntu" ]]; then
        pass "OS is Ubuntu $VERSION"
    else
        fail "OS is not Ubuntu (found: $ID)"
    fi
else
    fail "/etc/os-release not found"
fi
echo ""

# Check 2: Verify Cinnamon is installed
echo "Checking Cinnamon desktop..."
if command -v cinnamon-session &> /dev/null; then
    CINNAMON_VERSION=$(cinnamon --version 2>/dev/null || echo "unknown")
    pass "Cinnamon desktop is installed ($CINNAMON_VERSION)"
else
    fail "Cinnamon not found"
fi
echo ""

# Check 3: Verify theme availability
echo "Checking themes..."
if [ -d /usr/share/themes/Mint-Y-Dark-Blue ]; then
    pass "Mint-Y theme available"
elif [ -d /usr/share/themes/Arc-Dark ]; then
    pass "Arc-Dark theme available (fallback)"
else
    warn "Neither Mint-Y nor Arc-Dark theme found"
fi

if [ -d /usr/share/icons/Papirus ]; then
    pass "Papirus icon theme available"
else
    warn "Papirus icon theme not found"
fi
echo ""

# Check 4: Verify BTRFS tools
echo "Checking BTRFS and snapshot tools..."
if command -v btrfs &> /dev/null; then
    pass "BTRFS tools installed"
else
    fail "BTRFS tools missing"
fi

if command -v timeshift &> /dev/null; then
    pass "Timeshift installed"
else
    fail "Timeshift missing"
fi
echo ""

# Check 5: Verify business applications
echo "Checking business applications..."
if command -v libreoffice &> /dev/null; then
    pass "LibreOffice installed"
else
    fail "LibreOffice missing"
fi

if command -v thunderbird &> /dev/null; then
    pass "Thunderbird installed"
else
    fail "Thunderbird missing"
fi

if command -v gnucash &> /dev/null; then
    pass "GnuCash installed"
else
    fail "GnuCash missing"
fi
echo ""

# Check 6: Verify file sync tools
echo "Checking file sync tools..."
if command -v rclone &> /dev/null; then
    pass "rclone installed"
else
    fail "rclone missing"
fi

if command -v nextcloud &> /dev/null || snap list | grep -q nextcloud; then
    pass "Nextcloud Desktop Client installed"
else
    warn "Nextcloud Desktop Client not found"
fi
echo ""

# Check 7: Verify printing support
echo "Checking printing support..."
if systemctl is-enabled cups &> /dev/null; then
    pass "CUPS print service enabled"
else
    warn "CUPS print service not enabled"
fi
echo ""

# Check 8: Verify power management
echo "Checking power management..."
if systemctl is-enabled tlp &> /dev/null; then
    pass "TLP power management enabled"
else
    warn "TLP not enabled (optional for laptops)"
fi
echo ""

# Summary
echo "================================================"
echo "Validation Summary"
echo "================================================"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "✓ All critical checks passed!"
    echo "The Ubuntu migration appears successful."
    exit 0
else
    echo "✗ Some checks failed."
    echo "Review the failures above and check the Ansible logs."
    exit 1
fi
