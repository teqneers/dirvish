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

# Generate host keys if missing (needed on Fedora which ships no pre-generated keys)
[ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key -q
[ -f /etc/ssh/ssh_host_rsa_key ]     || ssh-keygen -t rsa     -N "" -f /etc/ssh/ssh_host_rsa_key     -q

# Start sshd
mkdir -p /run/sshd
/usr/sbin/sshd

# Prime the known_hosts file so dirvish doesn't hang on host key prompt
ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no \
    -o ConnectTimeout=5 localhost true

echo "SSH to localhost configured."