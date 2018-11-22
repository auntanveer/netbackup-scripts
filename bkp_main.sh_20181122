#!/usr/bin/ksh
###################################################################################################################
#                     MODIFICATION HISTORY
#
#  Program Name :  bkp_main.sh
#  Description  :  Backup the Data Warehouse on either weekly or monthly base
#  Usage        :
#
#  Date        Name              Reason
# ---------   ----------------   ---------------------------------------------------------------------------------
# 2018-17-11   Aun Tanweer        Monthly/weekly call scripts

integer vDD=`/usr/bin/date +%d`
SrcDir=/home/an093685/netbackup/scripts



        if [[ $vDD -le 7 ]]
        then
                echo "Start the Monthly backup "
                /usr/bin/ksh ${SrcDir}/bkp_monthly_1.sh
                rc=$?
        else
                echo "Start the Weekly backup "
                /usr/bin/ksh ${SrcDir}/bkp_weekly_1.sh
                rc=$?
        fi

