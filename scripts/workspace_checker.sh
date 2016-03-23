#bin/bash

source /platform/env/server_env.sh

#Accepts the following argument
#App Id : Provide the application id
#Group d : Provide the group associated with the application 

if [[ $# -ne 2 ]]; then
   echo "Missing argument. To use : workspace_checker.sh <App Id> <Group Id>"
   exit 1
fi

app_id=${1}
group_id=${2}
poweruser_group_id="lz2"`echo ${group_id} | cut -c4-`
app_data_raw_dir=${DATA_RAW_DIR}/${app_id}
app_data_refined_dir=${DATA_REFINED_DIR}/${app_id}
app_group_dir=${GROUP_DIR}/${app_id}
app_user_dir=${USER_DIR}/${app_id}
sentry_roles_admin="${app_id}_adm"
sentry_roles_poweruser="${app_id}_pwrusr"
#log $INFO "Application ID : ${app_id}"
#log $INFO "Group Id : ${group_id}"
#log $INFO "Power User Group Id : ${poweruser_group_id}"
#log $INFO "App Data Raw : ${app_data_raw_dir}"
#log $INFO "App Data Refined : ${app_data_refined_dir}"
#log $INFO "App Data Group : ${app_group_dir}"
#log $INFO "App Data User : ${app_user_dir}"
#log $INFO "Sentry Admin : ${sentry_roles_admin}"
#log $INFO "Sentry Poweruser : ${sentry_roles_poweruser}"

echo "Application ID : ${app_id}"
echo "Group Id : ${group_id}"
echo "Power User Group Id : ${poweruser_group_id}"
#Kinit as hdfs
/usr/bin/kinit hdfs -kt ~/.keytab/hdfs.keytab

#Checking for directory, space, access
printf "Data Raw : ${app_data_raw_dir} : "
hadoop fs -test -d ${app_data_raw_dir}
if [[ $? -eq 0 ]]; then
	dirsize=`hadoop fs -count -q -h ${app_data_raw_dir} | sed 's/  */ /g' | cut -d ' ' -f 4`
	printf "${dirsize}\n"
else
	printf "No space defined\n"
fi
 
printf "Data Refined : ${app_data_refined_dir} :  "
hadoop fs -test -d ${app_data_refined_dir}
if [[ $? -eq 0 ]]; then
	dirsize=`hadoop fs -count -q -h ${app_data_refined_dir} | sed 's/  */ /g' | cut -d ' ' -f 4`
	printf "${dirsize}\n"
else
	printf "None\n"
fi

printf "Group Dir : ${app_group_dir} :  "
hadoop fs -test -d ${app_group_dir}
if [[ $? -eq 0 ]]; then
	dirsize=`hadoop fs -count -q -h  ${app_group_dir} | sed 's/  */ /g' | cut -d ' ' -f 4`
	printf "${dirsize}\n"
else
	printf "None\n"
fi

printf "User Dir : ${app_user_dir} : "
hadoop fs -test -d ${app_user_dir}
if [[ $? -eq 0 ]]; then
	dirsize=`hadoop fs -count -q -h  ${app_user_dir} | sed 's/  */ /g' | cut -d ' ' -f 4`
	printf "${dirsize}\n"
else
	printf "None\n"
fi

# Kinit as lzadmin
/usr/bin/kinit lzadmin -kt ~/.keytab/lzadmin.keytab

# Check the sentry roles
echo "Checking admin role ${sentry_roles_admin}..."
beeline -u "${BEELINE_JDBC}/default;${BEELINE_PRINCIPAL}" --silent -e "show roles;" | grep ${sentry_roles_admin}
if [[ $? -ne 0 ]]; then
	echo "${group_id} does not exists."
else
	beeline -u "${BEELINE_JDBC}/default;${BEELINE_PRINCIPAL}" --silent -e "show grant role ${sentry_roles_admin}; show role grant group ${group_id}";
fi

echo "Checking poweruser role ${sentry_roles_poweruser}..."
beeline -u "${BEELINE_JDBC}/default;${BEELINE_PRINCIPAL}" --silent -e "show roles;" | grep ${sentry_roles_poweruser}
if [[ $? -ne 0 ]]; then
	echo "${group_id} does not exists."
else
	beeline -u  "${BEELINE_JDBC}/default;${BEELINE_PRINCIPAL}" --silent -e "show grant role ${sentry_roles_poweruser}; show role grant group ${poweruser_group_id}";
fi
