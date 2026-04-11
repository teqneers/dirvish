#!/bin/bash
# Tests that dirvish-expire removes images whose Expire date has passed,
# while keeping unexpired ones and always retaining the newest image even
# if it's expired (the "cannot expire last image" safety rule).
source /tests/helpers.sh
suite "Image Expiry"

VAULT=test-expire
BANK=${TEST_BANK:-/test-bank}
SOURCE=/test-src-expire

mkdir -p "$BANK/$VAULT/dirvish" "$SOURCE"
echo "data" > "$SOURCE/file.txt"

cat > "$BANK/$VAULT/dirvish/default.conf" << EOF
client: ${DIRVISH_CLIENT:-127.0.0.1}
tree: $SOURCE
rsh: $DIRVISH_RSH
expire: +30 days
EOF

# Create a first (valid) image via a real backup
dirvish --vault "$VAULT" --init >/dev/null 2>&1
KEEP_IMAGE=$(ls -1 "$BANK/$VAULT/" | grep -v '^dirvish$' | head -1)
assert_ne "$KEEP_IMAGE" "" "first image created"

# Inject a synthetic expired image by crafting a minimal summary file.
# dirvish-expire reads: vault, branch, Image, Status, Expire, Backup-complete.
# Expire date is parsed after stripping everything up to "== ".
EXPIRED_IMAGE="20000101000000"
mkdir -p "$BANK/$VAULT/$EXPIRED_IMAGE/tree"
cat > "$BANK/$VAULT/$EXPIRED_IMAGE/summary" << EOF
vault: $VAULT
branch: default
Image: $EXPIRED_IMAGE
client: ${DIRVISH_CLIENT:-127.0.0.1}
tree: $SOURCE
Status: success
Backup-begin: 2000-01-01 00:00:00
Backup-complete: 2000-01-01 00:00:01
Expire: +1 day == 2000-01-02 00:00:00
EOF

assert_dir_exists "$BANK/$VAULT/$EXPIRED_IMAGE" "expired image dir present before expire"

# Run expire
dirvish-expire --quiet 2>/tmp/expire-stderr.txt
EXIT=$?
assert_eq "$EXIT" "0" "dirvish-expire exits 0"

assert_not_exists "$BANK/$VAULT/$EXPIRED_IMAGE" "expired image removed"
assert_dir_exists  "$BANK/$VAULT/$KEEP_IMAGE"   "valid image retained"

summary
