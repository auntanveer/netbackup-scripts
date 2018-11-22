#-----------------------------------------------------------------------
#-- Script:             backup_tapes_report_prod_2.sh
#-- Server:             VHA
#-- Description:        Generates report containing Media ID for Teradata backups which ran in last 24 hours for two policies.
#--
#-- Version Date        Author
#-- 01      2018-10-11  A. Tanveer
#-----------------------------------------------------------------------

Polname=$1
policy_name1=${Polname}_1
policy_name2=${Polname}_2
outputfile=/home/netbackup/output/${Polname}_`date '+%Y%m%d.%H%S'`".txt"
status=$2
Backup_type=$3
Backup_seq=$5$4

rm -f /tmp/temp1.txt
rm -f /tmp/temp2.txt

cd /usr/openv/netbackup/bin/admincmd

./bpimagelist -U -media -pt Teradata -hoursago 24 -policy $policy_name1 > /tmp/temp1.txt

sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' /tmp/temp1.txt | awk '{print $1 "\," $3}' |tail -n +3 | awk '{print $0"\," "'$policy_name'""\," "'$status'""\," "'$Backup_type'""\," "'$Backup_seq'"}' >> $outputfile


./bpimagelist -U -media -pt Teradata -hoursago 24 -policy $policy_name2 > /tmp/temp2.txt

sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' /tmp/temp2.txt | awk '{print $1 "\," $3}' |tail -n +3 | awk '{print $0"\," "'$policy_name'""\," "'$status'""\," "'$Backup_type'""\," "'$Backup_seq'"}' >> $outputfile


scp $outputfile an093685@10.37.64.11:/home/an093685/netbackup/output/
