#!/bin/bash
##########################################################
# Generates Password for Service Account in LZ Test ENV 
# Author: Darshan S Mahendrakar (y270206)
#
#
##########################################################


log()
{
    local header=$INFO_STMT
    if [ $1 = $ERROR ]
    then
        header=$ERROR_STMT

    elif [ $1 = $WARN ]
    then
        header=$WARN_STMT
    fi
    echo "${header}|$2"
    echo "${header}|$2" >> $logfile
}
source /platform/env/server_env.sh
source /users/lzwsp/run/workspace/scripts/workspace_env.sh
logfile=/var/log/lz/lzwsp/platform/password_creator_`date +\%y\%m`.log

function userCheck() {
   if [[ $USER = "lzwsp" || $ENV = "TEST" &&  $USER = "lzwsp" || $ENV = "DEV" ]]; then 
   log $INFO "PASSWORD ADDER STARTED"
   else
   log $INFO "********************************************************"
   log $INFO "This script must be executed as  LZWSP ONLY !"
   log $INFO "********************************************************"
       exit 1
    fi
}
userCheck

if [ `ls ${PASSWORD_FILE_DIR}/${PASSWORD_WILDCARD} | wc -l`  -eq 0 ]
then
log $INFO  "***************************"
log $INFO  "	No files to process"
log $INFO  "***************************"
    exit 0
fi


for x in `ls ${PASSWORD_FILE_DIR}/${PASSWORD_WILDCARD}`
do

y=(`basename ${x%%_*_*.password}`)
log $INFO "User= $y"
/usr/bin/kinit hdfs -k -t ~/.keytab/hdfs.keytab
hdfs dfs -test -d /user/$y
 res=$?
    if [ $res -eq 0 ]
    then
        # log $INFO "/user/$y is available"
	/usr/bin/kinit hdfs -k -t ~/.keytab/hdfs.keytab
	 hdfs dfs -test -d /user/$y/.password
	 res=$?
       		 if [ $res -eq 1 ]
   		 then
        		hdfs dfs -mkdir /user/$y/.password
    		 fi
     else
         log $INFO "/user/$y is not available"
    fi
z=`echo ${x#*_}`
pass=`cat $x`
echo -n "$pass" > $z

group="lzg"`echo ${y} | cut -c3-`
/usr/bin/kinit hdfs -k -t ~/.keytab/hdfs.keytab
hdfs dfs -put -f $z /user/$y/.password/
hdfs dfs -chown -R $y:$group /user/$y/.password/
hdfs dfs -chmod -R 700 /user/$y/.password/
echo "`date +\%y\%m\%d/\%H:\%M`|$y|$group|$z|$pass" >> /users/lzwsp/run/common/password_runner.log

rm -rf $z $x
log $INFO "$z for HDFS user $y created and password file deleted."
done

