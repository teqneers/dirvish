#!/bin/sh
# Configure passwordless SSH to localhost for dirvish backup testing.
# dirvish uses ssh when client != server hostname, so we need working
# local SSH.
set -e

mkdir -p /root/.ssh
chmod 700 /root/.ssh

if [ ! -f /root/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519 -q
fi
cat /root/.ssh/id_ed25519.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Generate host keys if missing (Fedora minimal images ship none)
[ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key -q
[ -f /etc/ssh/ssh_host_rsa_key ]     || ssh-keygen -t rsa     -N "" -f /etc/ssh/ssh_host_rsa_key     -q

# Ensure sshd permits root login with keys. Drop a snippet into sshd_config.d
# if supported, otherwise append directly to sshd_config.
SSHD_SNIPPET="
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication no
AuthorizedKeysFile /root/.ssh/authorized_keys
ListenAddress 127.0.0.1
"
if [ -d /etc/ssh/sshd_config.d ]; then
    printf '%s\n' "$SSHD_SNIPPET" > /etc/ssh/sshd_config.d/99-test.conf
else
    printf '%s\n' "$SSHD_SNIPPET" >> /etc/ssh/sshd_config
fi

# Start sshd
mkdir -p /run/sshd
/usr/sbin/sshd

# Prime the known_hosts file so dirvish doesn't hang on host key prompt.
# Use 127.0.0.1 explicitly to avoid IPv6 (::1) which sshd may not serve.
ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no \
    -o PreferredAuthentications=publickey \
    -o ConnectTimeout=5 127.0.0.1 true

echo "SSH to localhost configured."
