#!/bin/ksh
################################################################################################################################
#
# Program Overview:     Kick off the weekly backup
#
# =====================================================================
# Filename:             bkp_monthly_1.sh
# ---------------------------------------------------------------------
#  Date        Name             Reason
# ---------   ----------------  --------------------------------------------
# 11-22-2018   Aun Tanweer      DSA/Netbackup Monthly backup


VDWADMINSMS=`/usr/bin/grep VDWADMINSMS /etc/profile`
VDWADMINSMS=`echo $VDWADMINSMS | /usr/bin/cut -f2 -d\"`
export VDWADMINSMS

VDW_WK_SUP_BI_SMS=`/usr/bin/grep VDW_WK_SUP_BI_SMS /etc/profile`
VDW_WK_SUP_BI_SMS=`echo $VDW_WK_SUP_BI_SMS | /usr/bin/cut -f2 -d\"`
export VDW_WK_SUP_BI_SMS

SCRIPT=`basename $0`
Pject=MonthlyBackup
initial=m
PLogDir=/home/an093685/netbackup/logs
SrcDir=/home/an093685/netbackup/scripts
RunFile=${SrcDir}/Running_NOW.${Pject}
Backup_Seq=`/bin/cat ${SrcDir}/Monthly_Backup_Seq.dat`
vDate=`date '+%Y%m%d.%H%S'`
OutputDir=/home/an093685/netbackup/output

# Variables used in Export tapes file
NEWOutputfile=${OutputDir}/Teradata_backup_tapes_report_monthly_`date '+%Y%m%d.%H%S'`".txt"
Outputfile=${OutputDir}/Teradata_backup_tapes_`date '+%Y%m%d.%H%S'`".txt"

export Pject # Backup_Seq

# Variables used in bkp_results.sh
PLog=$PLogDir/${SCRIPT}_`date '+%Y%m%d.%H%S'`.log
Bkp_Log=/home/arcadm/outputs

### Variables to Register Backup Set
CTL_DB=Control_db
Resgister_TBL=TapeRegisterOfBackupSet
LOGON_DBM=/load/logondbm.btq

### Variables to run the Stg_actv, VHA_Four and PDCR backup#######
#secs=10800;
#triggerfile=/home/an093685/netbackup/trigger.txt;
mv ${OutputDir}/*.txt ${OutputDir}/archive

#####
##### Register Backup Set
#####
Register_Backup_Set() {
        echo "" >> $PLog
        echo "Register Regular Backup details at `date '+%Y%m%d'.%H%M`" >> $PLog
        echo "" >> $PLog

        /usr/bin/bteq << !EOF >> $PLog
        .Set Sessions 20
        .Run File ${LOGON_DBM};
        SELECT 1
        FROM ${CTL_DB}.${Resgister_TBL}
        WHERE  Job_Name = '${JobName}'
        ;
        .If ActivityCount =0 THEN .GOTO INSERT_RECORD
        .If ActivityCount >= 1 THEN .GOTO UPDATE_RECORD
        .if ErrorCode <> 0 THEN .GOTO EXITWITHERROR
        .LABEL INSERT_RECORD
        INSERT INTO ${CTL_DB}.${Resgister_TBL}
        Values('${JobName}',date);
        .If ActivityCount >= 1 THEN .GOTO ExitOK
        .if ErrorCode <> 0 THEN .GOTO EXITWITHERROR
        .LABEL UPDATE_RECORD
        UPDATE ${CTL_DB}.${Resgister_TBL}
        SET Run_Date=Date
        WHERE JOB_NAME='${JobName}'
        ;
        .If ActivityCount >= 1 THEN .GOTO ExitOK
        .if ErrorCode <> 0 THEN .GOTO EXITWITHERROR
.LABEL EXITWITHERROR
.QUIT ERRORCODE;
.LABEL ExitOK
.Logoff
.QUIT 0;
/*   END OF REPORT  */
!EOF
rc=$?

if  [ $rc -ne 0 ]
then
        echo "" >> $PLog
        echo "ERROR - The backup job has not been registered correctly" >> $PLog
        echo "" >> $PLog
fi

}

############################################################################################################
######## This will kick off the required DSA jobs were the jobname is set prior execution #############
############################################################################################################
Trigger_DB_Job() {

                        Register_Backup_Set

ssh root@vodaaubarp2-95-5 dsc run_job -n $JobName -w >> $PLog 2>&1
        rc=$?
if [ $rc -ne 0 ]; then
    echo "Backup  ${JobName} Failed with return code ${rc}" >> $PLog
else
    echo "Backup  ${JobName} Completed Successfully with return code ${rc}" >> $PLog
fi

ssh -t root@vodaaubarp2-95-5 /home/netbackup/scripts/backup_tapes_report_prod.sh ${JobName}  $rc ${Pject} ${Backup_Seq} ${initial}  2>&1
ssh -t root@vodaaubarp2-95-5 /home/netbackup/scripts/dsa_log.sh ${JobName} ${Backup_Seq} ${initial} 2>&1

        Run_Clear_Ftp
}

############################################################################################################
######## This will kick off the required DSA  jobs were the jobname is set prior execution #############
############################################################################################################
Trigger_DB_Job_2() {

                        Register_Backup_Set
ssh root@vodaaubarp2-95-5 dsc run_job -n $JobName -w >> $PLog 2>&1
        rc=$?
if [ $rc -ne 0 ]; then
    echo "Backup  ${JobName} Failed with return code ${rc}" >> $PLog
else
    echo "Backup  ${JobName} Completed Successfully with return code ${rc}" >> $PLog
fi

ssh -t root@vodaaubarp2-95-5 /home/netbackup/scripts/backup_tapes_report_prod_2.sh ${JobName}  $rc ${Pject} ${Backup_Seq} ${initial}  2>&1
ssh -t root@vodaaubarp2-95-5 /home/netbackup/scripts/dsa_log.sh ${JobName} ${Backup_Seq} ${initial} 2>&1

        Run_Clear_Ftp
}


#####################################################################################################################
# Clear ftp dir1 run
#####################################################################################################################
Run_Clear_Ftp() {

        echo "Process the clear ftp script at `date '+%Y%m%d.%H%S'`" >> $PLog
        /usr/bin/ksh /load/bin/clear_ftp_dir1 >> /load/log/clear_ftp_dir.err &

}


if [ "$1" = "" ]; then
        MMDD=`/usr/bin/date +%m%d`
else
        MMDD=$1
fi
export MMDD

echo "Start of Monthly Backup ${MMDD} at `date '+%Y%m%d.%H%S'`" > $PLog

if [ "${Backup_Seq}" = "" ]; then
	echo "Sequence Number is blank ${Backup_Seq} "  >> $PLog
	exit 1
fi

if [[ ${Backup_Seq} = [12] ]]
then
        echo "Sequence Number ${Backup_Seq} is within the range "  >> $PLog
else
        echo "Sequence Number ${Backup_Seq} is incorrect"  >> $PLog
        exit 1
fi


#####################################################################################################################
# Check for running process
#####################################################################################################################
${SrcDir}/check_running_jobs.sh check >> $PLog 2>&1
rc=$?
if [[ $rc -ne 0 ]]
then
        mailx -s "Check for running process FAILED at: `date '+%Y%m%d.%H%S'`. Please investigate." $VDWADMINSMS << !!EOT
!!EOT
        exit 1
fi

#####################################################################################################################
# Register backup starting time
#####################################################################################################################

####
#### Create latest logon rule list to ensure no unauthorised person can access the Data Warehouse
####
/usr/bin/ksh ${SrcDir}/create_logon_rule_list.ksh  >> $PLog 2>&1


# If the file exists don't start processing
if [ -f $RunFile ]
then
        # Do nothing
                echo "Attemted to re-run the ${Pject} load while still running at `date '+%Y%m%d.%H%M'` " \
                        >> ${PLog}_ReRun
        exit 1
fi

echo `date +%Y-%m-%d` > $RunFile

#####################################################################################################################
# Uncomment the cron
#####################################################################################################################
/usr/bin/ksh ${SrcDir}/set_cron.ksh stop >> $PLog 2>&1

#####################################################################################################################
# Stop Users from accessing the Database
#####################################################################################################################
/usr/bin/ksh ${SrcDir}/turn_off_dbc.ksh >> $PLog 2>&1
rc=$?
if [[ $rc -ne 0 ]]
then
        mailx -s "TESTING Revoking access on all DBC users was not successful at: `date '+%Y%m%d.%H%S'`. Please investigate." $VDWADMINSMS << !!EOT
!!EOT
        exit 1
fi

#####################################################################################################################
# Release all locks (DBC ALL)
#####################################################################################################################
/usr/bin/ksh ${SrcDir}/release_dbc_all.sh >> $PLog 2>&1
rc=$?
if [[ $rc -ne 0 ]]
then
        mailx -s "TESTING Release lock all DBC was not successful at: `date '+%Y%m%d.%H%S'`. Please investigate." $VDWADMINSMS << !!EOT
!!EOT
        exit 1
fi


#SSH to Prod BAR Server & update inventory configuration
#/var/opt/teradata/openv/volmgr/bin/vmupdate -rt TLD -rn 0 -empty_map


#######################################################################################################################
### Backup Dictionary
#######################################################################################################################

JobName=bkp_dict_monthly
Trigger_DB_Job

#######################################################################################################################
### Backup DBC
#######################################################################################################################
##
JobName=bkp_dbc_monthly
Trigger_DB_Job


#####################################################################################################################
#  Grant access to Accesslog user
#####################################################################################################################

/usr/bin/ksh ${SrcDir}/grant_accesslog_access.ksh  >> $PLog &



#####################################################################################################################
#  Accesslog and logonoff Purge
#####################################################################################################################

/usr/bin/ksh ${SrcDir}/Acceslogging_Purge.ksh  >> $PLog &


##########################################################################################################################
# Grant TCF User Accounts access
#########################################################################################################################

/usr/bin/ksh ${SrcDir}/grant_tcf_register.ksh >> $PLog 2>&1

#####################################################################################################################
#  Start SAS PreProcess Queue
#####################################################################################################################

/usr/bin/ksh ${SrcDir}/set_sas.ksh DI ppconly  >> $PLog &
/usr/bin/ksh ${SrcDir}/set_sas.ksh DI asteronly  >> $PLog &

##########################################################################################################################
# grant access to DRAGON user Request raised by Data retention project
##########################################################################################################################

/usr/bin/ksh ${SrcDir}/grant_access_DRAGON.ksh >> $PLog &

##########################################################################################################################
# Backup VHA ONE (Includes AUPR_BUS AUPR_BUS_CTRL, AUPR_PRE_BUS) Target media = 9 LTO5 Tape
#########################################################################################################################

JobName=bkp_vha_one_monthly
Trigger_DB_Job_2

#####################################################################################################################
# Backup VHA TWO Databases (Includes Backup VHA TWO Databases (Includes AUPR_MODELStagging,Model, Model Trans
# AUR_MVNO,AUPR_Ctrl, AUPR_PRE_EDM AUPR_PRE_Model, AUPR_Retired, AUPR_STG_EDM, AUPR_Temp,
# AUPR_Work,Control_db, Prod_Temp_db, AUPR_STG_OTH.S_ASSET) Target media = 9 LTO5 Tape
#####################################################################################################################

JobName=bkp_vha_two_monthly
Trigger_DB_Job_2


#####################################################################################################################
#  Cleanup DBC Database table/s
#####################################################################################################################
#/usr/bin/ksh ${SrcDir}/clean_dbc_tables.ksh >> $PLog 2>&1

#####################################################################################################################
# Grant Users access to the Database
#####################################################################################################################
/usr/bin/ksh ${SrcDir}/turn_on_dbc.ksh >> $PLog 2>&1
rc=$?
if [[ $rc -ne 0 ]]
then
        mailx -s "TESTING Grant access on all DBC users was not successful at: `date '+%Y%m%d.%H%S'`. Please investigate." $VDWADMINSMS << !!EOT
!!EOT
        exit 1
fi

#####################################################################################################################
#  Restore the crontab
#####################################################################################################################

/usr/bin/ksh ${SrcDir}/set_cron.ksh restore >> $PLog 2>&1

       mailx -s "TESTING Please be aware that the CRON has been restored at: `date '+%Y%m%d.%H%S'`. " ${VDW_WK_SUP_BI_SMS} << !!EOT
!!EOT

#####################################################################################################################
#  Start SAS Application Queue
#####################################################################################################################

/usr/bin/ksh ${SrcDir}/set_sas.ksh ALL start  >> $PLog &


#####################################################################################################################
#  Send email notification
#####################################################################################################################


/usr/bin/mailx -s "TESTING set one and two backups are completed to resume daily sales at `date '+%Y%m%d.%H%S'`" ${VDWADMINMAIL} << !!EOT
!!EOT


##############################################################################################################################################
# Backup VHA THREE Databases Includes ALL Databases (Excluding the databases moved to Backup SET  1 and 2)
##############################################################################################################################################

JobName=bkp_vha_three_monthly
Trigger_DB_Job_2

#####################################################################################################################
#  Revoke user logon as per User Governance list
#####################################################################################################################

/usr/bin/ksh ${SrcDir}/revoke_access_byUAM_list.ksh  >> $PLog &



#####################################################################################################################
#  Send email notification
#####################################################################################################################



/usr/bin/mailx -s "TESTING TESTING VODAU5 Backup has completed with Set 3 at `date '+%Y%m%d.%H%S'`" ${VDWADMINMAIL} << !!EOT
!!EOT

usr/bin/mailx -s "TESTING TESTING Backup is completed. Please stop GG immediately at `date '+%Y%m%d.%H%S'`" ${VDW_GG_SMS} << !!EOT
!!EOT
/usr/bin/mailx -s "TESTING TESTING Backup is completed. Please stop GG immediately at `date '+%Y%m%d.%H%S'`" ${VDW_GG_MALL} << !!EOT
!!EOT

#while [ ! -f "$triggerfile" ]
#do
#
#sleep 60;
#
#: $((secs=secs-60))
#if [ $secs -lt 0 ]
#then
#echo 'File not found' $triggerfile >> $PLog &
#
#exit
#fi
#
#
#done
#
#rm -f $triggerfile
#
#echo "########Triggering the STG_ACTV,VHA_FOUR,PDCR backups########" >> $PLog &
#
###############################################################################################################################################
## Backup VHA STG_ACTV Databases
###############################################################################################################################################
#
#JobName=bkp_vha_stg_actv_monthly
#Trigger_DB_Job
#
###############################################################################################################################################
## Backup VHA Four Databases
###############################################################################################################################################
#
#JobName=bkp_vha_four_monthly
#Trigger_DB_Job
#
#
###############################################################################################################################################
## Backup VHA PDCR Databases
###############################################################################################################################################
#
#JobName=bkp_vha_pdcr_monthly
#Trigger_DB_Job
#
######################################################################################################################
##Formating the Columns of the outputfile
######################################################################################################################
#cat ${OutputDir}/*.txt >$Outputfile
#column -t $Outputfile > $NEWOutputfile
#sed -i $'1 i\\\MEDIA_ID\,LAST_WRIITTEN\,POLICY_NAME\,STATUS\,Backup_type\,Backup_seq' $NEWOutputfile
#
#rm -f $Outputfile
#
#
#
######################################################################################################################
##  Send email notification
######################################################################################################################
#/usr/bin/mailx -s "TESTING TESTING VODAU5 Export tapes report at `date '+%Y%m%d.%H%S'`" ${VDWADMINMAIL} < $NEWOutputfile << !!EOT
