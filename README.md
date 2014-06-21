switchbackup
============

Backup Nortel/Avaya switches to a ftfp server

## Configuration
In the script are four variables to set:

FTPSERVER=<tftp server>
SNMPCM=<snmp write string>
MAILTO="mail addresses"
SWITCHES="switch names (space separated)"

## Running
Without parameters the SWITCHES variable is used.
./switchbackup.sh

or with a switchname

./switchbackup.sh "switch"
