#!/bin/sh
# Replicates what install.sh does: prepends the shebang+CONFDIR header,
# then concatenates script.pl + loadconfig.pl into a single executable.
set -e

PERL=$(command -v perl || echo /usr/bin/perl)
CONFDIR="/etc/dirvish"
SRCDIR="${1:-/dirvish-src}"
BINDIR="/usr/sbin"

for script in dirvish dirvish-runall dirvish-expire dirvish-locate; do
    {
        printf '#!%s\n\n$CONFDIR = "%s";\n\n' "$PERL" "$CONFDIR"
        cat "$SRCDIR/${script}.pl"
        cat "$SRCDIR/loadconfig.pl"
    } > "$BINDIR/$script"
    chmod 755 "$BINDIR/$script"
done

mkdir -p "$CONFDIR"
echo "dirvish installed from $SRCDIR to $BINDIR"