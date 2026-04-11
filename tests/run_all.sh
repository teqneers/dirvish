#!/bin/bash
# Build all test images and run the full test suite (standard + BTRFS).
# Run from the repo root: sh tests/run_all.sh
# Requires Docker and a Linux host (or Docker Desktop with Linux containers).

set -e
cd "$(dirname "$0")/.."

DISTROS="debian-bookworm ubuntu-2404 fedora-41"
FAILED=0

for distro in $DISTROS; do
    image="dirvish-test:$distro"
    echo "========================================"
    echo "Building $distro..."
    echo "========================================"
    docker build -f "tests/Dockerfile.$distro" -t "$image" . 2>&1

    echo ""
    echo "--- $distro: standard tests ---"
    if docker run --rm "$image"; then
        echo "PASSED: $distro standard"
    else
        echo "FAILED: $distro standard"
        FAILED=$((FAILED + 1))
    fi

    echo ""
    echo "--- $distro: BTRFS tests ---"
    if docker run --rm --privileged "$image" --btrfs; then
        echo "PASSED: $distro BTRFS"
    else
        echo "FAILED: $distro BTRFS"
        FAILED=$((FAILED + 1))
    fi

    echo ""
done

echo "========================================"
if [ "$FAILED" -eq 0 ]; then
    echo "All suites passed across all distros."
    exit 0
else
    echo "$FAILED suite(s) failed."
    exit 1
fi