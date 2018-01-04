#!/bin/bash
#################### check_qnap_cpumem ####################
# Version : 1.0											  #
# Author  : Anthony SCHNEIDER							  #
# Date : Aug 2010										  #
# Licence : GPLv2										  #
###########################################################
# Description : Check CPU Usage, Total Memory, Used		  #
# Memory, Free Memory of a QNAP using SNMP 				  #
###########################################################

# Commands
CMD_BASENAME="/bin/basename"
CMD_SNMPWALK="/usr/bin/snmpwalk"
CMD_BC="/usr/bin/bc"

# Script name
SCRIPTNAME=`$CMD_BASENAME $0`

# Version
VERSION="1.0"

# Plugin return statements
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

OID_CPUUSAGE=".1.3.6.1.4.1.24681.1.2.1"
OID_TOTALMEMORY=".1.3.6.1.4.1.24681.1.2.2"
OID_FREEMEMORY=".1.3.6.1.4.1.24681.1.2.3"

# Default variables
DESCRIPTION="Unknown"
STATE="$STATE_UNKNOWN"
STATE_MESSAGE="UNKNOWN"
CPU_USAGE=""

# Default options
COMMUNITY="public"
HOSTNAME="127.0.0.1"
VERSION="1"
WARNING=0
CRITICAL=0

# Option processing
print_usage() {
  echo "Usage: ./check_qnap_cpumem.sh -H 127.0.0.1 -C public -w 80 -c 90"
  echo "  ./$SCRIPTNAME -H ADDRESS"
  echo "  ./$SCRIPTNAME -v STRING"
  echo "  ./$SCRIPTNAME -C STRING"
  echo "  ./$SCRIPTNAME -w INTEGER"
  echo "  ./$SCRIPTNAME -c INTEGER"
  echo "  ./$SCRIPTNAME -h"
  echo "  ./$SCRIPTNAME -V"
}

print_version() {
  echo "$SCRIPTNAME" version "$VERSION"
  echo "This nagios plugins comes with ABSOLUTELY NO WARRANTY."
  echo "You may redistribute copies of the plugins under the terms of the GNU General Public License v2."
}

print_help() {
  print_version
  echo ""
  print_usage
  echo ""
  echo "**** Check CPU Usage/Total Memory/Used Memory/Free Memory ****"
  echo ""
  echo "-H ADDRESS	- Hostname to query (default: 127.0.0.1)"
  echo "-v STRING	-> SNMP version to use, only compatible with v1 and v2c (default: 1)"
  echo "-C STRING	- Community for the host SNMP agent (default: public)"
  echo "-w INTEGER	- Warning threshold in percentage (default: 0)"
  echo "-c INTEGER	- Critical threshold in percentage (default: 0)"
  echo "-h		- Print this help"
  echo "-V		- Print the Plugin version and warranty"
}

# Arguments
while getopts H:v:C:w:c:hV OPT
do
  case "$OPT" in
    H) HOSTNAME="$OPTARG" ;;
	v) VERSION="$OPTARG";;
    C) COMMUNITY="$OPTARG" ;;
    w) WARNING="$OPTARG" ;;
    c) CRITICAL="$OPTARG" ;;
    h) print_help
       exit "$STATE_UNKNOWN" ;;
    V) print_version 
       exit "$STATE_UNKNOWN" ;;
   esac
done

# Plugin processing
# CPU Usage
CPU_USAGE=`$CMD_SNMPWALK -v $VERSION -c $COMMUNITY $HOSTNAME $OID_CPUUSAGE -Ov | cut -c '10-12'`
PERCENT_CPU_USAGE=`echo $CPU_USAGE | cut -c '1-1'` # Integer needed to check the value at next step

# Total Memory
TOTAL_MEMORY=`$CMD_SNMPWALK -v $VERSION -c $COMMUNITY $HOSTNAME $OID_TOTALMEMORY -Ov | cut -c '10-15'`

# Free Memory
FREE_MEMORY=`$CMD_SNMPWALK -v $VERSION -c $COMMUNITY $HOSTNAME $OID_FREEMEMORY -Ov | cut -c '10-15'`
PERCENT_FREE_MEMORY=`echo "((100*$FREE_MEMORY)/$TOTAL_MEMORY)" | $CMD_BC`

# Used Memory
USED_MEMORY=`echo "($TOTAL_MEMORY-$FREE_MEMORY)" | $CMD_BC`
PERCENT_USED_MEMORY=`echo "((100*$USED_MEMORY)/$TOTAL_MEMORY)" | $CMD_BC`

# Comparaison with the warnings and criticals thresholds given by user
if [ -n "$USED_MEMORY" ] && [ -n "$CPU_USAGE" ]; then
	if [ "$WARNING" != "0" ] || [ "$CRITICAL" != "0" ]; then
		if [ "$PERCENT_USED_MEMORY" -gt "$CRITICAL" ] || [ "$PERCENT_CPU_USAGE" -gt "$CRITICAL" ] && [ "$CRITICAL" != "0" ]; then
			STATE="$STATE_CRITICAL"
			STATE_MESSAGE="CRITICAL"
		elif [ "$PERCENT_USED_MEMORY" -gt "$WARNING" ] || [ "$PERCENT_CPU_USAGE" -gt "$WARNING" ] && [ "$WARNING" != 0 ]; then
			STATE="$STATE_WARNING"
			STATE_MESSAGE="WARNING"
		else
			STATE="$STATE_OK"
			STATE_MESSAGE="OK"
		fi
	else
		STATE="$STATE_OK"
		STATE_MESSAGE="OK"
	fi
	DESCRIPTION="$STATE_MESSAGE - CPU usage : $CPU_USAGE% / Mem. usage: Total: $TOTAL_MEMORY Mb - Used: $USED_MEMORY Mb ($PERCENT_USED_MEMORY%) - Free: $FREE_MEMORY Mb ($PERCENT_FREE_MEMORY%)"
else
	DESCRIPTION="$STATE_MESSAGE - Your host is not a QNAP device (default: localhost)! Missing arguments ? Try the help command (-h) to learn more."
fi

echo "$DESCRIPTION"
exit "$STATE"
