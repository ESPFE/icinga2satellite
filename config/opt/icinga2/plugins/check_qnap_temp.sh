#!/bin/bash
##################### check_qnap_temp #####################
# Version : 1.0											  #
# Author  : Anthony SCHNEIDER							  #
# Date : Aug 2010										  #
# Licence : GPLv2										  #
###########################################################
# Description : Check CPU/System/HDs temperatures of	  #
# a QNAP using SNMP, originally made for TS-809, but also #
# works with other QNAP (exception with the CPU Temp).	  #
# Tested and works with TS-419 also.					  #
###########################################################
# Infos : It seems CPU Temp cannot be obtained on all QNAP#
# or maybe thanks to an other OID. I could obtain it on	  #
# the TS-809 but not on the TS-419 so i added it only for #
# the 809. But if you really need and if it wotks on	  #
# your QNAP, you can easily add it :)					  #
###########################################################

# Commands
CMD_BASENAME="/bin/basename"
CMD_SNMPWALK="/usr/bin/snmpwalk"

# Script name
SCRIPTNAME=`$CMD_BASENAME $0`

# Version
VERSION="1.0"

# Plugin return statements
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

OID_CPUTEMP="1.3.6.1.4.1.24681.1.2.5"
OID_SYSTEMTEMP=".1.3.6.1.4.1.24681.1.2.6"
OID_HDTEMP=".1.3.6.1.4.1.24681.1.2.11.1.3"
OID_MODELNAME=".1.3.6.1.4.1.24681.1.2.12"

# Default variables
DESCRIPTION="Unknown"
STATE="$STATE_UNKNOWN"
STATE_MESSAGE="UNKNOWN"
CPU_TEMP=""
SYSTEM_TEMP=""
HD_TEMP=""

# Default options
COMMUNITY="public"
HOSTNAME="127.0.0.1"
VERSION="1"
WARNING=0
CRITICAL=0

# Option processing
print_usage() {
  echo "Usage: ./check_qnap_temp.sh -H 127.0.0.1 -C public -w 40 -c 50"
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
  echo "**** Check CPU/System/HDs temperatures ****"
  echo ""
  echo "-H ADDRESS	-> Hostname to query (default: 127.0.0.1)"
  echo "-v STRING	-> SNMP version to use, only compatible with v1 and v2c (default: 1)"
  echo "-C STRING	-> Community for the host SNMP agent (default: public)"
  echo "-w INTEGER	-> Warning threshold in percentage (default: 0)"
  echo "-c INTEGER	-> Critical threshold in percentage (default: 0)"
  echo "-h		-> Print this help"
  echo "-V		-> Print the Plugin version and warranty"
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
       exit "$STATE_UNKNOWN";;
   esac
done

# Plugin processing
# Model slots number
MODEL_SLOTS=`$CMD_SNMPWALK -v $VERSION -c $COMMUNITY $HOSTNAME $OID_MODELNAME -Oav | grep -v '\-\-' | wc -l`

# CPU Temp
CPU_TEMP=`$CMD_SNMPWALK -v $VERSION -c $COMMUNITY $HOSTNAME $OID_CPUTEMP -Oav | cut -c '10-11'`

# System Temp
SYSTEM_TEMP=`$CMD_SNMPWALK -v $VERSION -c $COMMUNITY $HOSTNAME $OID_SYSTEMTEMP -Oav | cut -c '10-11'`

# HD Temp
HD_TEMP=`$CMD_SNMPWALK -v $VERSION -c $COMMUNITY $HOSTNAME $OID_HDTEMP -Oav | cut -c '10-11'`

# Determining how much temps should we consider, according to the number of slots
case "$MODEL_SLOTS" in
	"1") HD_TEMP1=`echo $HD_TEMP | cut -d ' ' -f1`;;
	"2") HD_TEMP1=`echo $HD_TEMP | cut -d ' ' -f1`
		 HD_TEMP2=`echo $HD_TEMP | cut -d ' ' -f2`;;
	"4") HD_TEMP1=`echo $HD_TEMP | cut -d ' ' -f1`
		 HD_TEMP2=`echo $HD_TEMP | cut -d ' ' -f2`
		 HD_TEMP3=`echo $HD_TEMP | cut -d ' ' -f3`
		 HD_TEMP4=`echo $HD_TEMP | cut -d ' ' -f4`;;
	"5") HD_TEMP1=`echo $HD_TEMP | cut -d ' ' -f1`
		 HD_TEMP2=`echo $HD_TEMP | cut -d ' ' -f2`
		 HD_TEMP3=`echo $HD_TEMP | cut -d ' ' -f3`
		 HD_TEMP4=`echo $HD_TEMP | cut -d ' ' -f4`
		 HD_TEMP5=`echo $HD_TEMP | cut -d ' ' -f5`;;
	"6") HD_TEMP1=`echo $HD_TEMP | cut -d ' ' -f1`
		 HD_TEMP2=`echo $HD_TEMP | cut -d ' ' -f2`
		 HD_TEMP3=`echo $HD_TEMP | cut -d ' ' -f3`
		 HD_TEMP4=`echo $HD_TEMP | cut -d ' ' -f4`
		 HD_TEMP5=`echo $HD_TEMP | cut -d ' ' -f5`
		 HD_TEMP6=`echo $HD_TEMP | cut -d ' ' -f6`;;
	"8") HD_TEMP1=`echo $HD_TEMP | cut -d ' ' -f1`
		 HD_TEMP2=`echo $HD_TEMP | cut -d ' ' -f2`
		 HD_TEMP3=`echo $HD_TEMP | cut -d ' ' -f3`
		 HD_TEMP4=`echo $HD_TEMP | cut -d ' ' -f4`
		 HD_TEMP5=`echo $HD_TEMP | cut -d ' ' -f5`
		 HD_TEMP6=`echo $HD_TEMP | cut -d ' ' -f6`
		 HD_TEMP7=`echo $HD_TEMP | cut -d ' ' -f7`
		 HD_TEMP8=`echo $HD_TEMP | cut -d ' ' -f8`;;
esac

# Comparaison with the warnings and criticals thresholds given by user
if [ -n "$SYSTEM_TEMP" ] && [ -n "$HD_TEMP" ]; then
	if [ "$WARNING" != "0" ] || [ "$CRITICAL" != "0" ]; then
		if [ "$MODEL_SLOTS" = "1" ]; then
			if [ "$SYSTEM_TEMP" -gt "$CRITICAL" ] || [ "$HD_TEMP1" -gt "$CRITICAL" ] && [ "$CRITICAL" != "0" ]; then
				STATE="$STATE_CRITICAL"
				STATE_MESSAGE="CRITICAL"
			elif [ "$SYSTEM_TEMP" -gt "$WARNING" ] || [ "$HD_TEMP1" -gt "$WARNING" ] && [ "$WARNING" != "0" ]; then
				STATE="$STATE_WARNING"
				STATE_MESSAGE="WARNING"
			else
				STATE="$STATE_OK"
				STATE_MESSAGE="OK"
			fi
		elif [ "$MODEL_SLOTS" = "2" ]; then
			if [ "$SYSTEM_TEMP" -gt "$CRITICAL" ] || [ "$HD_TEMP1" -gt "$CRITICAL" ] || [ "$HD_TEMP2" -gt "$CRITICAL" ] && [ "$CRITICAL" != "0" ]; then
				STATE="$STATE_CRITICAL"
				STATE_MESSAGE="CRITICAL"
			elif [ "$SYSTEM_TEMP" -gt "$WARNING" ] || [ "$HD_TEMP1" -gt "$WARNING" ] || [ "$HD_TEMP2" -gt "$WARNING" ] && [ "$WARNING" != "0" ]; then
				STATE="$STATE_WARNING"
				STATE_MESSAGE="WARNING"
			else
				STATE="$STATE_OK"
				STATE_MESSAGE="OK"
			fi
		elif [ "$MODEL_SLOTS" = "4" ]; then
			if [ "$SYSTEM_TEMP" -gt "$CRITICAL" ] || [ "$HD_TEMP1" -gt "$CRITICAL" ] || [ "$HD_TEMP2" -gt "$CRITICAL" ] || [ "$HD_TEMP3" -gt "$CRITICAL" ] || [ "$HD_TEMP4" -gt "$CRITICAL" ] && [ "$CRITICAL" != "0" ]; then
				STATE="$STATE_CRITICAL"
				STATE_MESSAGE="CRITICAL"
			elif [ "$SYSTEM_TEMP" -gt "$WARNING" ] || [ "$HD_TEMP1" -gt "$WARNING" ] || [ "$HD_TEMP2" -gt "$WARNING" ] || [ "$HD_TEMP3" -gt "$WARNING" ] || [ "$HD_TEMP4" -gt "$WARNING" ]  && [ "$WARNING" != "0" ]; then
				STATE="$STATE_WARNING"
				STATE_MESSAGE="WARNING"
			else
				STATE="$STATE_OK"
				STATE_MESSAGE="OK"
			fi
		elif [ "$MODEL_SLOTS" = "5" ]; then
			if [ "$SYSTEM_TEMP" -gt "$CRITICAL" ] || [ "$HD_TEMP1" -gt "$CRITICAL" ] || [ "$HD_TEMP2" -gt "$CRITICAL" ] || [ "$HD_TEMP3" -gt "$CRITICAL" ] || [ "$HD_TEMP4" -gt "$CRITICAL" ] || [ "$HD_TEMP5" -gt "$CRITICAL" ] && [ "$CRITICAL" != "0" ]; then
				STATE="$STATE_CRITICAL"
				STATE_MESSAGE="CRITICAL"
			elif [ "$SYSTEM_TEMP" -gt "$WARNING" ] || [ "$HD_TEMP1" -gt "$WARNING" ] || [ "$HD_TEMP2" -gt "$WARNING" ] || [ "$HD_TEMP3" -gt "$WARNING" ] || [ "$HD_TEMP4" -gt "$WARNING" ] || [ "$HD_TEMP5" -gt "$WARNING" ] && [ "$WARNING" != "0" ]; then
				STATE="$STATE_WARNING"
				STATE_MESSAGE="WARNING"
			else
				STATE="$STATE_OK"
				STATE_MESSAGE="OK"
			fi
		elif [ "$MODEL_SLOTS" = "6" ]; then
			if [ "$SYSTEM_TEMP" -gt "$CRITICAL" ] || [ "$HD_TEMP1" -gt "$CRITICAL" ] || [ "$HD_TEMP2" -gt "$CRITICAL" ] || [ "$HD_TEMP3" -gt "$CRITICAL" ] || [ "$HD_TEMP4" -gt "$CRITICAL" ] || [ "$HD_TEMP5" -gt "$CRITICAL" ] || [ "$HD_TEMP6" -gt "$CRITICAL" ] && [ "$CRITICAL" != "0" ]; then
				STATE="$STATE_CRITICAL"
				STATE_MESSAGE="CRITICAL"
			elif [ "$SYSTEM_TEMP" -gt "$WARNING" ] || [ "$HD_TEMP1" -gt "$WARNING" ] || [ "$HD_TEMP2" -gt "$WARNING" ] || [ "$HD_TEMP3" -gt "$WARNING" ] || [ "$HD_TEMP4" -gt "$WARNING" ] || [ "$HD_TEMP5" -gt "$WARNING" ] || [ "$HD_TEMP6" -gt "$WARNING" ]  && [ "$WARNING" != "0" ]; then
				STATE="$STATE_WARNING"
				STATE_MESSAGE="WARNING"
			else
				STATE="$STATE_OK"
				STATE_MESSAGE="OK"
			fi
		elif [ "$MODEL_SLOTS" = "8" ]; then
			if [ "$CPU_TEMP" -gt "$CRITICAL" ] || [ "$SYSTEM_TEMP" -gt "$CRITICAL" ] || [ "$HD_TEMP1" -gt "$CRITICAL" ] || [ "$HD_TEMP2" -gt "$CRITICAL" ] || [ "$HD_TEMP3" -gt "$CRITICAL" ] || [ "$HD_TEMP4" -gt "$CRITICAL" ] || [ "$HD_TEMP5" -gt "$CRITICAL" ] || [ "$HD_TEMP6" -gt "$CRITICAL" ]  || [ "$HD_TEMP7" -gt "$CRITICAL" ]  || [ "$HD_TEMP8" -gt "$CRITICAL" ] && [ "$CRITICAL" != "0" ]; then
			STATE="$STATE_CRITICAL"
			STATE_MESSAGE="CRITICAL"
			elif [ "$CPU_TEMP" -gt "$WARNING" ] || [ "$SYSTEM_TEMP" -gt "$WARNING" ] || [ "$HD_TEMP1" -gt "$WARNING" ] ||  [ "$HD_TEMP2" -gt "$WARNING" ] || [ "$HD_TEMP3" -gt "$WARNING" ] || [ "$HD_TEMP4" -gt "$WARNING" ] || [ "$HD_TEMP5" -gt "$WARNING" ] || [ "$HD_TEMP6" -gt "$WARNING" ] || [ "$HD_TEMP7" -gt "$WARNING" ] || [ "$HD_TEMP8" -gt "$WARNING" ] && [ "$WARNING" != "0" ]; then
			STATE="$STATE_WARNING"
			STATE_MESSAGE="WARNING"
			else
			STATE="$STATE_OK"
			STATE_MESSAGE="OK"
			fi
		fi
	else
		STATE="$STATE_OK"
		STATE_MESSAGE="OK"
	fi
	if [ "$MODEL_SLOTS" = "1" ]; then
		DESCRIPTION="$STATE_MESSAGE - System Temp : $SYSTEM_TEMP Deg. / HDs Temp : $HD_TEMP1 Deg."
	elif [ "$MODEL_SLOTS" = "2" ]; then
		DESCRIPTION="$STATE_MESSAGE - System Temp : $SYSTEM_TEMP Deg. / HDs Temp : $HD_TEMP1 $HD_TEMP2 Deg."
	elif [ "$MODEL_SLOTS" = "4" ]; then
		DESCRIPTION="$STATE_MESSAGE - System Temp : $SYSTEM_TEMP Deg. / HDs Temp : $HD_TEMP1 $HD_TEMP2 $HD_TEMP3 $HD_TEMP4 Deg."
	elif [ "$MODEL_SLOTS" = "5" ]; then
		DESCRIPTION="$STATE_MESSAGE - System Temp : $SYSTEM_TEMP Deg. / HDs Temp : $HD_TEMP1 $HD_TEMP2 $HD_TEMP3 $HD_TEMP4 $HD_TEMP5 Deg."
	elif [ "$MODEL_SLOTS" = "6" ]; then
		DESCRIPTION="$STATE_MESSAGE - System Temp : $SYSTEM_TEMP Deg. / HDs Temp : $HD_TEMP1 $HD_TEMP2 $HD_TEMP3 $HD_TEMP4 $HD_TEMP5 $HD_TEMP6 Deg."
	elif [ "$MODEL_SLOTS" = "8" ]; then
		DESCRIPTION="$STATE_MESSAGE - CPU Temp : $CPU_TEMP Deg. / System Temp : $SYSTEM_TEMP Deg. / HDs Temp : $HD_TEMP1 $HD_TEMP2 $HD_TEMP3 $HD_TEMP4 $HD_TEMP5 $HD_TEMP6 $HD_TEMP7 $HD_TEMP8 Deg."
	fi
else
	DESCRIPTION="$STATE_MESSAGE - Your host is not a QNAP device (default: localhost)! Missing arguments ? Try the help command (-h) to learn more."
fi

echo "$DESCRIPTION"
exit "$STATE"
