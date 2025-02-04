
#       $Id: dirvish-runall.pl,v 12.0 2004/02/25 02:42:14 jw Exp $  $Name: Dirvish-1_2 $

$VERSION = ('$Name: Dirvish-1_2_1 $' =~ /Dirvish/i)
	? ('$Name: Dirvish-1_2_1 $' =~ m/^.*:\s+dirvish-(.*)\s*\$$/i)[0]
	: '1.1.2 patch' . ('$Id: dirvish-runall.pl,v 12.0 2004/02/25 02:42:14 jw Exp $'
		=~ m/^.*,v(.*:\d\d)\s.*$/)[0];
$VERSION =~ s/_/./g;


#########################################################################
#                                                         		#
#	Copyright 2002 and $Date: 2004/02/25 02:42:14 $
#                         Pegasystems Technologies and J.W. Schultz 	#
#                                                         		#
#	Licensed under the Open Software License version 2.0		#
#                                                         		#
#	This program is free software; you can redistribute it		#
#	and/or modify it under the terms of the Open Software		#
#	License, version 2.0 by Lauwrence E. Rosen.			#
#                                                         		#
#	This program is distributed in the hope that it will be		#
#	useful, but WITHOUT ANY WARRANTY; without even the implied	#
#	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR		#
#	PURPOSE.  See the Open Software License for details.		#
#                                                         		#
#########################################################################

use Time::ParseDate;
use POSIX qw(strftime);
use POSIX ":sys_wait_h";
use Getopt::Long;

sub loadconfig;
sub seppuku;

sub usage
{
	my $message = shift(@_);

	length($message) and print STDERR $message, "\n\n";

	$! and exit(255); # because getopt seems to send us here for death

	print STDERR <<EOUSAGE;
USAGE
	dirvish-runall OPTIONS
OPTIONS
	--config configfile
	--no-run
	--quiet
	--version
EOUSAGE

	exit 255;
}

$Options = {
	version		=> sub {
			print STDERR "dirvish version $VERSION\n";
			exit(0);
		},
	help		=> \&usage,
};

GetOptions($Options, qw(
		config=s
		quiet no-run|dry-run
		version help
	)) or usage;

if ($$Options{config})
{
	$Config = loadconfig(undef, $$Options{config})
}
elsif ($CONFDIR =~ /dirvish$/ && -f "$CONFDIR.conf")
{
	$Config = loadconfig(undef, "$CONFDIR.conf");
}
elsif (-f "$CONFDIR/master.conf")
{
	$Config = loadconfig(undef, "$CONFDIR/master.conf");
}
elsif (-f "$CONFDIR/dirvish.conf")
{
	seppuku 250, <<EOERR;
ERROR: no master configuration file.
	An old $CONFDIR/dirvish.conf file found.
	Please read the dirvish release notes.
EOERR
}
else
{
	seppuku 251, "ERROR: no global configuration file";
}
$$Config{Dirvish} ||= '/usr/sbin/dirvish';

$$Config{concurrent} ||= '1';
@pidList = ();

$$Options{'no-run'} and $$Options{quiet} = 0;

$errors = 0;

for $sched (@{$$Config{Runall}})
{
	# Wait until we have a free slot
	until (scalar(@pidList) < int($$Config{concurrent})) {
		@pidList2 = ();
		for $pid (@pidList) {
			$wait_result = waitpid($pid, WNOHANG);
			if ($wait_result > 0) {
				# Increment the error counter if dirvish failed
				$? < 0 || $? / 256 and ++$errors;
			} else {
				# Keep PID
				push(@pidList2, $pid);
			}
		}
		# Put all unsuccessful PIDs back in pidList
		@pidList = @pidList2;
		sleep(1);
	}

	# Spawn Child
	($vault, $itime) = split(/\s+/, $sched);
	$cmd = "$$Config{Dirvish} --vault $vault";
	$itime and $cmd .= qq[ --image-time "$itime"];
	$$Options{quiet}
		or printf "%s %s\n", strftime('%H:%M:%S', localtime), $cmd;
	$$Options{'no-run'} and next;
	$pid = fork();
	if ($pid > 0) {
		# Parent thread, register child pid
		push(@pidList, $pid);
	} elsif ($pid == -1) {
		# Failed fork
		print "Fork failed!\n";
	} else {
		# pid == 0, child thread
		exec($cmd) || die "child exit";
	}
}

# Wait for remaining dirvish processes
for $pid (@pidList) {
	# Wait forever this time
	$wait_result = waitpid($pid, 0);
	if ($wait_result == -1 or $wait_result == $pid) {
		# Increment the error counter if dirvish failed
		$? < 0 || $? / 256 and ++$errors;
	}
}

$$Options{quiet}
	or printf "%s %s\n", strftime('%H:%M:%S', localtime), 'done';


exit ($errors < 200 ? $errors : 199);
