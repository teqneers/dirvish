#!/bin/bash
# BTRFS-specific tests: verifies snapshot creation, read-only flag on success,
# and subvolume deletion on expire.
# Only runs when BTRFS_MODE=true (entrypoint skips this case otherwise).
source /tests/helpers.sh
suite "BTRFS Snapshots"

VAULT=test-btrfs
BANK=${TEST_BANK:-/test-bank}
SOURCE=/test-src-btrfs

mkdir -p "$BANK/$VAULT/dirvish" "$SOURCE"
echo "btrfs data" > "$SOURCE/file.txt"

cat > "$BANK/$VAULT/dirvish/default.conf" << EOF
client: localhost
tree: $SOURCE
rsh: $DIRVISH_RSH
expire: +30 days
EOF

# First backup (--init creates a btrfs subvolume)
dirvish --vault "$VAULT" --init 2>/tmp/btrfs-stderr.txt
EXIT=$?
assert_eq "$EXIT" "0" "first BTRFS backup exits 0"

IMAGE1=$(ls -1 "$BANK/$VAULT/" | grep -v '^dirvish$' | sort | head -1)
assert_ne "$IMAGE1" "" "first image directory created"
assert_contains "$BANK/$VAULT/$IMAGE1/summary" "Status: success" "first backup is success"

TREE1="$BANK/$VAULT/$IMAGE1/tree"
assert_dir_exists "$TREE1" "tree directory exists"

# Verify the tree is a BTRFS subvolume
assert_cmd_ok "tree is a btrfs subvolume" \
    btrfs subvolume show "$TREE1"

# Verify the snapshot is read-only after a successful backup
RO=$(btrfs property get -ts "$TREE1" ro 2>/dev/null | grep -c 'ro=true' || true)
assert_eq "$RO" "1" "snapshot is read-only after success"

# Second backup creates a snapshot of the first
sleep 1
dirvish --vault "$VAULT" >/dev/null 2>&1
IMAGE2=$(ls -1 "$BANK/$VAULT/" | grep -v '^dirvish$' | sort | tail -1)
assert_ne "$IMAGE2" "$IMAGE1" "second image has different name"
assert_contains "$BANK/$VAULT/$IMAGE2/summary" "Status: success" "second backup is success"

TREE2="$BANK/$VAULT/$IMAGE2/tree"
RO2=$(btrfs property get -ts "$TREE2" ro 2>/dev/null | grep -c 'ro=true' || true)
assert_eq "$RO2" "1" "second snapshot is read-only"

# Test expire: inject a synthetic expired image as a subvolume
EXPIRED_IMAGE="20000101000000"
mkdir -p "$BANK/$VAULT/$EXPIRED_IMAGE"
btrfs subvolume create "$BANK/$VAULT/$EXPIRED_IMAGE/tree" >/dev/null
btrfs property set -ts "$BANK/$VAULT/$EXPIRED_IMAGE/tree" ro true >/dev/null
cat > "$BANK/$VAULT/$EXPIRED_IMAGE/summary" << EOF
vault: $VAULT
branch: default
Image: $EXPIRED_IMAGE
client: localhost
tree: $SOURCE
Status: success
Backup-begin: 2000-01-01 00:00:00
Backup-complete: 2000-01-01 00:00:01
Expire: +1 day == 2000-01-02 00:00:00
EOF

dirvish-expire --quiet 2>/tmp/btrfs-expire-stderr.txt
EXPIRE_EXIT=$?
assert_eq "$EXPIRE_EXIT" "0" "dirvish-expire exits 0"

assert_not_exists "$BANK/$VAULT/$EXPIRED_IMAGE" "expired BTRFS image removed"
assert_dir_exists  "$BANK/$VAULT/$IMAGE1"       "valid image retained"

# Confirm the expired subvolume is actually gone from BTRFS
SUBVOL_COUNT=$(btrfs subvolume list "$BANK" | grep -c "$EXPIRED_IMAGE" || true)
assert_eq "$SUBVOL_COUNT" "0" "expired subvolume deleted from BTRFS"

summary