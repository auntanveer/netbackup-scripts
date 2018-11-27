#-----------------------------------------------------------------------
#-- Script:             netbackup_log.sh
#-- Server:             VHA
#-- Description:        Generates Aster nebackup logs
#--
#-- Version Date        Author
#-- 01      2018-10-11  A. Tanveer
#-----------------------------------------------------------------------

#aun=root.`date "+%m%d%y"`


Policy_name=$1
date=$2:
outputfile=/home/netbackup/netbackup_logs/${Policy_name}.$2_$4$3.log
logdir=/var/opt/teradata/openv/netbackup/logs/bpbackup
logfile=$(ls $logdir/root.$date*)
archivefile=$logdir/archive

cat $logdir/$logfile > $outputfile

mv $logdir/$logfile $archivefile/$logfile_`date "+%s"`

scp $outputfile root@39.80.32.62:/home/netbackup/netbackup_log/
