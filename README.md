# Dirvish — Fast, Battle-Tested Disk Backup

![Tests](https://github.com/teqneers/dirvish/actions/workflows/test.yml/badge.svg)
![License](https://img.shields.io/badge/license-OSL_2.0-blue)
![Perl](https://img.shields.io/badge/perl-5%2B-informational?logo=perl)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey?logo=linux)
![Last Commit](https://img.shields.io/github/last-commit/teqneers/dirvish)

> A time machine for your servers. Dirvish has been running reliably in production environments for over two decades — and this fork makes it faster than ever.

Dirvish is a disk-based, rotating network backup system built on top of [rsync](https://rsync.samba.org). It maintains a complete, browsable image of your filesystems after every backup run — with automatic creation, rotation, and expiration of snapshots — all unattended.

**This fork adds two major improvements over the [original](https://dirvish.org):**

- **BTRFS snapshot support** — uses copy-on-write snapshots instead of hardlinks, making both backup creation and cleanup dramatically faster on large filesystems
- **Concurrent backups** — `dirvish-runall` can back up multiple vaults in parallel, cutting total backup window time

---

## Why Dirvish?

| Feature | Dirvish | rsnapshot | Duplicati | Restic |
|---|---|---|---|---|
| Full browsable snapshots | Yes | Yes | No | No |
| rsync-based (fast delta) | Yes | Yes | No | No |
| BTRFS copy-on-write | Yes (this fork) | No | No | No |
| Parallel vault backups | Yes (this fork) | No | No | Yes |
| Pre/post hook scripts | Yes | Limited | No | No |
| Production-proven (20+ yrs) | Yes | Yes | No | No |
| Zero backup-client software | Yes | Yes | No | No |

Dirvish is the right choice when you need **browsable, point-in-time snapshots** of remote Linux/Unix machines with no agent installed on the client — just rsync and SSH.

---

## Features

- **Complete disk images** — every backup is a full, browsable directory tree you can `cd` into and restore individual files from directly
- **Space-efficient** — unchanged files are shared between snapshots via hardlinks (works on any filesystem) or BTRFS copy-on-write (optional, dramatically faster on large filesystems), so you only pay for what changed
- **BTRFS snapshots** *(optional)* — instant snapshot creation and O(1) deletion; no `cp -al` over millions of files; enable with `btrfs: 1` in `master.conf`
- **Automatic expiry** — define flexible expiry rules (`+2 weeks`, `+6 months`) and let `dirvish-expire` clean up on a schedule
- **Parallel backups** — run N vaults concurrently with `concurrent: N` in `master.conf`
- **Pre/post hook scripts** — run commands on the server or client before and after each backup; dump a database, stop a service, collect metrics — anything you need beyond a plain file copy
- **Multi-vault, multi-bank** — organise backups across multiple storage pools and dozens of machines from a single config
- **SSH-based transport** — no agent on the client; any machine reachable via SSH can be backed up
- **Battle-hardened** — the core engine has been running production backups since the early 2000s

---

## Requirements

- **rsync** 2.5.6 or higher (2.6.0+ recommended for Windows clients)
- **Perl 5** with modules: `POSIX`, `Getopt::Long`, `Time::ParseDate`, `Time::Period`
- **SSH** configured so root on the backup server can connect to clients non-interactively (key-based auth)
- **BTRFS filesystem** *(optional)* — enables copy-on-write snapshots for significantly faster backups and cleanup on large filesystems; without it, dirvish falls back to hardlinks which work fine on any filesystem

Install Perl dependencies on Debian/Ubuntu:
```sh
apt-get install libtime-parsedate-perl cpanminus && cpanm Time::Period
```

---

## Installation

```sh
git clone https://github.com/teqneers/dirvish.git
cd dirvish
sh install.sh
```

The installer will ask for your Perl path, install prefix, and target directories. Defaults install to `/usr/sbin/` with config in `/etc/dirvish/`.

See [INSTALL](INSTALL) for full details and dependencies.

---

## Quick Start

### 1. Create `/etc/dirvish/master.conf`

```yaml
bank:
    /backup

# Optional: run multiple vaults in parallel
concurrent: 4

# Vaults to back up when dirvish-runall is invoked.
# The optional time is used as the image name (--image-time), not for scheduling.
# Scheduling is handled externally (e.g. cron).
Runall:
    webserver
    database
    fileserver

# Default expiry policy
expire-default: +6 months
```

Add `btrfs: 1` if your bank is on a BTRFS filesystem.

### 2. Create a vault config at `/backup/webserver/dirvish/default.conf`

```yaml
client: webserver.example.com
tree: /
rsh: ssh -l root
exclude:
    /proc/
    /sys/
    /tmp/
    lost+found/
expire: +4 weeks
```

### 3. Initialize and run

```sh
# First-time init (creates the reference snapshot)
dirvish --vault webserver --init

# Subsequent backups (run nightly via cron)
dirvish-runall

# Clean up expired images
dirvish-expire
```

### 4. Restore a file

Every snapshot is a plain directory — just copy from it:

```sh
# Find which snapshot has the file you need
dirvish-locate webserver /etc/nginx/nginx.conf

# Restore directly
cp /backup/webserver/20250101/tree/etc/nginx/nginx.conf /etc/nginx/nginx.conf
```

### Pre/post hook scripts

Dirvish supports four hooks per vault, run in this order:

| Hook | Runs on | Typical use |
|---|---|---|
| `pre-server` | Backup server | Mount a remote share, send a notification |
| `pre-client` | Backup target (client) | Dump a database, flush application state |
| `post-client` | Backup target (client) | Restart a service, clean up the dump file |
| `post-server` | Backup server | Alert on failure, update a monitoring system |

Hooks can be any shell command or script path. They receive the backup status via the `DIRVISH_STATUS` environment variable (`success` or `failure`), so `post-*` hooks can react to the outcome.

**Example: dump a database before backup, clean up after**

```yaml
# Dump all databases to a file that rsync will then include in the snapshot
pre-client: pg_dumpall -U postgres > /var/backups/postgres.sql

# Remove the dump after the backup completes (success or failure)
post-client: rm -f /var/backups/postgres.sql
```

The dump runs on the client machine before rsync starts, so the snapshot always contains a consistent export. Any command works here — stop a service, export a config, snapshot a VM disk — as long as it exits 0 on success.

---

## Advanced Configuration Example

A production-grade `master.conf` with BTRFS, log compression, and tiered expiry:

```yaml
bank:
    /dirvish/server

xdev: 1
btrfs: 1
devices: 0
index: none
log: pbzip2
image-default: %Y%m%d-%H:%M

exclude:
    # macOS artifacts (safe to exclude everywhere)
    .DS_Store
    ._.*

    # Virtual and pseudo filesystems — never back these up
    /dev
    /proc
    /run
    /sys
    /var/run

    # Swap and temp
    /swap.img
    /tmp/*
    /var/tmp/*

    # Removable and network mounts
    /cdrom/*
    /media/*
    /mnt/*

    # Package manager caches (easily rebuilt)
    /var/cache/apt/*
    /var/lib/apt/lists/*

    # Build artifacts
    /usr/src/**/*.o

    # Per-user caches and throwaway data
    /home/*/.cache/*
    /home/*/.npm/_cacache/*
    /root/.cache/*

    # Docker layer storage (can be huge; restore from image instead)
    /var/lib/docker/btrfs/subvolumes/*
    /var/lib/docker/buildkit/*

    # Misc
    lost+found/
    /var/backups/*

Runall:
# internal servers
    omega
# external servers
    alpha
    beta

concurrent: 4

expire-default: +15 days
expire-rule:
# MIN HR  DOM MON DOW  RETENTION
  *   *   *   *   *    +14 days
  *   *   *   *   7    +1 months
```

### Option reference

| Option | Description |
|---|---|
| `bank` | Directory where all vault subdirectories are stored |
| `xdev` | `1` = stay on one filesystem (don't cross mount points) — almost always what you want for a full-system backup |
| `btrfs` | `1` = use BTRFS copy-on-write snapshots instead of hardlinks; requires the bank to be on a BTRFS filesystem |
| `devices` | `0` = skip device files (character/block devices); they can't be meaningfully restored from a file backup |
| `index` | How to build the per-image file index. `none` skips it; set to `gzip` or a path to a compressor to enable — used by `dirvish-locate` |
| `log` | Compress the rsync transfer log with this program (e.g. `pbzip2`, `gzip`). Keeps log files small on busy servers |
| `image-default` | `strftime` format for image directory names. `%Y%m%d-%H:%M` gives `20250101-22:00` |
| `rsh` | Remote shell command. Defaults to `ssh`; override here or per-vault (e.g. `ssh -i /root/.ssh/backup_key`) |
| `exclude` | Glob patterns excluded from every vault. Per-vault configs can add more |
| `Runall` | Vaults to back up when `dirvish-runall` is invoked. Comments (`#`) work as section labels. Scheduling is external (cron/systemd) |
| `concurrent` | Maximum number of vaults to back up in parallel |
| `expire-default` | Fallback retention period for images not matched by any `expire-rule` |
| `expire-rule` | Cron-style retention rules (`MIN HR DOM MON DOW PERIOD`). Rules are evaluated in order; first match wins. Day-of-week 7 = Sunday |

---

## Documentation

| Manpage | Description |
|---|---|
| [dirvish(8)](dirvish.8) | The main backup utility — options, config reference |
| [dirvish.conf(5)](dirvish.conf.5) | Full configuration file format and all options |
| [dirvish-runall(8)](dirvish-runall.8) | Run scheduled vaults, optionally in parallel |
| [dirvish-expire(8)](dirvish-expire.8) | Remove images that have passed their expiry date |
| [dirvish-locate(8)](dirvish-locate.8) | Find historical versions of files across all snapshots |

### Guides

- [Dirvish HOWTO](https://wiki.diala.org/doc:boxman) by Jason Boxman — recommended starting point
- [Debian HOWTO](https://dirvish.org/debian.howto.html) by Paul Slootman — single-workstation setup, mostly distro-agnostic
- [FAQ](https://dirvish.org/FAQ.html) — common questions and configuration tips
- [Mike Rubel's rsync snapshots](http://www.mikerubel.org/computers/rsync_snapshots/) — background reading on the disk-backup model dirvish is built on

---

## Credits

Dirvish was created by **J.W. Schultz** at Pegasystems Technologies. Original source and documentation at [dirvish.org](https://dirvish.org).

BTRFS support based on the [dirvish-rpm patch](https://github.com/keachi/dirvish-rpm) by keachi.
Concurrency patch also from [dirvish-rpm](https://github.com/keachi/dirvish-rpm/blob/master/SOURCES/05-dirvish-runall-concurrency.patch).
