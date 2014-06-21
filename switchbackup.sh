#!/bin/bash
#
# Copyright (c) 2011 Sjaak Westdijk
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# 
# Name : switchbackup.sh
# 
# Task : Shell script backup nortel switch configuration
#
# Author : Sjaak Westdijk
#
# Date : 06-11-2012
#
# Description : This shell script provide method to backup
#					 Nortel switch configurations to a tftp server
#
# TODO : - checking for backup failed/succeed
#			- more ascii configuration dumps
#

#

clear

##############################################################################
# User Specified Global Variables
#
##############################################################################
TFTPSERVER=<tftp server>
SNMPCM=<snmp write string>
MAILTO="mail addresses"
SWITCHES="switch names (space separated)"

##############################################################################
# Static Global Variables
#
##############################################################################
VERSION=1.0

TFTPPATH=/tftpboot
SNMPVER=2c
SNMPGET=/usr/bin/snmpget
SNMPSET=/usr/bin/snmpset
LOG=/tmp/backswitch.log

##############################################################################
# Global Variables
#
##############################################################################
SW_CAT=""
RST=""
BP=""
OID_tftpServer=""
OID_bckFileName=""
OID_transferPush=""
OID_sourceFileName=""
pushInteger=""
sourceFileName=""
FMT=""
METHOD=1

##############################################################################
# All OID's for switches
#
##############################################################################
OID_sysDesc=".1.3.6.1.2.1.1.1.0"
OID_sysUpTime=".1.3.6.1.2.1.1.3.0"
OID_sysContact=".1.3.6.1.2.1.1.4.0"
OID_sysName=".1.3.6.1.2.1.1.5.0"
OID_sysLocation=".1.3.6.1.2.1.1.6.0"

OID_imageVersion_wgs=('.iso.org.dod.internet.private.enterprises.45.1.6.3.1.5.0' 's')
OID_diagVersion_wgs=('.iso.org.dod.internet.private.enterprises.45.1.6.3.5.1.1.7.8.1.0.2' 's')

# 470-24 - 470-48 - 420
OID_tftpServer_470=('.iso.org.dod.internet.private.enterprises.45.1.6.4.2.2.1.5.1' 'a')
OID_bckFileName_470=('.iso.org.dod.internet.private.enterprises.45.1.6.4.2.2.1.4.1' 's')
OID_transferPush_470=('.iso.org.dod.internet.private.enterprises.45.1.6.4.2.1.24.0' 'i')
OID_asciibckFileName_470=('.iso.org.dod.internet.private.enterprises.45.1.6.4.4.6.0' 's')
OID_asciitransferPush_470=('.iso.org.dod.internet.private.enterprises.45.1.6.4.4.19.0' 'i')
pushInteger_470=4

# PASSPORT 1600
OID_tftpServer_PP1600=('.iso.org.dod.internet.private.enterprises.2272.1.201.1.1.1.2.2.0' 'a')
OID_bckFileName_PP1600=('.iso.org.dod.internet.private.enterprises.2272.1.201.1.2.1.2.4.0' 's')
OID_transferPush_PP1600=('.iso.org.dod.internet.private.enterprises.2272.1.201.1.2.1.2.6.0' 'i')
pushInteger_PP1600=2

# 4500
OID_bckFileName_4500=('.iso.org.dod.internet.private.enterprises.45.1.6.4.11.1.1.3.1' 's')
OID_transferPush_4500=('.iso.org.dod.internet.private.enterprises.45.1.6.4.11.1.1.4.1' 'i')
pushInteger_4500=3

# PASSPORT 8600 AND PASSPORT 1600 > v2.1.x
pp8600_sourceFileName='/flash/config.cfg'
OID_sourceFileName_PP8600=('.iso.org.dod.internet.private.enterprises.2272.1.100.7.1.0' 's')
OID_destFileName_PP8600=('.iso.org.dod.internet.private.enterprises.2272.1.100.7.2.0' 's')
# e.g. destFileName: STRING: "10.8.177.40:/NG0101.cfg"
OID_transferPush_PP8600=('.iso.org.dod.internet.private.enterprises.2272.1.100.7.3.0' 'i')
pushInteger_PP8600=2

##############################################################################
# log
#
#	local variables :
#	
#
##############################################################################
log()
{
	echo $1 
	echo $1 >> $LOG
}

##############################################################################
# date
#
#	local variables :
#	DATE
#
##############################################################################
datetime()
{
	DATE=`date +"%d%m%Y-%T"`
	log $DATE
}

##############################################################################
# check_alive
#
#	local variables :
#	output
#
##############################################################################
check_alive()
{
	output=`ping $1 | grep alive`
	if [ "${output}" = "" ]; then
		return 0
	fi
	return 1
}

##############################################################################
# identify_system
#
#	local variables :
#	output
# 	SV
# 	DV
#  SD
#
##############################################################################
identify_system()
{
	log "IDENTIFYING system: $1" 	

	output=`${SNMPGET} -v${SNMPVER} -c${SNMPCM} ${S} ${OID_sysName} | cut -d'=' -f2 | sed -e 's/STRING: //'`
	log "System-Name: ${output}"

	SD=`${SNMPGET} -v${SNMPVER} -c${SNMPCM} ${S} ${OID_sysDesc} | cut -d'=' -f2 | sed -e 's/STRING: //'`
	if [[ "${SD}" =~ HW: ]] && [[ "${SD}" =~ FW: ]]; then 
		log "Switch-Type: Workgroupswitch (wgs)"

		SW=`${SNMPGET} -v${SNMPVER} -c${SNMPCM} ${S} ${OID_imageVersion_wgs} | cut -d'=' -f2 | sed -e 's/STRING: //'`
		DW=`${SNMPGET} -v${SNMPVER} -c${SNMPCM} ${S} ${OID_diagVersion_wgs} | cut -d'=' -f2 | sed -e 's/STRING: //'`
		if [[ "${SD}" =~ 425 ]]; then
			log "Switch-Model: Nortel Baystack 425"
			log "Software-Version: ${SW}"
			log "Diagnostic-Version: ${DW}"
			RST=425
			BP=470
		elif [[ "${SD}" =~ 470 ]]; then
			log "Switch-Model: Nortel Baystack 470"
			log "Software-Version: ${SW}"
			log "Diagnostic-Version: ${DW}"
			RST=470
			BP=470_ascii
		elif [[ "${SD}" =~ 4550 ]]; then
			log "Switch-Model: Nortel Ethernet Routing Switch 4550"
			log "Software-Version: ${SW}"
			log "Diagnostic-Version: ${DW}"
			RST=4550
			BP=4500
		elif [[ "${SD}" =~ 4548 ]]; then
			log "Switch-Model: Nortel Ethernet Routing Switch 4548"
			log "Software-Version: ${SW}"
			log "Diagnostic-Version: ${DW}"
			RST=4548
			BP=4500
		elif [[ "${SD}" =~ 5510 ]]; then
			log "Switch-Model: Nortel Ethernet Routing Switch 5510"
			log "Software-Version: ${SW}"
			log "Diagnostic-Version: ${DW}"
			RST=5510
			BP=470_ascii
		elif [[ "${SD}" =~ 5632 ]]; then
			log "Switch-Model: Nortel Ethernet Routing Switch 5632"
			log "Software-Version: ${SW}"
			log "Diagnostic-Version: ${DW}"
			RST=5632
			BP=470_ascii
		else
			log "$1: Failed"
			RST=""
			BP=""
			return 0
		fi
		SW_CAT=wgs
	elif [[ "${SD}" =~ Passport-16 ]] || [[ "${SD}" =~ ERS-16 ]]; then 
		SW=`echo ${SD} | sed -e 's/.*(//' | sed -e 's/).*//'`
		log "Switch-Type: Backboneswitch (bbs)"
		log "Switch-Model: Nortel Ethernet Routing Switch Passport 1600"
		log "Software-Version: ${SW}"
		RST=1624
		BP=8600
		SW_CAT=bbs
	else
		log "$1: Failed"
		return 0
	fi

	return 1
}

##############################################################################
# get_procedure
#
#	local variables :
#
##############################################################################
get_procedure()
{
	METHOD=0

	case $1 in
		470) OID_tftpServer=("${OID_tftpServer_470[@]}")
			OID_bckFileName=("${OID_bckFileName_470[@]}")
			OID_transferPush=("${OID_transferPush_470[@]}")
			pushInteger=("${pushInteger_470[@]}")
			FMT=bin
			METHOD=1
			;;
		470_ascii) OID_tftpServer=("${OID_tftpServer_470[@]}")
			OID_bckFileName=("${OID_asciibckFileName_470[@]}")
			OID_transferPush=("${OID_asciitransferPush_470[@]}")
			pushInteger=("${pushInteger_470[@]}")
			FMT=txt
			METHOD=1
			;;
		4500) OID_bckFileName=("${OID_bckFileName_4500[@]}")
			OID_transferPush=("${OID_transferPush_4500[@]}")
			pushInteger=("${pushInteger_4500[@]}")
			FMT=txt
			METHOD=3
			;;
		8600) OID_sourceFileName=("${OID_sourceFileName_PP8600[@]}")
			OID_bckFileName=("${OID_destFileName_PP8600[@]}")
			OID_transferPush=("${OID_transferPush_PP8600[@]}")
			pushInteger=("${pushInteger_PP8600[@]}")
			sourceFileName=${pp8600_sourceFileName}
			FMT=txt
			METHOD=2
			;;
		*) log "No valid backup procedure found"
			return 0
			;;
	esac
	return 1
}

##############################################################################
# check_bckfile
#
#	local variables :
#
##############################################################################
check_bckfile()
{
	if [ ! -f ${TFTPPATH}/$1-${FMT}.cfg ]; then
		touch ${TFTPPATH}/$1-${FMT}.cfg
		chmod 777 ${TFTPPATH}/$1-${FMT}.cfg
	else
		cp ${TFTPPATH}/$1-${FMT}.cfg ${TFTPPATH}/$1-${FMT}.cfg.old
		
		if [ $( stat -c %s ${TFTPPATH}/$1-${FMT}.cfg.old) = 0 ]; then
			log "Error: empty config file ${FMT}"
		fi
	fi
}

##############################################################################
# get_backup
#
#	local variables :
#
##############################################################################
get_backup()
{
	case ${METHOD} in
		1) log "using traditional save method"
			${SNMPSET} -v${SNMPVER} -c${SNMPCM} $1 ${OID_tftpServer[0]} ${OID_tftpServer[1]} ${TFTPSERVER}
			${SNMPSET} -v${SNMPVER} -c${SNMPCM} $1 ${OID_bckFileName[0]} ${OID_bckFileName[1]} $1-${FMT}.cfg
			;;
		2)
			log "using new tftp copy method"
			destFileName=${TFTPSERVER}:/$1-${FMT}.cfg
			${SNMPSET} -v${SNMPVER} -c${SNMPCM} $1 ${OID_sourceFileName[0]} ${OID_sourceFileName[1]} ${sourceFileName}
			${SNMPSET} -v${SNMPVER} -c${SNMPCM} $1 ${OID_bckFileName[0]} ${OID_bckFileName[1]} ${destFileName}
			;;
		3)
			log "using latest tftp copy method"
			destFileName="tftp://${TFTPSERVER}/$1-${FMT}.cfg"
			${SNMPSET} -v${SNMPVER} -c${SNMPCM} $1 ${OID_bckFileName[0]} ${OID_bckFileName[1]} ${destFileName}
			;;
		*) log "No backup made, wrong method"
			return 0
			;;
	esac

	${SNMPSET} -v${SNMPVER} -c${SNMPCM} $1 ${OID_transferPush[0]} ${OID_transferPush[1]} ${pushInteger}
}

##############################################################################
# usage
#
##############################################################################
usage()
{
	log "switchbackup.sh [<switchname>]"
	log ""
	log "	-h		show help"
	log "without parmeters the switch list will be backuped"
	exit
}
##############################################################################
# main
#
##############################################################################
echo "backupswitch.sh ${VERSION}"
datetime

if [ $# = 1 ]; then
	if [ "$1" = "-h" ]; then 
		usage
	else
		SWITCHES=$1
	fi
fi

for S in ${SWITCHES} 
do	
	log ""
	check_alive ${S}
	if [ $? = 1 ]; then 
		identify_system ${S}
		if [ $? = 1 ]; then 
			get_procedure ${BP}
			if [ $? = 1 ]; then
				check_bckfile ${S}
				get_backup ${S}
			else
				log "no known backyp type for ${BP}"
			fi
		else
			log "No known switch type"
		fi
	else
		log "system not alive"
	fi
done

mailx -s"backupswitch.sh log" ${MAILTO} < ${LOG}
rm ${LOG}
