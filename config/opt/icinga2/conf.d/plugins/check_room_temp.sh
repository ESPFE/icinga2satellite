#!/bin/bash

# Commands
CMD_BASENAME="/bin/basename"


# Script name
SCRIPTNAME=`$CMD_BASENAME $0`

# Version
VERSION="1.0"

# Default Variables
STATE_MESSAGE="UNKNOWN"
OUTPUT=""


# Plugin return statements
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

IP_ADDRESS=${1}
OID_TEMP="1.3.6.1.4.1.21796.4.9.3.1.4.1"


# Option processing
print_usage() {
	echo "Usage: ./check_raum_temp.sh -H 192.168.28.12 -w 30 -c 35"
	echo "  ./$SCRIPTNAME -H ADDRESS"
	echo "  ./$SCRIPTNAME -w INTEGER"
	echo "  ./$SCRIPTNAME -c INTEGER"
	echo "  ./$SCRIPTNAME -h"
	echo "  ./$SCRIPTNAME -V"
}

print_version() {
	echo "$SCRIPTNAME" version "$VERSION"
	echo "This Plugin comes with ABSOLUTELY NO WARRANTY"
}

print_help() {
	print_version
	echo ""
	print_usage
	echo ""
	echo "**** Check Room temperatures ****"
	echo ""
	echo "-H ADDRESS -> Hostname to query"
	echo "-w INTEGER -> Warning threshold in percentage"
	echo "-c INTEGER -> Critical threshold in percentage"
	echo "-h 	   -> Print this help"
	echo "-V	   -> Print the Plugin verion and warranty"
}

# Arguments
while getopts H:v:C:w:c:hV OPT
do
	case "$OPT" in 
		H) HOSTNAME="$OPTARG" ;;
			v) VERSION="$OPTARG" ;;
		C) COMMUNITY="$OPTARG" ;;
		w) WARNING="$OPTARG" ;;
		c) CRITICAL="$OPTARG" ;;
		h) print_help
		exit "$STATE_UNKNOWN" ;;
		V) print_version
		exit "$STATE_UNKNOWN" ;;
	esac
done

#Plugin processing
OUTPUT=$(snmpget -v1 -cpublic $HOSTNAME 1.3.6.1.4.1.21796.4.9.3.1.5.1| cut -c '54-')


RECHNUNG=$(expr $OUTPUT / 10)



if [ "$RECHNUNG" -gt "$CRITICAL" ] && [ "$CRITICAL" != "0" ]; then
	STATE_MESSAGE="CRITICAL"

elif [ "$RECHNUNG" -gt "$WARNING" ] && [ "$WARNING" != "0" ]; then
	STATE_MESSAGE="WARNING"
else
	STATE_MESSAGE="OK"
fi



echo The Room Temperature is $RECHNUNG Degrees
echo  Info: $STATE_MESSAGE

exit 
