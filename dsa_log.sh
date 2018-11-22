#-----------------------------------------------------------------------
#-- Script:             dsa_log.sh
#-- Server:             VHA
#-- Description:        Generates DSA LOGS
#--
#-- Version Date        Author
#-- 01      2018-10-11  A. Tanveer
#-----------------------------------------------------------------------



Jobname=$1
seq=$3$2
homedir=/home/netbackup/dsalog
exportpath=/var/opt/teradata/dsa/export


dsc job_status_log -n $Jobname -full_export
latest=$(ls -tr $exportpath | grep $Jobname | tail -1)
outputfile=$homedir/${seq}_`date '+%Y%m%d.%H%S'`_${latest}
cp $exportpath/$latest ${outputfile}

scp $outputfile an093685@10.37.64.11:/home/an093685/netbackup/dsa_logs/

