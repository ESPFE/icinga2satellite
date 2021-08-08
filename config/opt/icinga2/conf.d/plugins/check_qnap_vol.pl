#!/usr/bin/perl -w
#
# check_qnap_vol.pl
# Based on check_qnap_volumes by (c) Michael Geiger, info@mgeiger.de
#
# nagios plugin that verifies the volumes (state, used space)
# of a QNAP NAS 
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# V.1.3 Martin Kasztantowicz, ka@geotek.de - http://geotek.de
#   Changes:
# - Corrected Perl Dependencies
# - Allows to specify SNMP community via -C parameter
# - Changed behaviour: Performance data now shows the used space versus total space which is more intuitive
# - Changed behaviour: Warning and critical levels are now referring to used percentage instead of free percentage
#   which makes performance graphs more useful
# - Renamed to check_qnap_vol due to changed behaviour
# - Removed "QNAP" from output. Shortens line and possibly allows to use with other NAS makes (if they use the NAS MIB)
# - Made output more informative like so:
#   "Volumes OK - [Mirror Disk Volume: Drive 1 2]: 331GB (84%) of 393GB used, 62GB free"
# - Putting each volume on a new line makes output more readable with multiple volumes
# - Handle zero volume sizes correctly (caused div by zero error before) and give hint to possible assignment as
#   iSCSI target

use 5.016;
use strict;
use Monitoring::Plugin;
use Monitoring::Plugin::Getopt;
use SNMP 5.0701;

use constant VERSION => "1.3";
use constant QTREE =>".1.3.6.1.4.1.24681.1.2.";

my ($np,$sess,$anz,@tab,$statc,$statw,$txt,$a,$x,$warn,$crit,$free,$used,$usedrel,$size);


# check SNMP error code
sub chk_err {
	my $txt = shift;

	if ($sess->{ErrorNum} != 0) {
		$np->nagios_die ("$txt: " . $sess->{ErrorStr});
	}
}


# convert into bytes
sub to_bytes {
	my $n = shift;
	my $b = lc(shift);

	if ($b eq "kb") {
		return (int($n * 1024));
	} elsif ($b eq "mb") {
		return (int($n * 1024 * 1024));
	} elsif ($b eq "gb") {
		return (int($n * 1024 * 1024 * 1024));
	} elsif ($b eq "tb") {
		return (int($n * 1024 * 1024 * 1024 * 1024));
	} else {
		return (0);
	}
}



### MAIN ###
$np = Monitoring::Plugin->new(
	usage		=> "Usage: %s -H <host> -C <SNMP community> -w <warning used space%%> -c <critical used space%%> [-t <timeout>]",
	shortname	=> "Volumes",
	version		=> VERSION,
	timeout		=> 5,
	url		=> "",
	blurb		=> "This plugin sends SNMP queries to a QNAP NAS and verifies the state\n" .
			   "of all volumes (status, used space).",
);

# plugin arguments
$np->add_arg(
	spec		=> "host|H=s",
	help		=> "ip address or hostname of the qnap device",
	required	=> 1,
);

$np->add_arg(
	spec		=> "community|C=s",
	help		=> "SNMP Community",
	required	=> 1,
);

$np->add_arg(
	spec		=> "warning|w=s",
	label		=> "PERCENT%",
	help		=> "used space in percent, when a WARNING is returned",
	required	=> 1,
);

$np->add_arg(
	spec		=> "critical|c=s",
	label		=> "PERCENT%",
	help		=> "used space in percent, when a CRITICAL is returned",
	required	=> 1,
);

$np->getopts;

if ($np->opts->warning =~ /^(\d+)%/) {
	$warn = $1;
} else {
	$np->nagios_die ("warning value not a percentage (e.g. 90%)");
}

if ($np->opts->critical =~ /^(\d+)%/) {
	$crit = $1;
} else {
	$np->nagios_die ("critical value not a percentage (e.g. 95%)");
}


# setup SNMP session
$sess = new SNMP::Session(
	DestHost	=> $np->opts->host,
	Community	=> $np->opts->community,
	Version		=> 2,
	Timeout		=> $np->opts->timeout * 1000000,
	Retries		=> 2,
);
if (! defined($sess)) {
	$np->nagios_die ("SNMP Session Setup");
}
chk_err("Session Setup");


# query number of volumes
$anz = $sess->get(QTREE . "16.0");
chk_err("Get SysVolumeNumber");
if (($anz !~ /^\d+$/) || ($anz <= 0) || ($anz > 20)) {
	$np->nagios_die ("SysVolumeNumber: " . $anz);
}

# bulk query on SystemVolumeTable
@tab = $sess->getbulk(0,$anz * 6,QTREE . "17.1");
chk_err("Get SystemVolumeTable");


# loop all volumes
$statw = 0;
$statc = 0;
$txt = "";
for ($a = 1; $a <= $anz; $a++) {

	# Status Text
	$x = $tab[$anz * 1 + $a - 1];
	$txt .= "\n" . $x . ": ";

	# SysVolumeFreeSize
	$x = $tab[$anz * 4 + $a - 1];
	if ($x =~ /^([0-9\.]+) ([kmgt]b)/i) {
		$free = to_bytes($1,$2);
	} else {
		$np->nagios_die ("SysVolumeFreeSize: $x");
	}

	# SysVolumeTotalSize
	$x = $tab[$anz * 3 + $a - 1];
	if ($x =~ /^([0-9\.]+) ([kmgt]b)/i) {
		$size = to_bytes($1,$2);
	} else {
		$np->nagios_die ("SysVolumeTotalSize: $x");
	}

    $used = $size - $free;

	# check used space
	if ($size eq 0) {
		$usedrel = 0;
	}
	else {
		$usedrel = $used / $size;
	}
	if ($usedrel >= ($crit / 100)) {
		$statc = 1;
	} elsif ($usedrel >= ($warn / 100)) {
		$statw = 1;
	}
	
	if ($size == 0 && $free == 0) {
		$txt .= "0GB free - volume may be configured as iSCSI target";
	}
	else {
		$txt .= int($used/1000000000) . "GB (" . int($usedrel * 100) . "%) of " . int($size/1000000000) . "GB used, " . int($free/1000000000) . "GB free";
	}

	# performance data
	$np->add_perfdata(
		label		=> "Volume " . $a . " used",
		value		=> ($used),
		uom		=> "B",
		warning		=> int($warn / 100 * $size),
		critical	=> int($crit / 100 * $size),
	);


	# SysVolumeStatus
	$x = $tab[$anz * 5 + $a - 1];
	if ($x !~ /^ready/i) {
		$statc = 1;
		$txt .= ", Volume " . $a . " Status: " . $x;
	}
}


# Exit
if ($statc) {
	$np->nagios_exit (CRITICAL, $txt);
} elsif ($statw) {
	$np->nagios_exit (WARNING, $txt);
} else {
	$np->nagios_exit (OK, $txt);
}

