#!/bin/bash
# Author: Yevgeniy Goncharov aka xck, http://sys-admin.k
# Script for backup folder and files from list.txt
#
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Variables
# ---------------------------------------------------\
FILEBACKUP=true
DESTINATION="/dwn/bkp"
LISTFILE="$SCRIPT_PATH/list.txt"
FOLDERS=""

DBBACKUP=false
dbuser=""
dbpass=""

# Days
OLD=3

function check_fileExist() {
	PASSED=$1
	if [[ -d $PASSED ]]; then
	    echo "$PASSED is a directory"
	    return 1
	elif [[ -f $PASSED ]]; then
	    echo "$PASSED is a file"
	    return 1
	else
	    echo "$PASSED is not valid"
	    return 0

	fi
}


check_file(){

        local file="${1}"
        [[ -s "${file}" ]] || { echo "EMPTY"; return; }

        echo "NOT EMPTY";

        [[ -d "${file}" ]] && { echo "DIRECTORY"; return; }

        echo "IS A FILE $file"

    }

# $(date +%d-%m-%Y_%H-%M-%S)
# find /dwn/bkp/ -type f -exec rm {} \;

# Backup folders (enable or disable use FILEBACKUP variable)
# ---------------------------------------------------\

if $FILEBACKUP; then

	while read -r line; do
		# Cut comment lines
	    if [[ -n "$line" && "$line" != [[:blank:]#]* ]]; then

	    	if ! check_fileExist $line; then
	    		echo "aaa"
	    	fi

		    FOLDERS+="$line "
	    fi

	done < $LISTFILE

	tar -czf $DESTINATION/bkp.$(date +%d-%m-%Y).tar.gz $FOLDERS 2>&1 | grep -v  "Removing leading"

else
	echo "File backup disabled!"

fi




# Backup DBs (enable or disable use DBBACKUP variable)
# ---------------------------------------------------\

if $DBBACKUP; then
	#statements
	databases=`mysql -u $dbuser -p$dbpass -e "SHOW DATABASES;" | tr -d "| " | grep -v Database`
 
	for db in $databases; do
	    if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != _* ]] ; then
	        echo "Dumping database: $db"
	        mysqldump --force --opt -u $dbuser -p$dbpass --databases $db > $DESTINATION/$db.`date +%d-%m-%Y`.sql
	        gzip -f $DESTINATION/$db.`date +%d-%m-%Y`.sql
	    fi
	done
else
	echo "DB backup disabled!"	
fi


# Rotate
# ---------------------------------------------------\

for i in `find $DESTINATION -type f -mtime +$OLD`; do
	rm -rf $i
done
