#!/bin/bash
# Author: Yevgeniy Goncharov aka xck, http://sys-admin.k
# Script for backup folder and files from list.txt
#
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

_host=`hostname`
_dest="/bkp"
_old=1

for i in `find $_dest -type f -mtime +$_old`; do
	rm -rf $i
done

tar -zcvf /bkp/bkp-$_host-$(date +%d-%m-%Y_%H).tar.gz /etc/ /root/

