#!/bin/bash
# Tests dirvish-runall: runs multiple vaults in parallel and verifies
# each produces a successful image.
source /tests/helpers.sh
suite "dirvish-runall"

BANK=${TEST_BANK:-/test-bank}

# Set up two independent vaults
for V in runall-vault-a runall-vault-b; do
    SRC="/test-src-$V"
    mkdir -p "$BANK/$V/dirvish" "$SRC"
    echo "data for $V" > "$SRC/data.txt"
    cat > "$BANK/$V/dirvish/default.conf" << EOF
client: localhost
tree: $SRC
rsh: $DIRVISH_RSH
expire: +30 days
EOF
done

# Append both vaults to Runall in master.conf
cat >> /etc/dirvish/master.conf << 'EOF'

Runall:
    runall-vault-a
    runall-vault-b

concurrent: 2
EOF

# --init both vaults first (runall doesn't --init)
dirvish --vault runall-vault-a --init >/dev/null 2>&1
dirvish --vault runall-vault-b --init >/dev/null 2>&1

# Sleep to ensure dirvish-runall will use a different timestamp for the new images
sleep 2

# Run runall for a second backup pass
dirvish-runall --quiet 2>/tmp/runall-stderr.txt
EXIT=$?
assert_eq "$EXIT" "0" "dirvish-runall exits 0"

for V in runall-vault-a runall-vault-b; do
    # Each vault should now have 2 images (init + runall)
    COUNT=$(ls -1 "$BANK/$V/" | grep -v '^dirvish$' | wc -l | tr -d ' ')
    assert_ne "$COUNT" "0" "$V has images after runall"
    # Latest image should be success
    LATEST=$(ls -1 "$BANK/$V/" | grep -v '^dirvish$' | sort | tail -1)
    assert_contains "$BANK/$V/$LATEST/summary" "Status: success" "$V latest image is success"
done

# Cleanup: remove Runall entries so later tests aren't affected
grep -v 'Runall:\|runall-vault\|concurrent:' /etc/dirvish/master.conf > /tmp/master.conf.tmp \
    && mv /tmp/master.conf.tmp /etc/dirvish/master.conf

summary