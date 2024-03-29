#!/bin/bash
# Author: Yevgeniy Goncharov aka xck, http://sys-adm.in
# Script for backup folder and files from list.txt

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
SCRIPT_NAME=${0##*/}

# Init Variables
# ---------------------------------------------------\
HOSTNAME=`hostname`
SERVER_IP=`hostname -I`

LISTFILE="$SCRIPT_PATH/list.txt"
FOLDERS=""

# Enable or disable backup files and folders from list.txt
FILEBACKUP=true
DESTINATION="/dest-bkp"

# Dumps from command executes aka crontabs
DUMPBACKUP=true
DUMPS="$DESTINATION/dumps"

# Enable or disable MySQL database backups
DBBACKUP=false
dbuser=""
dbpass=""

# Enable or disable Mongo database backups
MONGOBACKUP=false
mdbuser=""
mdbpass=""

# Enable or disable remote backups (need cifs)
REMOTEBACKUP=false
WINSHARE="//server/kvm-backup$"
MOUNTSHARE="/mnt/remote-bkp"
REMOTEUSER="user"
REMOTEUSERPASS="pass"

# How long store backups in DESTINATION
OLD=30

# Output messages
# ---------------------------------------------------\

# And colors
RED='\033[0;91m'
GREEN='\033[0;92m'
CYAN='\033[0;96m'
YELLOW='\033[0;93m'
PURPLE='\033[0;95m'
BLUE='\033[0;94m'
BOLD='\033[1m'
WHiTE="\e[1;37m"
NC='\033[0m'

ON_SUCCESS="DONE"
ON_FAIL="FAIL"
ON_ERROR="Oops"
ON_CHECK="✓"

Info() {
  echo -en "[${1}] ${GREEN}${2}${NC}\n"
}

Warn() {
  echo -en "[${1}] ${PURPLE}${2}${NC}\n"
}

Success() {
  echo -en "[${1}] ${GREEN}${2}${NC}\n"
}

Error () {
  echo -en "[${1}] ${RED}${2}${NC}\n"
}

Splash() {
  echo -en "${WHiTE} ${1}${NC}\n"
}

space() { 
  echo -e ""
}

# Helpers
# ---------------------------------------------------\
# Help information
usage() {

	space
	Info "Info" "Script usage information:"
	Info "$ON_CHECK" "./$SCRIPT_NAME	: Local backup (from $LISTFILE)"
	Info "$ON_CHECK" "./$SCRIPT_NAME -r	: Remote backup over SSH ($LISTFILE will be automatically copied to remote server)"
	space
	Info "Info" "Remote example:"
	Info "$ON_CHECK" "ssh server < ./$SCRIPT_NAME -r"
	space
	
	exit 1

}

# Checks arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--remote) REMOTE=1; ;;
		-h|--help) usage ;;	
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Functions
# ---------------------------------------------------\

function backupCrontabCurrentUser {

	crontab -l > $DUMPS/crontab.txt

}

function checkfolder {

	# Проверяем на наличие существующих
	if [ -d "$1" ]
		then
		echo "Check $1 succesfully!"
	else
		echo "Create $1 ..."
		mkdir -p $1
	fi

}

function check_fileExist() {
	PASSED=$1

	if [[ -d $PASSED ]]; then
	    # echo "$PASSED is a directory"
	    return 1
	elif [[ -f $PASSED ]]; then
	    # echo "$PASSED is a file"
	    return 1
	else
	    # echo "$PASSED is not valid"
	    return 0

	fi
}

function get_time {
	# echo $(date +%d-%m-%Y_%H-%M-%S)
	echo $(date +%d-%m-%Y_%H)
}

function mountFolder {

	# Mount
	if mount|grep $MOUNTSHARE > /dev/null 2>&1; then
	echo -e "\nAlready mounted...\n"
	else
		echo -e "\nNot mounted... Mounting....\n"
		/usr/bin/mount -t cifs -o username=$REMOTEUSER,password=$REMOTEUSERPASS $WINSHARE $MOUNTSHARE
		sleep 2
	fi
}

function umountFolder {

	# Umount
	if mount|grep $LOCALMNTFOLDER > /dev/null 2>&1; then
		sleep 2
		umount -f -a -t cifs -l
		sleep 2
	else
		echo "Mounted... unmount..."
	fi

}

# find /dwn/bkp/ -type f -exec rm {} \;

# Backup folders (enable or disable use FILEBACKUP variable)
# ---------------------------------------------------\

checkfolder "$DESTINATION"
checkfolder "$DUMPS"

# Backup files and folders from list.txt
if $FILEBACKUP; then

	# Read data from list.txt
	while read -r line; do

		# Cut comment lines
	    if [[ -n "$line" && "$line" != [[:blank:]#]* ]]; then

	    	# Check folder or file exist
	    	if ! check_fileExist $line; then

	    		# If exist, add to folder / files list
	    		FOLDERS+="$line "
	    	fi

	    fi

	done < $LISTFILE

	# Backup command results to file dumps
	if $DUMPBACKUP; then

		backupCrontabCurrentUser
		FOLDERS+="$DUMPS"

	fi

	# Pack folder and files from FOLDERS list
	tar -czf $DESTINATION/bkp-$HOSTNAME.$(get_time).tar.gz $FOLDERS 2>&1 | grep -v  "Removing leading"
	rm -rf $DUMPS

else
	echo "File backup disabled!"

fi

# Backup DBs (enable or disable use DBBACKUP variable)
# ---------------------------------------------------\

if $DBBACKUP; then

	# Connect to database server, show databases, grep database names
	databases=`mysql -u $dbuser -p$dbpass -e "SHOW DATABASES;" | tr -d "| " | grep -v Database`

	for db in $databases; do
	    if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != _* ]] ; then
	        echo "Dumping database: $db"
	        mysqldump --force --opt -u $dbuser -p$dbpass --databases $db > $DESTINATION/$db.$(get_time).sql
	        gzip -f $DESTINATION/$db.$(get_time).sql
	        rm -rf $DESTINATION/$db.$(get_time).sql
	    fi
	done
else
	echo "DB backup disabled!"
fi

# Backup DBs (enable or disable use MONGOBACKUP variable)
# ---------------------------------------------------\

if $MONGOBACKUP; then

	#TODO - add checking mongodb exists
	MONGOBKPFOLDER="$DESTINATION/mongo/"

	checkfolder $MONGOBKPFOLDER

	mongodump --host=localhost --port=27017 --out=$MONGOBKPFOLDER

	tar -czf $DESTINATION/bkp-mongo-$HOSTNAME.$(get_time).tar.gz $MONGOBKPFOLDER 2>&1 | grep -v  "Removing leading"
	rm -rf $MONGOBKPFOLDER

else
	echo "MongoDB backup disabled!"
fi

# Copy backup to remote
# ---------------------------------------------------\
if $REMOTEBACKUP; then
	# Create and mount folders
	checkfolder $MOUNTSHARE
	mountFolder

	# Checking and create host folder for backups
	HOSTFOLDER=$MOUNTSHARE/$HOSTNAME-confs
	checkfolder $HOSTFOLDER

	# Copy fom local backup to remote
	rsync -av --delete $DESTINATION $HOSTFOLDER

	# Umount mounted share
	umount $MOUNTSHARE
fi


# Rotate (check backup folder, find files age over OLD, them delete)
# ---------------------------------------------------\

for i in `find $DESTINATION -type f -mtime +$OLD`; do
	rm -rf $i
done
