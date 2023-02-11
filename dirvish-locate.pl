#       $Id: dirvish-locate.pl,v 12.0 2004/02/25 02:42:14 jw Exp $  $Name: Dirvish-1_2 $

$VERSION = ('$Name: Dirvish-1_2_1 $' =~ /Dirvish/i)
	? ('$Name: Dirvish-1_2_1 $' =~ m/^.*:\s+dirvish-(.*)\s*\$$/i)[0]
	: '1.1.2 patch' . ('$Id: dirvish-locate.pl,v 12.0 2004/02/25 02:42:14 jw Exp $'
		=~ m/^.*,v(.*:\d\d)\s.*$/)[0];
$VERSION =~ s/_/./g;


#########################################################################
#                                                         		#
#	Copyright 2003 and $Date: 2004/02/25 02:42:14 $
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
use File::Find;
use Getopt::Long;

sub loadconfig;
sub check_expire;
sub findop;
sub imsort;
sub seppuku;

$KILLCOUNT = 1000;
$MAXCOUNT = 100;

sub usage
{
	my $message = shift(@_);

	length($message) and print STDERR $message, "\n\n";

	print STDERR <<EOUSAGE;
USAGE
	dirvish-locate vault[:branch] pattern
	
EOUSAGE

	exit 255;
}

$Options = 
{ 
	help		=> \&usage,
	version		=> sub {
			print STDERR "dirvish version $VERSION\n";
			exit(0);
		},
};

if ($CONFDIR =~ /dirvish$/ && -f "$CONFDIR.conf")
{
	loadconfig(undef, "$CONFDIR.conf", $Options);
}
elsif (-f "$CONFDIR/master.conf")
{
	loadconfig(undef, "$CONFDIR/master.conf", $Options);
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

GetOptions($Options, qw(
	version
	help|?
	)) or usage;

$Vault = shift;
$Vault =~ /:/ and ($Vault, $Branch) = split(/:/, $Vault);
$Pattern = shift;

$Vault && length($Pattern) or usage;

$fullpattern = $Pattern;
$fullpattern =~ /\$$/ or $fullpattern .= '[^/]*$';
($partpattern = $fullpattern) =~ s/^\^//;

for $b (@{$$Options{bank}})
{
	-d "$b/$Vault" and $bank = $b;
}
$bank or seppuku 220, "No such vault: $Vault";

opendir VAULT, "$bank/$Vault" or seppuku 221, "cannot open vault: $Vault";
@invault = readdir(VAULT);
closedir VAULT;

for $image (@invault)
{
	$image eq 'dirvish' and next;
	$imdir = "$bank/$Vault/$image";
	-f "$imdir/summary" or next;
	$conf = loadconfig('R', "$imdir/summary") or next;
	$$conf{Status} eq 'success' || $$conf{Status} =~ /^warn/
		or next;
	$$conf{'Backup-complete'} or next;
	$Branch && $$conf{branch} ne $Branch and next;

	unshift @images, {
		imdir => $imdir,
		image => $$conf{Image},
		branch => $$conf{branch},
		created	=> $$conf{'Backup-complete'},
	    }
}

for $image (sort(imsort @images))
{
	$imdir = $$image{imdir};

	$index = undef;
	-f "$imdir/index.bz2" and $index = "bzip2 -d -c $imdir/index.bz2|";
	-f "$imdir/index.gz" and $index = "gzip -d -c $imdir/index|";
	-f "$imdir/index" and $index = "<$imdir/index";
	$index or next;

	++$imagecount;

	open INDEX, $index or next;
	while (<INDEX>)
	{
		chomp;

		m($partpattern) or next;

# this parse operation is too slow.  It might be faster as a
# split with trimmed leading whitespace and remerged modtime
		$f = { image => $image };
		(
		 	$$f{inode},
			$$f{blocks},
			$$f{perms},
			$$f{links},
			$$f{owner},
			$$f{group},
			$$f{bytes},
			$$f{mtime},
			$path
		) = m<^
			\s*(\S+)		# inode
			\s+(\S+)		# block count
			\s+(\S+)		# perms
			\s+(\S+)		# link count
			\s+(\S+)		# owner
			\s+(\S+)		# group
			\s+(\S+)		# byte count
			\s+(\S+\s+\S+\s+\S+)	# date
			\s+(\S.*)		# path
		$>x;
		$$f{perms} =~ /^[dl]/ and next;
		$path =~ m($fullpattern) or next;

		exists($match{$path}) or ++$pathcount;
		push @{$match{$path}}, $f;
	}
	if ($pathcount >= $KILLCOUNT)
	{
		printf "dirvish-locate: too many paths match pattern, interupting search\n";
		last;
	}
}

printf "%d matches in %d images\n", $pathcount, $imagecount;
$pathcount >= $MAXCOUNT
	and printf "Pattern '%s' too vague, listing paths only.\n",
		$Pattern;

for $path (sort(keys(%match)))
{
	$last = undef;
	print $path;

	if ($pathcount >= $MAXCOUNT)
	{
		print "\n";
	       	next;
	}

	for $hit (@{$match{$path}})
	{
		$inode = $$hit{inode};
		$mtime = $$hit{mtime};
		$image = $$hit{image}{image};
		if ($inode ne $last)
		{
			$linesize = 5 + length($mtime) + length($image);
			printf "\n    %s %s", $mtime, $image;
		} else {
			$linesize += length($image) + 2;
			if ($linesize > 78)
			{
				$linesize = 5 + length($mtime) + length($image);
				print "\n",
					" " x (5 + length($mtime)),
					$image;
			} else {
				printf ", %s", $$hit{image}{image};
			}
		}
		$last = $inode;
	}
	print "\n\n";
}

exit 0;

sub imsort
{
	$$a{branch} cmp $$b{branch}
	|| $$b{created} cmp $$a{created};
}

#	Get patch level of loadconfig.pl in case exit codes
#	are needed.
#		$Id: loadconfig.pl,v 12.0 2004/02/25 02:42:15 jw Exp $


#########################################################################
#                                                         		#
#	Copyright 2002 and $Date: 2004/02/25 02:42:15 $
#                         Pegasystems Technologies and J.W. Schultz 	#
#                                                         		#
#	Licensed under the Open Software License version 2.0		#
#                                                         		#
#########################################################################

sub seppuku	# Exit with code and message.
{
	my ($status, $message) = @_;

	chomp $message;
	if ($message)
	{
		$seppuku_prefix and print STDERR $seppuku_prefix, ': ';
		print STDERR $message, "\n";
	}
	exit $status;
}

sub slurplist
{
	my ($key, $filename, $Options) = @_;
	my $f;
	my $array;

	$filename =~ m(^/) and $f = $filename;
	if (!$f && ref($$Options{vault}) ne 'CODE')
	{
		$f = join('/', $$Options{Bank}, $$Options{vault},
			'dirvish', $filename);
		-f $f or $f = undef;
	}
	$f or $f = "$CONFDIR/$filename";
	open(PATFILE, "<$f") or seppuku 229, "cannot open $filename for $key list";
	$array = $$Options{$key};
	while(<PATFILE>)
	{
		chomp;
		length or next;
		push @{$array}, $_;
	}
	close PATFILE;
}

#   loadconfig -- load configuration file
#   SYNOPSYS
#     	loadconfig($opts, $filename, \%data)
#
#   DESCRIPTION
#   	load and parse a configuration file into the data
#   	hash.  If the filename does not contain / it will be
#   	looked for in the vault if defined.  If the filename
#   	does not exist but filename.conf does that will
#   	be read.
#
#   OPTIONS
#	Options are case sensitive, upper case has the
#	opposite effect of lower case.  If conflicting
#	options are given only the last will have effect.
#
#   	f	Ignore fields in config file that are
#   		capitalized.
#
#   	o	Config file is optional, return undef if missing.
#
#   	R	Do not allow recoursion.
#
#   	g	Only load from global directory.
#
#
#
#   LIMITATIONS
#   	Only way to tell whether an option should be a list
#   	or scalar is by the formatting in the config file.
#
#   	Options reqiring special handling have to have that
#   	hardcoded in the function.
#

sub loadconfig
{
	my ($mode, $configfile, $Options) = @_;
	my $confile = undef;
	my ($key, $val);
	my $CONFIG;
	ref($Options) or $Options = {};
	my %modes;
	my ($conf, $bank, $k);

	$modes{r} = 1;
	for $_ (split(//, $mode))
	{
		if (/[A-Z]/)
		{
			$_ =~ tr/A-Z/a-z/;
			$modes{$_} = 0;
		} else {
			$modes{$_} = 1;
		}
	}


	$CONFIG = 'CFILE' . scalar(@{$$Options{Configfiles}});

	$configfile =~ s/^.*\@//;

	if($configfile =~ m[/])
	{
		$confile = $configfile;
	}
	elsif($configfile ne '-')
	{
		if(!$modes{g} && $$Options{vault} && $$Options{vault} ne 'CODE')
		{
			if(!$$Options{Bank})
			{
				my $bank;
				for $bank (@{$$Options{bank}})
				{
					if (-d "$bank/$$Options{vault}")
					{
						$$Options{Bank} = $bank;
						last;
					}
				}
			}
			if ($$Options{Bank})
			{
				$confile = join('/', $$Options{Bank},
					$$Options{vault}, 'dirvish',
					$configfile);
				-f $confile || -f "$confile.conf"
					or $confile = undef;
			}
		}
		$confile ||= "$CONFDIR/$configfile";
	}

	if($configfile eq '-')
	{
		open($CONFIG, $configfile) or seppuku 221, "cannot open STDIN";
	} else {
		! -f $confile && -f "$confile.conf" and $confile .= '.conf';

		if (! -f "$confile")
		{
			$modes{o} and return undef;
			seppuku 222, "cannot open config file: $configfile";
		}

		grep(/^$confile$/, @{$$Options{Configfiles}})
			and seppuku 224, "ERROR: config file looping on $confile";

		open($CONFIG, $confile)
			or seppuku 225, "cannot open config file: $configfile";
	}
	push(@{$$Options{Configfiles}}, $confile);

	while(<$CONFIG>)
	{
		chomp;
		s/\s*#.*$//;
		s/\s+$//;
		/\S/ or next;

		if(/^\s/ && $key)
		{
			s/^\s*//;
			push @{$$Options{$key}}, $_;
		}
		elsif(/^SET\s+/)
		{
			s/^SET\s+//;
			for $k (split(/\s+/))
			{
				$$Options{$k} = 1;
			}
		}
		elsif(/^UNSET\s+/)
		{
			s/^UNSET\s+//;
			for $k (split(/\s+/))
			{
				$$Options{$k} = undef;
			}
		}
		elsif(/^RESET\s+/)
		{
			($key = $_) =~ s/^RESET\s+//;
			$$Options{$key} = [ ];
		}
		elsif(/^[A-Z]/ && $modes{f})
		{
			$key = undef;
		}
		elsif(/^\S+:/)
		{
			($key, $val) = split(/:\s*/, $_, 2);
			length($val) or next;
			$k = $key; $key = undef;

			if ($k eq 'config')
			{
				$modes{r} and loadconfig($mode . 'O', $val, $Options);
				next;
			}
			if ($k eq 'client')
			{
				if ($modes{r} && ref ($$Options{$k}) eq 'CODE')
				{
					loadconfig($mode .  'og', "$CONFDIR/$val", $Options);
				}
				$$Options{$k} = $val;
				next;
			}
			if ($k eq 'file-exclude')
			{
				$modes{r} or next;

				slurplist('exclude', $val, $Options);
				next;
			}
			if (ref ($$Options{$k}) eq 'ARRAY')
			{
				push @{$$Options{$k}}, $_;
			} else {
				$$Options{$k} = $val;
			}
		}
	}
	close $CONFIG;
	return $Options;
}