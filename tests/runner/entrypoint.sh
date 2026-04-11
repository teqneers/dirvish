#!/bin/bash
# Main test runner executed inside the container.
# Usage: entrypoint.sh [--btrfs]

set -e

BTRFS_MODE=false
[ "$1" = "--btrfs" ] && BTRFS_MODE=true
export BTRFS_MODE

TEST_BANK=/test-bank

if $BTRFS_MODE; then
    echo "Setting up BTRFS..."
    /tests/setup_btrfs.sh
    echo ""
fi

echo "Setting up SSH..."
/tests/setup_ssh.sh
echo ""

mkdir -p "$TEST_BANK"
export TEST_BANK

# Write master.conf for this run
cat > /etc/dirvish/master.conf << EOF
bank:
    $TEST_BANK
EOF

if $BTRFS_MODE; then
    echo "btrfs: 1" >> /etc/dirvish/master.conf
fi

# RSH option written once for all test vaults to use
export DIRVISH_RSH="ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no"

echo "Running tests (BTRFS_MODE=$BTRFS_MODE, TEST_BANK=$TEST_BANK)"
echo ""

TOTAL_FAIL=0

for case_file in /tests/cases/*.sh; do
    case_name=$(basename "$case_file")

    # Skip BTRFS-specific case when not in BTRFS mode, and vice versa
    if ! $BTRFS_MODE && [ "$case_name" = "05_btrfs.sh" ]; then
        echo "SKIP  $case_name (not in BTRFS mode)"
        continue
    fi
    if $BTRFS_MODE && [ "$case_name" = "02_incremental.sh" ]; then
        echo "SKIP  $case_name (hardlink test not applicable to BTRFS)"
        continue
    fi

    if bash "$case_file"; then
        :
    else
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
done

echo ""
if [ "$TOTAL_FAIL" -eq 0 ]; then
    echo "All test suites passed."
    exit 0
else
    echo "$TOTAL_FAIL test suite(s) failed."
    exit 1
fi