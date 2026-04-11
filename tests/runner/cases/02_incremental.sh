#!/bin/bash
# Tests that a second backup hardlinks unchanged files to the previous image,
# and creates a new copy of changed files.
# Skipped in BTRFS mode (snapshots replace hardlinks).
source /tests/helpers.sh
suite "Incremental Backup (hardlinks)"

VAULT=test-incremental
BANK=${TEST_BANK:-/test-bank}
SOURCE=/test-src-incremental

mkdir -p "$BANK/$VAULT/dirvish" "$SOURCE"
echo "unchanged" > "$SOURCE/unchanged.txt"
echo "original content here" > "$SOURCE/changed.txt"

cat > "$BANK/$VAULT/dirvish/default.conf" << EOF
client: localhost
tree: $SOURCE
rsh: $DIRVISH_RSH
expire: +30 days
EOF

# First backup
dirvish --vault "$VAULT" --init >/dev/null 2>&1
IMAGE1=$(ls -1 "$BANK/$VAULT/" | grep -v '^dirvish$' | sort | head -1)
assert_ne "$IMAGE1" "" "first image created"

# Modify one file (use a different byte count to guarantee rsync detects the change
# even if the mtime rounds to the same second)
echo "mod" > "$SOURCE/changed.txt"

# Second backup (give it a distinct name via --image)
sleep 1  # ensure different timestamp
dirvish --vault "$VAULT" >/dev/null 2>&1
IMAGE2=$(ls -1 "$BANK/$VAULT/" | grep -v '^dirvish$' | sort | tail -1)
assert_ne "$IMAGE2" "$IMAGE1" "second image has different name"

assert_contains "$BANK/$VAULT/$IMAGE2/summary" "Status: success" "second backup succeeds"

# Unchanged file should share the same inode (hardlink) with image1
INODE1=$(stat -c %i "$BANK/$VAULT/$IMAGE1/tree/unchanged.txt" 2>/dev/null)
INODE2=$(stat -c %i "$BANK/$VAULT/$IMAGE2/tree/unchanged.txt" 2>/dev/null)
assert_eq "$INODE1" "$INODE2" "unchanged file is hardlinked between images"

# Changed file must NOT share an inode with image1
INODE_CHANGED1=$(stat -c %i "$BANK/$VAULT/$IMAGE1/tree/changed.txt" 2>/dev/null)
INODE_CHANGED2=$(stat -c %i "$BANK/$VAULT/$IMAGE2/tree/changed.txt" 2>/dev/null)
assert_ne "$INODE_CHANGED1" "$INODE_CHANGED2" "modified file has its own inode in new image"

# Content of changed file is up to date
CONTENT=$(cat "$BANK/$VAULT/$IMAGE2/tree/changed.txt")
assert_eq "$CONTENT" "mod" "changed file has new content in second image"

summary