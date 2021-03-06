#!/usr/bin/perl -w
#
# check_qnap_hdd  v1.1, 04.06.2014
# (c) Michael Geiger, info@mgeiger.de
# updates on http://www.mgeiger.de/downloads.html
#
# nagios plugin that verifies the harddisks (temperature, state)
# of a QNAP NAS (tested on a TS-259 Pro+, firmware 3.8.4)
#
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
# V.1.2 Martin Kasztantowicz, ka@geotek.de - http://geotek.de
# - Corrected Perl Dependencies
# - Allows to specify SNMP community via -C parameter
# - Improved SMART Notification: SMART Status "Normal" is misleading as it indicates a predictive failure warning
#   The script returns a "Warning" condition instead of "Critical" in this case
# - Vertical alignment of visual HDD status looks nicer
# - Add support for newer Qnap models - e.g. TS-879 Pro
# - Don't get confused by emty drive slots (previous version returned UNKNOWN result)

use 5.016;
use strict;
use Monitoring::Plugin;
use Monitoring::Plugin::Getopt;
use SNMP 5.0701;

use constant VERSION => "1.2";
use constant QTREE =>".1.3.6.1.4.1.24681.1.2.";

my ($np,$sess,$anz,@tab,$statc,$statw,$txt,$a,$x);


# check SNMP error code
sub chk_err {
	my $txt = shift;

	if ($sess->{ErrorNum} != 0) {
		$np->nagios_die ("$txt: " . $sess->{ErrorStr});
	}
}


### MAIN ###
$np = Monitoring::Plugin->new(
	usage		=> "Usage: %s -H <host> -C <community> -w <warning-temp> -c <critical-temp> [-t <timeout>]",
	shortname	=> "QNAP HDDs",
	version		=> VERSION,
	timeout		=> 5,
	url		=> "http://www.mgeiger.de/downloads.html",
	blurb		=> "This plugin sends SNMP queries to a QNAP NAS and verifies the state\n" .
			   "of all harddisks (temperature, status, SMART info).",
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
	spec		=> "warning|w=i",
	help		=> "temperature in celsius, when a WARNING is returned",
	required	=> 1,
);

$np->add_arg(
	spec		=> "critical|c=i",
	help		=> "temperature in celsius, when a CRITICAL is returned",
	required	=> 1,
);

$np->getopts;


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


# query number of hdds
$anz = $sess->get(QTREE . "10.0");
chk_err("Get HdNumber");
if (($anz !~ /^\d+$/) || ($anz <= 0) || ($anz > 20)) {
	$np->nagios_die ("HdNumber: " . $anz);
}

# bulk query on SystemHdTable
@tab = $sess->getbulk(0,$anz * 7,QTREE . "11.1");
chk_err("Get SystemHdTable");


# loop all harddisks
$statw = 0;
$statc = 0;
$txt = "";
for ($a = 1; $a <= $anz; $a++) {

	# check if disk is present
	if ($tab[$anz * 3 + $a - 1] !~ -5) {
		# HdTemperature
		$x = $tab[$anz * 2 + $a - 1];
		if ($x =~ /^(\d+) C/) {
			if ($1 >= $np->opts->critical) {
				$statc = 1;
			} elsif ($1 >= $np->opts->warning) {
				$statw = 1;
			}
			$np->add_perfdata(
				label		=> "HDD" . $a . " Temp",
				value		=> $1,
				warning		=> $np->opts->warning,
				critical	=> $np->opts->critical,
			);
			$txt .= "\nHDD" . $a . ": " . $1 . "C";
		}

		# HdStatus
		$x = $tab[$anz * 3 + $a - 1];
		if ($x != 0) {
			$statc = 1;
			$txt .= "  Status: " . $x;
		}

		# HdSmartInfo
		$x = $tab[$anz * 6 + $a - 1];
		if ($x !~ /^GOOD/) {
			if ($x eq "Normal") {
				$statw = 1;
			}
			else {
				$statc = 1;
			}
			$txt .= "  SMART=" . $x;
		}
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

