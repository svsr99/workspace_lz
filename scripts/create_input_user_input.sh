#!/bin/bash
# Platform Team Landing ZONE
# Author : Darshan S Mahendrakar
# Input format : create_raw_space, appid, hdfs dir , db name , size , env

# get_roles_group will retrieve the correct AD group that needs to be assigned based on the target environment and target role
get_roles_group() {
	if [[ $# -ne 3 ]]; then
		echo "get_roles_group : missing the appid, role or variable parameter."
		echo 1
	fi

	if [[ ${2} != ${ROLE_POWERUSER} && ${2} != ${ROLE_ANALYST} ]]; then
		echo "get_roles_group : Invalid role.  Accepted Roles are POWERUSER and ANALYST"
		echo 1
	fi
	appid=$1
	role=$2
	role_group="ROLE_${role}_GROUP_${env}"
	echo "App id : ${appid}; Role : ${role}; Role Group : ${role_group}; variable : ${3}"
	eval "${3}=${!role_group}${appid:2}"
}

get_workspace_information() {
        echo "Enter:  <APPID> <HDFS_DIR> <DB_NAME> <SIZE> <ENV> for ${space}"
        read appid hdfs dbname size env
        echo "$appid $hdfs $dbname $size $env"

        if [[ -z ${appid} || -z ${hdfs} || -z ${dbname} || -z ${size} || -z ${env} ]]; then
                echo "Some information are missing. Please try again."
                exit 1
        fi

        # Convert to lower case
        appid=`echo ${appid} | tr 'A-Z' 'a-z'`
        hdfs=`echo ${hdfs} | tr 'A-Z' 'a-z'`
        dbname=`echo ${dbname} | tr 'A-Z' 'a-z'`
        env=`echo ${env} | tr 'a-z' 'A-Z'`
        group="lzg"`echo ${appid} | cut -c3-`
        raw_dbname="${dbname}_raw"
	group_dbname="${dbname}_uda"
	get_roles_group ${appid} ${ROLE_POWERUSER} poweruser_group
	get_roles_group ${appid} ${ROLE_ANALYST} analyst_group


        if [[ ${space} = "REFINED" ]]; then
                echo "Do you need a group workspace for this refined space? (y/n)"
                read group_required_yn
                group_required_yn=`echo ${group_required_yn} | tr 'A-Z' 'a-z'`

		if [[ ${group_required_yn} = "y" ]]; then
			echo "What is the size of the group workspace?"
			read group_size
		fi
        fi

	if [[ ${space} = "GROUP" || ${group_required_yn} = "y" ]]; then
		echo "Do you need Group UDA / Scratchpad Databases? (y/n)"
        	read uda_ans
        	uda_ans=`echo ${uda_ans} | tr 'A-Z' 'a-z'`
	fi


}

get_space_qouta(){
echo "im in space quota"

}
create_staging() {
	echo "Enter:  <APPID> <DIR_NAME> <ENV> for ${space}"
        read appid dirname env
	if [[ -z ${appid} || -z ${dirname} || -z ${env} ]]; then
                echo "Some information are missing. Please try again."
                exit 1
        fi

        # Convert to lower case
        appid=`echo ${appid} | tr 'A-Z' 'a-z'`
        dirname=`echo ${hdfs} | tr 'A-Z' 'a-z'`
        env=`echo ${env} | tr 'a-z' 'A-Z'`
	group="lzg"`echo ${appid} | cut -c3-`
	echo $appid $group $dirname $env
	echo "CREATE|STAGING|${dirname}|${appid}|${group}" >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp	
	
}

create_raw_input() {
         echo "CREATE|DATA_RAW|${hdfs}|${appid}|${group}|${size}" >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
         echo "CREATE|DATABASE|RAW|${raw_dbname}|${hdfs}" >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
         echo "CREATE|ROLE|${appid}|${group}|ADMIN|URI:DATA_RAW:${appid}:ALL,DB_RAW:${raw_dbname}:ALL"  >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
}


create_refined_input() {
	echo "CREATE|DATA_REFINED|${hdfs}|${appid}|${group}|${size}" >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
	echo "CREATE|DATABASE|REFINED|${dbname}|${hdfs}" >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
	echo "CREATE|ROLE|${appid}|${group}|ADMIN|URI:DATA_REFINED:${hdfs}:ALL,DB_REFINED:${dbname}:ALL"  >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
	echo "CREATE|ROLE|${appid}|${poweruser_group}|${ROLE_POWERUSER}|DB_REFINED:${dbname}:SELECT"  >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
	echo "CREATE|ROLE|${appid}|${analyst_group}|${ROLE_ANALYST}|DB_REFINED:${dbname}:SELECT" >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
}

create_group_input() {
	if [[ ${uda_ans} = "y" ]]; then
        	echo "CREATE|GROUP|${hdfs}|${appid}|${group}|${size}" >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
      	        echo "CREATE|DATABASE|GROUP|${group_dbname}|${hdfs}" >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp	
                echo "CREATE|ROLE|${appid}|${poweruser_group}|${ROLE_POWERUSER}|URI:GROUP:${hdfs}:ALL,DB_GROUP:${group_dbname}:ALL"  >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
                echo "CREATE|ROLE|${appid}|${analyst_group}|${ROLE_ANALYST}|DB_GROUP:${group_dbname}:SELECT" >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
	else
                echo "CREATE|GROUP|${hdfs}|${appid}|${group}|${size}" >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
                echo "CREATE|ROLE|${appid}|${poweruser_group}|${ROLE_POWERUSER}|URI:GROUP:${hdfs}:ALL"  >> ${GENERATED_WSP_DIR}/${appid}_${env}.wsp
	fi
}


################################# Main Function ###########################################
source /platform/env/server_env.sh
source ./workspace_env.sh
if [[ $? -ne 0 ]]; then
 	echo "workspace_env.sh found in default directory"
	source ~/run/workspace/scripts/workspace_env.sh
	if [[ $? -ne 0 ]]; then
		log $INFO "workspace_env.sh cannot be found.  Exiting"
		exit 1
	fi
fi

echo "Welcome to Landing Zone "
echo "Please enter type of input file to be created. "
echo "RAW, REFINED, GROUP, STAGING"
read space
space=`echo ${space} | tr 'a-z' 'A-Z'`
if [[ ${space} = "RAW" ]];then
	echo " I am in raw space"	
	get_workspace_information
	create_raw_input
elif [[ ${space} = "REFINED" ]];then
	echo "im in refined"
	get_workspace_information
	create_refined_input
	if [[ ${group_required_yn} = "y" ]]; then
		size=${group_size}
		create_group_input
	fi	
elif [[ ${space} = "GROUP" ]];then
	echo "im in group space"
	get_workspace_information
	create_group_input
elif [[ ${space} = "GRANT_TABLE" ]];then
	echo "im in grant table"
	
elif [[ ${space} = "STAGING" ]];then
	create_staging
elif [[ ${space} = "GRANT_DB" ]];then
	echo "im in grant db"
else
	echo "wrong parameter"
fi
