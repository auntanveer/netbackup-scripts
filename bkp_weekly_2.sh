#!/bin/ksh
################################################################################################################################
#
# Program Overview:     Kick off the weekly backup
#
# =====================================================================
# Filename:             bkp_weekly_2.sh
# ---------------------------------------------------------------------
#
#  Description :        Weekly backup of Teradata & Linux
#                               - Backup of Teradata Production system to LTO5 Tapes
#  Important Note:
#
#  Date        Name             Reason
# ---------   ----------------  --------------------------------------------
# 20-11-2018  Aun Tanweer        DSA/Netbackup jobs

VDWADMINSMS=`/usr/bin/grep VDWADMINSMS /etc/profile`
VDWADMINSMS=`echo $VDWADMINSMS | /usr/bin/cut -f2 -d\"`
export VDWADMINSMS

VDW_WK_SUP_BI_SMS=`/usr/bin/grep VDW_WK_SUP_BI_SMS /etc/profile`
VDW_WK_SUP_BI_SMS=`echo $VDW_WK_SUP_BI_SMS | /usr/bin/cut -f2 -d\"`
export VDW_WK_SUP_BI_SMS

SCRIPT=`basename $0`
Pject=WeeklyBackup
initial=w
PLogDir=/home/an093685/netbackup/logs
SrcDir=/home/an093685/netbackup/scripts
RunFile=${SrcDir}/Running_NOW.${Pject}
Backup_Seq=`/bin/cat ${SrcDir}/Backup_Seq.dat`
vDate=`date '+%Y%m%d.%H%S'`
OutputDir=/home/an093685/netbackup/output

# Variables used in Export tapes file
NEWOutputfile=${OutputDir}/Teradata_backup_tapes_report_prod_`date '+%Y%m%d'`".txt"
Outputfile=${OutputDir}/reports/export_media/Teradata_backup_tapes_`date '+%Y%m%d'`".txt"

export Pject # Backup_Seq

# Variables used in bkp_results.sh
PLog=$PLogDir/${SCRIPT}_`date '+%Y%m%d.%H%S'`.log
Bkp_Log=/home/arcadm/outputs

### Variables to Register Backup Set
CTL_DB=Control_db
Resgister_TBL=TapeRegisterOfBackupSet
LOGON_DBM=/load/logondbm.btq


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

ssh root@39.82.248.5 dsc run_job -n $JobName -w >> $PLog 2>&1
        rc=$?
if [ $rc -ne 0 ]; then
    echo "Backup  ${JobName} Failed with return code ${rc}" >> $PLog
else
    echo "Backup  ${JobName} Completed Successfully with return code ${rc}" >> $PLog
fi

ssh -t root@39.82.248.5 /home/netbackup/scripts/backup_tapes_report_prod.sh ${JobName}  $rc ${Pject} ${Backup_Seq} ${initial} 2>&1
ssh -t root@39.82.248.5 /home/netbackup/scripts/dsa_log.sh ${JobName} ${Backup_Seq} ${initial} 2>&1

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

echo "Start of Weekly Backup ${MMDD} at `date '+%Y%m%d.%H%S'`" > $PLog

if [ "${Backup_Seq}" = "" ]; then
        echo "Sequence Number is blank ${Backup_Seq} "  >> $PLog
        exit 1
fi

if [[ ${Backup_Seq} = [1234] ]]
then
        echo "Sequence Number ${Backup_Seq} is within the range "  >> $PLog
else
        echo "Sequence Number ${Backup_Seq} is incorrect"  >> $PLog
        exit 1
fi


#####################################################################################################################
# Disable GG user logon before stg actv backup
#####################################################################################################################
/usr/bin/ksh ${SrcDir}/set_golden_gate.ksh >> $PLog 2>&1

##############################################################################################################################################
# Backup VHA STG ACTIVE Database
##############################################################################################################################################

JobName=bkp_vha_stg_actv_weekly
Trigger_DB_Job

##########################################################################################################################
# Grant Golden Gate User Accounts access
#########################################################################################################################

/usr/bin/ksh ${SrcDir}/grant_gg_register.ksh >> $PLog 2>&1


#####################################################################################################################
#  Send email notification
#####################################################################################################################


/usr/bin/mailx -s "Stg actv Backup has completed and Please ask infra DBA to enable GG at `date '+%Y%m%d.%H%S'`" ${VDWADMINMAIL} << !!EOT
!!EOT


##############################################################################################################################################
# Backup VHA Four Databases
################################################################################################################################################
##
JobName=bkp_vha_four_weekly
Trigger_DB_Job
##
##
###############################################################################################################################################
# Backup VHA PDCR Databases
################################################################################################################################################
##
JobName=bkp_vha_pdcr_weekly
Trigger_DB_Job
##
#######################################################################################################################
#Formating the Columns of the outputfile
#####################################################################################################################
cat ${OutputDir}/*.txt >$Outputfile
column -t $Outputfile > $NEWOutputfile
sed -i $'1 i\\\MEDIA_ID\,LAST_WRIITTEN\,POLICY_NAME\,STATUS\,Backup_type\,Backup_seq' $NEWOutputfile

rm -f $Outputfile

############################################################
# Rotate back to first generation if last rotation number
############################################################

if [ ${Backup_Seq} = 4 ]; then
        Backup_Seq=0
fi

############################################################
# Increment ROTATION counter for next run
############################################################

/usr/bin/echo ${Backup_Seq} + 1 | bc > ${SrcDir}/Backup_Seq.dat

/bin/rm -f $RunFile  >> $PLog 2>&1


