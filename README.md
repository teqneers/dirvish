# Dirvish

*This project originated from https://dirvish.org.*

## Changes made to original

- Applied BTRFS [patch](https://github.com/keachi/dirvish-rpm), so it is possible to use snapshots instead of hardlinks
  - It is so much faster when creating a backup, but also when cleanup
- Added [concurrency](https://github.com/keachi/dirvish-rpm/blob/master/SOURCES/05-dirvish-runall-concurrency.patch), so dirvish can trigger multiple backups in parallel

## What is dirvish?
Dirvish is a fast, disk based, rotating network backup system. With dirvish you can maintain a set of complete images of your filesystems with unattended creation and expiration. A dirvish backup vault is like a time machine for your data.

Dirvish was originally created by JW Schultz.

# Documentation

Dirvish Documentation and links

## Dirvish Manpages

| Name                                 | Description                                             |
|--------------------------------------|---------------------------------------------------------|
| [dirvish.8](dirvish.8)               | The dirvish backup utility.                             |
| [dirvish.conf.5](dirvish.conf.5)	    | Configuration file options and format.                  |
| [dirvish-runall.8](dirvish-runall.8) | Utility to run a set of dirvish backup jobs             |
| [dirvish-expire.8](dirvish-expire.8) | Utility to remove expired dirvish images.               |
| [dirvish-locate.8](dirvish-locate.8) | Utility to locate versions of files in a dirvish vault. |

## Dirvish HOWTOs

These HOWTOs may be helpful in setting up a dirvish server or seeing what it will take to do so. Having the manpages for reference while reading these HOWTOs is advised.

Jason Boxman wrote a [dirvish guide](https://wiki.diala.org/doc:boxman). Check it out!

The [Debian Howto](https://dirvish.org/debian.howto.html) by Paul Slootman is a pretty decent recepe for setting up dirvish for local backup of a single workstation. There are some Debian package specifics but they are minor. Even if you are going to be using dirvish for backing up a network this is a good start.

The [INSTALL](INSTALL) instructions list dependencies and outlines setting up dirvish.

While not a HOWTO, the dirvish [FAQ](https://dirvish.org/FAQ.html) may help answer questions that come to mind while reading the other documentation and configuring dirivsh.

Links

[rsync](https://rsync.samba.org) is the utility that provides the foundation for dirvish. Understanding rsync's options is extremely helpful in getting the most out of dirvish. Rsync is highly recommended for much more than backups.

rlbackup creates backup images somewhat similar to dirvish, but has a much different approach to configuration and image expiration.

Mike Rubel's [rsync_snapshot](http://www.mikerubel.org/computers/rsync_snapshots/) paper, written just as dirvish was completed, outlines a simple backup approach using rsync and linking. This paper's real value is the clearly articulated discussion of disk-based backups and in particular how they relate to rsync. It also has a number of useful links.