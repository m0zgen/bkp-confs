#!/bin/bash
# Author: Yevgeniy Goncharov aka xck, http://sys-admin.k
# Script for backup folder and files from list.txt

# Variables
# ---------------------------------------------------\
FILEBACKUP=true
LIST=`cat list.txt`
DESTINATION="/dwn/bkp"
FOLDERS=""

DBBACKUP=false
dbuser=""
dbpass=""

# Days
OLD=3
# $(date +%d-%m-%Y_%H-%M-%S)


# Backup folders (enable or disable use FILEBACKUP variable)
# ---------------------------------------------------\

if $FILEBACKUP; then

	while read -r line; do
		# Cut comment lines
	    if [[ -n "$line" && "$line" != [[:blank:]#]* ]]; then
	    	echo "Find folder: $line"
		    FOLDERS+="$line "
	    fi

	done < list.txt

else
	echo "File backup disabled!"

fi

tar -czf $DESTINATION/bkp.$(date +%d-%m-%Y).tar.gz $FOLDERS 2>&1 | grep -v  "Removing leading"


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
