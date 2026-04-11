#!/bin/sh
# Create a loop-device-backed BTRFS filesystem for testing.
# Requires --privileged Docker or SYS_ADMIN capability.
set -e

IMG=/btrfs-test.img
MOUNT=/test-bank

dd if=/dev/zero of="$IMG" bs=1M count=512 status=none
mkfs.btrfs -q "$IMG"
mkdir -p "$MOUNT"
mount -o loop "$IMG" "$MOUNT"

echo "BTRFS mounted at $MOUNT"