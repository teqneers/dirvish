#!/bin/bash
source /tests/helpers.sh
suite "Basic Backup"

VAULT=test-basic
BANK=${TEST_BANK:-/test-bank}
SOURCE=/test-src-basic

# Setup
mkdir -p "$BANK/$VAULT/dirvish" "$SOURCE/subdir"
echo "hello world"  > "$SOURCE/file1.txt"
echo "second file"  > "$SOURCE/file2.txt"
echo "nested"       > "$SOURCE/subdir/nested.txt"

cat > "$BANK/$VAULT/dirvish/default.conf" << EOF
client: ${DIRVISH_CLIENT:-127.0.0.1}
tree: $SOURCE
rsh: $DIRVISH_RSH
expire: +30 days
EOF

# Run initial backup
dirvish --vault "$VAULT" --init 2>/tmp/dirvish-stderr.txt
EXIT=$?

assert_eq "$EXIT" "0" "dirvish exits 0"

# The image name is a timestamp; find it dynamically
IMAGE=$(ls -1 "$BANK/$VAULT/" | grep -v '^dirvish$' | head -1)
assert_ne "$IMAGE" "" "image directory created"

assert_file_exists "$BANK/$VAULT/$IMAGE/summary"        "summary written"
assert_dir_exists  "$BANK/$VAULT/$IMAGE/tree"           "tree directory created"
assert_file_exists "$BANK/$VAULT/$IMAGE/tree/file1.txt" "file1.txt backed up"
assert_file_exists "$BANK/$VAULT/$IMAGE/tree/file2.txt" "file2.txt backed up"
assert_file_exists "$BANK/$VAULT/$IMAGE/tree/subdir/nested.txt" "nested file backed up"
assert_contains    "$BANK/$VAULT/$IMAGE/summary" "Status: success" "summary reports success"
assert_file_exists "$BANK/$VAULT/dirvish/default.hist"  "history file created"

# Content integrity
CONTENT=$(cat "$BANK/$VAULT/$IMAGE/tree/file1.txt")
assert_eq "$CONTENT" "hello world" "file content preserved"

summary