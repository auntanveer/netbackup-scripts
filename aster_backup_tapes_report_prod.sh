#-----------------------------------------------------------------------
#-- Script:             aster_backup_tapes_report_prod.sh
#-- Server:             VHA
#-- Description:        Generates report containing Media ID for Teradata backups which ran in last 24 hours.
#--
#-- Version Date        Author
#-- 01      2018-10-11  A. Tanveer
#-----------------------------------------------------------------------

policy_name=$1
outputfile=/home/netbackup/output/${policy_name}_`date '+%Y%m%d.%H%S'`".txt"
#outputfile=/home/netbackup/output/test1_`date '+%Y%m%d.%H%S'`".txt"
status=$2
Backup_type=$3
Backup_seq=$5$4




rm -f /tmp/temp1.txt


cd /usr/openv/netbackup/bin/admincmd

./bpimagelist -U -media  -hoursago 24 -policy $policy_name > /tmp/temp1.txt

sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' /tmp/temp1.txt | awk '{print $1 "\," $3}' |tail -n +3 | awk '{print $0"\," "'$policy_name'""\," "'$status'""\," "'$Backup_type'""\," "'$Backup_seq'"}' >> $outputfile

scp $outputfile root@39.80.32.62:/home/netbackup/output/
