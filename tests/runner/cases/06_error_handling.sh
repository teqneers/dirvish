#!/bin/bash
# Tests that dirvish exits non-zero and marks the summary as failed when
# something goes wrong, rather than silently reporting success.
source /tests/helpers.sh
suite "Error Handling"

BANK=${TEST_BANK:-/test-bank}

# --- Test: missing source tree ---
VAULT=test-err-nosrc
mkdir -p "$BANK/$VAULT/dirvish"
cat > "$BANK/$VAULT/dirvish/default.conf" << EOF
client: ${DIRVISH_CLIENT:-127.0.0.1}
tree: /nonexistent-source-path-xyz
rsh: $DIRVISH_RSH
expire: +30 days
EOF

dirvish --vault "$VAULT" --init >/dev/null 2>/dev/null
EXIT=$?
assert_ne "$EXIT" "0" "non-zero exit when source tree is missing"

IMAGE=$(ls -1 "$BANK/$VAULT/" | grep -v '^dirvish$' | head -1)
if [ -n "$IMAGE" ] && [ -f "$BANK/$VAULT/$IMAGE/summary" ]; then
    # Summary should NOT say success
    if grep -q "Status: success" "$BANK/$VAULT/$IMAGE/summary"; then
        fail "summary should not report success for failed backup"
    else
        pass "summary does not report success for failed backup"
    fi
else
    pass "no summary written for failed backup (acceptable)"
fi

# --- Test: vault with no config file ---
VAULT2=test-err-noconf
mkdir -p "$BANK/$VAULT2"
# No dirvish/default.conf

dirvish --vault "$VAULT2" --init >/dev/null 2>/dev/null
EXIT2=$?
assert_ne "$EXIT2" "0" "non-zero exit when vault has no config"

# --- Test: dirvish-expire with no master.conf ---
# Temporarily rename master.conf
mv /etc/dirvish/master.conf /etc/dirvish/master.conf.bak

dirvish-expire >/dev/null 2>/dev/null
EXPIRE_EXIT=$?
assert_ne "$EXPIRE_EXIT" "0" "dirvish-expire exits non-zero with no master.conf"

mv /etc/dirvish/master.conf.bak /etc/dirvish/master.conf

summary