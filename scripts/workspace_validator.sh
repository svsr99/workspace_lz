#!/bin/bash
# Project : Landing Zone
# Desc : Validate a workspace for the landing zone.  
# Author : Darshan S Mahendrakar
# 

create_workspace() {

	# $1 is the user id 
	# $2 is the group 
	# $3 is the size of the workspace 
	# $4 is target dir
   	 # $5 is dir access
# icreate_workspace $user $group $size $targetdir $access
	local ws_user=$1
	local ws_grp=$2
    	local ws_size=$3
        local ws_dir=$4
    	local ws_access=$5
 	
	# Create the user
    log $INFO "Creating user directory->$ws_dir"
    hdfs dfs -mkdir $ws_dir
    hdfs dfs -chown -R $ws_user:$ws_grp $ws_dir
    hdfs dfs -chmod $ws_access $ws_dir

    log $INFO "Setting space quota for the user directory->$ws_size"
    if [[ ${ws_size} !=  "0" ]]; then
    	hdfs dfsadmin -setSpaceQuota $ws_size $ws_dir
	if [[ $? -eq 0 ]]; then
		log $INFO "Space quota allocated successfully"
	else
		log $ERROR "Space quota allocation failed."
	fi
    else
	log $INFO "No space quota required for $1"
    fi
    log $INFO "Workspace Created Completed for " $1
}

set_uri_acls() {
	log $INFO "Setting URI ACLs"
	local ws_dir=$1
	local ws_role=$2
        local ws_group=$3
        local ws_access_type=$4
        local ws_dir_type=$5
        local ws_role_type=$6
     	/usr/bin/kinit ${APP_ID} -k -t ~/.keytab/${KEY_TAB}
        check_role_exist $ws_role $ws_group
        if [ ${ws_access_type} = "ALL" ]
        then
	   log $INFO "ALL access given for $ws_role for this URI: $ws_dir"
           beeline -u ${BEELINE_CONNECT_STR} -e "GRANT ALL ON URI '$HDFS_HOST$ws_dir' to ROLE $ws_role" 2>&1 | grep FAIL
	   if [ $ws_role_type = "POWERUSER" ]
	   then
	       if [ $ws_dir_type = "GROUP" ]
	       then
		    # Kinit back to hdfs
            	    /usr/bin/kinit hdfs -k -t ~/.keytab/hdfs.keytab
		    hadoop fs -setfacl -R -m group:$ws_group:rwx $ws_dir 
            	    hadoop fs -setfacl -R -m default:group:$ws_group:rwx $ws_dir
		    /usr/bin/kinit ${APP_ID} -k -t ~/.keytab/${KEY_TAB} 
	       fi
	   fi
        fi
        
	if [ ${ws_access_type} = "SELECT" ]
	then	
	    log $INFO "DATA SCIENTIST given for $ws_role for this URI: $ws_dir"
            # Kinit back to hdfs
            /usr/bin/kinit hdfs -k -t ~/.keytab/hdfs.keytab
            hadoop fs -setfacl -R -m group:$ws_group:r-x $ws_dir 
	    hadoop fs -setfacl -R -m default:group:$ws_group:r-x $ws_dir
	    /usr/bin/kinit ${APP_ID} -k -t ~/.keytab/${KEY_TAB}
        fi

# Ingest Gets full read write permission on DB_RAW in DEV and READ ONLY  in TEST and PROD
        if [[ ${CLUSTER_ENV} = "DEV" && ${dir_type} = "DB_RAW" ]]
        then
	    log $INFO "FULL_ACCESS given for $ws_role for this URI: $ws_dir and assigned to GROUP lzgingst since its a dev" 
            beeline -u ${BEELINE_CONNECT_STR} -e "GRANT ROLE $ws_role to GROUP lzgingst" 2>&1 | grep FAIL
            beeline -u ${BEELINE_CONNECT_STR} -e "GRANT ALL ON URI '$HDFS_HOST$ws_dir' to ROLE $ws_role" 2>&1 | grep FAIL
            
	 
	elif [[ ${CLUSTER_ENV} = "TEST" && ${dir_type} = "DB_RAW" ]] || [[ ${CLUSTER_ENV} = "PROD" && ${dir_type} = "DB_RAW" ]]; then
	    log $INFO "SELECT_ACCESS given for $ws_role for this URI: $ws_dir and assigned to GROUP lzgingst since its a $ENV"
            beeline -u ${BEELINE_CONNECT_STR} -e "GRANT ROLE $ws_role to GROUP lzgingst" 2>&1 | grep FAIL
            beeline -u ${BEELINE_CONNECT_STR} -e "GRANT SELECT ON URI '$HDFS_HOST$ws_dir' to ROLE $ws_role" 2>&1 | grep FAIL
	
	else 
	     log $INFO "Not a RAW Space moving on..."
	fi
        log $INFO "ACLs and granting access on URI completed for role $ws_role"

        # Kinit back to hdfs
        /usr/bin/kinit hdfs -k -t ~/.keytab/hdfs.keytab

}

set_custom_acl() {
# INPUT : set_custom_acl ${user_group} ${appid_groupid} ${hdfspath} ${accesstype}
	log $INFO "Setting CUSTOM ACL for HDFS Directory"
 	local ws_user_group=$1
	local ws_appid_groupid=$2
	local ws_hdfspath=$3
	local ws_accesstype=$4
 	# Changing Kinit to HDFS
        /usr/bin/kinit hdfs -k -t ~/.keytab/hdfs.keytab
	if [[ ${ws_accesstype} = "SELECT" ]]; then
		hdfs dfs -test -d ${ws_hdfspath}                
		res=$?
		if [ $res -eq 0 ]
     		then
			if [[ ${ws_user_group} = "USER" ]]; then
              		    log $INFO "HDFS  Directory already exists->$ws_hdfspath"
			    log $INFO "Setting Custom SELECT Access ACL TO $ws_user_group:$ws_appid_groupid on $ws_hdfspath"
         		    hdfs dfs -setfacl -R -m default:user:${ws_appid_groupid}:r-x ${ws_hdfspath}
      			    hdfs dfs -setfacl -R -m user:${ws_appid_groupid}:r-x ${ws_hdfspath}
			else
			    log $INFO "HDFS  Directory exists->$ws_hdfspath"
                            log $INFO "Setting Custom SELECT Access ACL TO $ws_user_group:$ws_appid_groupid on $ws_hdfspath"
                            hdfs dfs -setfacl -R -m default:group:${ws_appid_groupid}:r-x ${ws_hdfspath}
                            hdfs dfs -setfacl -R -m group:${ws_appid_groupid}:r-x ${ws_hdfspath}	
			fi
		else
			log $ERROR "HDFS Directory doesn't exists ->$ws_hdfspath...Please check input file."
		fi
	elif [[ ${ws_accesstype} = "ALL" ]]; then
		hdfs dfs -test -d ${ws_hdfspath}
                res=$?
		if [ $res -eq 0 ]
                then
	            if [[ ${ws_user_group} = "USER" ]]; then
                            log $INFO "HDFS  Directory already exists->$ws_hdfspath"
                            log $INFO "Setting Custom FULL Access ACL TO $ws_user_group:$ws_appid_groupid on $ws_hdfspath"
                            hdfs dfs -setfacl -R -m default:user:${ws_appid_groupid}:rwx ${ws_hdfspath}
                            hdfs dfs -setfacl -R -m user:${ws_appid_groupid}:rwx ${ws_hdfspath}
                        else
                            log $INFO "HDFS  Directory exists->$ws_hdfspath"
                            log $INFO "Setting Custom FULL Access ACL TO $ws_user_group:$ws_appid_groupid on $ws_hdfspath"
                            hdfs dfs -setfacl -R -m default:group:${ws_appid_groupid}:rwx ${ws_hdfspath}
                            hdfs dfs -setfacl -R -m group:${ws_appid_groupid}:rwx ${ws_hdfspath}
                        fi
		else
		   log $ERROR "HDFS Directory doesn't exists ->$ws_hdfspath...Please check input file."
		fi
	else
                log $ERROR "Incorrect access Please Check input file -> $y"
	fi


}

setacl_hdfs_dir() {
	# $1 is the target directory
	# $2 is the role of the user
	# $3 is group
	
	local ws_dir=$1
	local ws_dir_type=$2

	hadoop fs -setfacl -R -m user:hive:rwx $ws_dir
	hadoop fs -setfacl -R -m default:user:hive:rwx $ws_dir
	hadoop fs -setfacl -R -m user:impala:rwx $ws_dir
	hadoop fs -setfacl -R -m default:user:impala:rwx $ws_dir
	
	if [[ $CLUSTER_ENV = "DEV" && ${ws_dir_type} = "DATA_RAW" ]]
	then 
		hadoop fs -setfacl -R -m group:lzgingst:rwx $ws_dir
		hadoop fs -setfacl -R -m default:group:lzgingst:rwx $ws_dir
	fi
	log $INFO "Setting ACLs for HDFS directory are done"	
}

setprivileges() {

	log $INFO "Setting Database sentry privileges"
	local ws_dbtype=$1
	local ws_group=$2
	local ws_dbname=$3
	local ws_role=$4
	local ws_access_type=$5
       
	/usr/bin/kinit ${APP_ID} -k -t ~/.keytab/${KEY_TAB}
    	check_role_exist $ws_role $ws_group	
	if [[ $CLUSTER_ENV = "DEV" && ${ws_dbtype} = "DB_RAW"  ]]
        then
		log $INFO "Adding special ingest access to data raw database : ${ws_dbtype} :  ${ws_role}"
                beeline -u ${BEELINE_CONNECT_STR} -e "GRANT ROLE $ws_role to GROUP lzgingst" 2>&1 | grep FAIL
        fi
	if [ $ws_access_type = "ALL" ]
	then
	    log $INFO "Setting ALL role privileges for $ws_group on $ws_dbname database"
	    beeline -u ${BEELINE_CONNECT_STR} -e "GRANT ALL ON DATABASE $ws_dbname to ROLE $ws_role" 2>&1 | grep FAIL
	elif [ $ws_access_type = "SELECT" ]	
	then    
	    log $INFO "Setting SELECT role privileges for $ws_group on $ws_dbname database"
	    beeline -u ${BEELINE_CONNECT_STR} -e "GRANT SELECT ON DATABASE $ws_dbname to ROLE $ws_role" 2>&1 | grep FAIL
	fi

    	# Kinit back to hdfs
    	/usr/bin/kinit hdfs -k -t ~/.keytab/hdfs.keytab
}

check_role_exist(){
   log $INFO  "Checking whether role is already exists or not"
	local ws_role=$1
	local ws_group=$2
        beeline -u ${BEELINE_CONNECT_STR} -e "GRANT ROLE $ws_role to GROUP $ws_group" > checkinfo.txt 2>&1
	if [[ `grep "SentryNoSuchObjectException" checkinfo.txt | wc -l` -gt 0 ]]
        then
            log $INFO "Role: $ws_role doesn't exist in the Data Base, so creating a new role : $ws_role"
	    beeline -u ${BEELINE_CONNECT_STR} -e "CREATE ROLE $ws_role" 2>&1 | grep FAIL
            beeline -u ${BEELINE_CONNECT_STR} -e "GRANT ROLE $ws_role to GROUP $ws_group" 2>&1 | grep FAIL
	else
	    log $INFO "Role: $ws_role is already exists in the Data Base"
        fi
	return
}

modify_workspace()
{
#BASE_GROUP_HDFS=/group
#USER_HDFS=/user
    echo "Work in Progress."
}

create_group()
{
    #Validate that all elements are in the array
    if [[ ${#tokens[@]} -ne 6 ]]
    then
        log $ERROR "Create user request doest not have enough information->$y"
    else   
        groupdir=${tokens[2]}
        user=${tokens[3]}
        group=${tokens[4]}
        size=${tokens[5]}
	
        targetdir="/group/$groupdir"
        access="771"
        log $INFO "Creating group->$user:$group:$size:$targetdir:$access"
        hdfs dfs -test -d $targetdir 
        res=$?
        if [ $res -eq 0 ] 
        then
	        log $ERROR "Group Directory already exists->$targetdir"
        else
	/usr/bin/kinit hdfs -k -t ~/.keytab/hdfs.keytab
            create_workspace $user $group $size $targetdir $access
            hdfs dfs -test -d $targetdir
            res=$?
            if [ $res -eq 0 ]
            then
                log $INFO "Setting ACLs for->$targetdir"
                setacl_hdfs_dir $targetdir
	    fi
        fi
    fi
    return
}

create_staging()
{
    #Validate that all elements are in the array
    if [[ ${#tokens[@]} -ne 4 ]]
    then
        log $ERROR "Create staging request doest not have enough information->$y"
    else   
        user=${tokens[2]}
echo "${user}"
        group=${tokens[3]}
echo "${group}" 
       targetdir="$STAGING_DIR/$user"
echo "${targetdir}"

        access="770"
echo "${access}"
        log $INFO "Creating staging->$user:$group:$targetdir:$access"
        # Validate that the directory does not exists
        if [ -d "$targetdir" ]
        then
	        log $ERROR "Staging Directory already exists->$targetdir"
        else
            mkdir "$TARGET_DIR/$user"
            chmod $access $TARGET_DIR/$user
            chown $user:$group "$TARGET_DIR/$user"
echo " ln -s "${TARGET_DIR}/${user}" "${targetdir}""
	    ln -s "${TARGET_DIR}/${user}" "${targetdir}"
           # ln -s "${targetdir}" "${SYM_LINK_DIR}/${user}"
            chown -R  $user:$group "${targetdir}"
            log $INFO "Created Staging Directory-> $targetdir"
        fi
    fi
    return
}

create_user()
{   
    #Validate that all elements are in the array
    if [[ ${#tokens[@]} -ne 5 ]]
    then
        log $ERROR " user validation doest not have enough information->$y"
    else   
        user=${tokens[2]}
        group=${tokens[3]}
        size=${tokens[4]}
        
        targetdir="/user/$user"
        hdfs dfs -test -d $targetdir 
        res=$?
        if [ $res -eq 0 ] 
        then
	        log $INFO "User Directory exists->$targetdir"
        else
	    # Kinit to hdfs
	    /usr/bin/kinit hdfs -k -t ~/.keytab/hdfs.keytab
	    create_workspace $user $group $size $targetdir $access

            hdfs dfs -test -d $targetdir 
            res=$?
            if [ $res -eq 0 ]
            then
            	log $INFO "Setting ACLs for->$targetdir"
            	setacl_hdfs_dir $targetdir
            fi
        fi
    fi
    return
}

create_data()
{
    #Validate that all elements are in the array
    if [[ ${#tokens[@]} -ne 6 ]]
    then
        log $ERROR "Create data request doest not have enough information->$y"
    else  
        if [ ${tokens[1]} = "DATA_REFINED" ]
        then
            datadir="refined"
        else
            datadir="raw"
        fi
        
        hdfsdir_type=${tokens[1]}
        groupdir=${tokens[2]}
        user=${tokens[3]}
        group=${tokens[4]}
        size=${tokens[5]}
	
        targetdir="/data/$datadir/$groupdir"
	if [ $CLUSTER_ENV = "DEV" ]
	then
        	access="771"
	else
		access="751"
	fi
        log $INFO "Creating data->$user:$group:$size:$targetdir:$access"
        hdfs dfs -test -d $targetdir 
        res=$?
        if [ $res -eq 0 ] 
        then
	        log $ERROR "Data Directory already exists->$targetdir"
        else
            create_workspace $user $group $size $targetdir $access
	    log $INFO "Setting ACLs for->$targetdir"
	    setacl_hdfs_dir $targetdir ${hdfsdir_type}
        fi
    fi
    return
}

create_database() 
{
    #Validate that all elements are in the array
    if [[ ${#tokens[@]} -ne 5 ]]
    then
        log $ERROR "Create database request doest not have enough information->$y"
    else   
        dbtype=${tokens[2]}
	appid=${tokens[4]}
	if [ $dbtype = "REFINED" ]
       then
	   dbname=${tokens[3]}
	   location=${HDFS_HOST}${BASE_DATA_REFINED_HDFS}/${appid}/db/${dbname}.db
	elif [ $dbtype = "RAW" ]
        then
	   dbname=${tokens[3]}
	   location=${HDFS_HOST}${BASE_DATA_RAW_HDFS}/${appid}/db/${dbname}.db
	
        elif [ $dbtype = "GROUP" ]
        then
            dbname=${tokens[3]}
            location=${HDFS_HOST}${BASE_GROUP_HDFS}/${appid}/db/${dbname}.db
        else 
            dbname=${tokens[3]}
            location=${HDFS_HOST}${USER_HDFS}/${appid}/db/${dbname}.db
        fi
        createdb_stmt="CREATE DATABASE $dbname LOCATION '${location}'"
	log $INFO "Create DB statment : $createdb_stmt"	
        /usr/bin/kinit ${APP_ID} -k -t ~/.keytab/${KEY_TAB}
        log $INFO "Creating database->$dbname:$group"
        beeline -u ${BEELINE_CONNECT_STR} -e "CREATE DATABASE $dbname LOCATION '${location}'" > checkdb.txt 2>&1
        if [[ `grep "already exists" checkdb.txt | wc -l` -gt 0 ]]
        then
	        log $ERROR "Database already exists->$dbname"
        else
            log $INFO "Database created->$dbname"
        fi
    fi
    return
}

create_role_privileges()
{
     log $INFO "Creating roles, setting up privileges and ACls for URIs"
     if [[ ${#tokens[@]} -ne 6 ]]
     then
	log $ERROR "Create role request doesn't have enough information->$y"
     else
	IFS=","
	
	appdir=${tokens[2]}
    	group=${tokens[3]}
	roletype=${tokens[4]}
	
	if [ ${roletype} = "ADMIN" ]
	then
	    role=${appdir}_${ADMIN_ROLE_SUFFIX}
	elif [ ${roletype} = "POWERUSER" ];then
	    role=${appdir}_${POWERUSER_ROLE_SUFFIX}
	else
            role=${appdir}_${ANALYST_ROLE_SUFFIX}
	fi
	accesspattern=${tokens[5]}
	accesstokens=( ${tokens[5]} )
	counts=${#accesstokens[@]}
	
	for ((i=0;i<${counts};++i)) 
	do
	    access_category=${accesstokens[$i]}
	    IFS=":"
	    access_category_tokens=( ${access_category} )
	    keytoken=${access_category_tokens[0]}
	    valuetoken=${access_category_tokens[1]}
	    keylocation_accesstype=${access_category_tokens[2]}
            accesstype=${access_category_tokens[3]}

	    if [[ ${keytoken} = "URI" ]]
	    then
		if [[ ${valuetoken} = "DATA_RAW" ]]
		then
		    log $INFO " Setting URI acls for DATA_RAW: ${BASE_DATA_RAW_HDFS}/${keylocation_accesstype}"
		    hdfs dfs -test -d ${BASE_DATA_RAW_HDFS}/${keylocation_accesstype}
		    res=$?
		    if [ $res -eq 0 ]
		    then
			#changing it to base delimiter as ":" delimiter will not work with con string
			IFS="|"
			set_uri_acls ${BASE_DATA_RAW_HDFS}/${keylocation_accesstype} ${role} ${group} ${accesstype} ${valuetoken} ${roletype}
 		        IFS=":"
 		    else
			log $ERROR "HDFS data_raw directory doesn't exists, please check the appid in input file -> ${BASE_DATA_RAW_HDFS}/${keylocation_accesstype}"
		    fi
		elif [[ ${valuetoken} = "DATA_REFINED" ]]
		then
		     hdfs dfs -test -d ${BASE_DATA_REFINED_HDFS}/${keylocation_accesstype}
                     res=$?
		     if [ $res -eq 0 ]
		     then
			 IFS="|" 
		     	 set_uri_acls ${BASE_DATA_REFINED_HDFS}/${keylocation_accesstype} ${role} ${group} ${accesstype} ${valuetoken} ${roletype}
			 IFS=":" 
		     else
		     	log $ERROR "HDFS data_refined directory doesn't exists, please check the appid in input file -> ${BASE_DATA_REFINED_HDFS}/${keylocation_accesstype}"
		     fi
		elif [[ ${valuetoken} = "GROUP" ]]
		then
		    hdfs dfs -test -d ${BASE_GROUP_HDFS}/${keylocation_accesstype}
		    res=$?
		    if [ $res -eq 0 ]
		    then
			IFS="|" 
			set_uri_acls ${BASE_GROUP_HDFS}/${keylocation_accesstype} ${role} ${group} ${accesstype} ${valuetoken} ${roletype}
			IFS=":" 
		    else
			log $ERROR "HDFS group directory doesn't exists, please check the appid in input file -> ${BASE_GROUP_HDFS}/${keylocation_accesstype}"
	            fi	
		fi
	    #if the key is DB then check whether its a raw or refined, if its a refined then add refined key as suffix to the db name
	    elif [[ ${keytoken} = "DB_RAW" || ${keytoken} = "DB_REFINED" || ${keytoken} = "DB_GROUP" || ${keytoken} = "DB_USER" ]]
	    then
		IFS="|" 
		setprivileges ${keytoken} ${group} ${valuetoken} ${role} ${keylocation_accesstype}
		log $INFO "Setting acl and privilleges for DB : ${valuetoken}"
		IFS=":" 
            fi 
	done
     fi
     IFS="|"		
}

modify_acl()
{
IFS="|"
log $INFO "Modifying ACL, setting up privileges and ACls for HDFS location"
        if [[ ${#tokens[@]} -ne 5 ]]; then
        log $ERROR "Modify ACL REQUEST doesn't have enough information -> $y"
	else
            IFS=","
            user_group=${tokens[2]}
            appid_groupid=${tokens[3]}
            accesspattern=${tokens[4]}
            accesstokens=( ${tokens[4]} )
            count=${#accesstokens[@]}
            for ((i=0;i<${count};++i))
            do
                access_category=${accesstokens[$i]}
                IFS=":"
                access_category_tokens=( ${access_category} )
	        datadir_type=${access_category_tokens[0]}
                key_location=${access_category_tokens[1]}
                accesstype=${access_category_tokens[2]}
	        if [[ ${datadir_type} = "DATA_RAW" ]]; then
		hdfspath="${BASE_DATA_RAW_HDFS}/${key_location}"
		set_custom_acl ${user_group} ${appid_groupid} ${hdfspath} ${accesstype}

		elif [[ ${datadir_type} = "DATA_REFINED" ]]; then
                hdfspath=${BASE_DATA_REFINED_HDFS}/${key_location}
                set_custom_acl ${user_group} ${appid_groupid} ${hdfspath} ${accesstype}

		elif [[ ${datadir_type} = "GROUP" ]]; then
                hdfspath=${BASE_GROUP_HDFS}/${key_location}
                set_custom_acl ${user_group} ${appid_groupid} ${hdfspath} ${accesstype}

		else
                hdfspath=${USER_HDFS}/${key_location}
                set_custom_acl ${user_group} ${appid_groupid} ${hdfspath} ${accesstype}	
          	fi
	        
	    done
	IFS=","
	fi
IFS="|"
}

modify_space_quota(){
# Kinit to HDFS
/usr/bin/kinit hdfs -k -t  ~/.keytab/hdfs.keytab
log $INFO "Modifying Space Quota for HDFS location "
        if [[ ${#tokens[@]} -ne 3 ]]; then
        log $ERROR "Modify SPACE Quota doesn't have enough information -> $y"
        else
            IFS=","
	    quotapattern=${tokens[2]}
            quotatokens=( ${tokens[2]} )
            count=${#quotatokens[@]}
            for ((i=0;i<${count};++i))
            do
                quota_category=${quotatokens[$i]}
		IFS=":"
                quota_category_tokens=( ${quota_category} )
		datadir_type=${quota_category_tokens[0]}
		key_location=${quota_category_tokens[1]}
		quota=${quota_category_tokens[2]}
                if [[ ${datadir_type} = "DATA_RAW" ]]; then
              	     hdfspath="${BASE_DATA_RAW_HDFS}/${key_location}"
		     hdfs dfs -test -d ${hdfspath}
	             res=$?
		     if [[ $res -eq 0 ]]; then
			log $INFO "Changing DATA_RAW Space quota for ->${hdfspath} to ${quota}"	
			hdfs dfsadmin -setSpaceQuota ${quota} ${hdfspath}
		     else
			log $ERROR "DATA_RAW HDFS Path not Found...Please Check input ->$y"
		     fi 	
                elif [[ ${datadir_type} = "DATA_REFINED" ]]; then
                     hdfspath=${BASE_DATA_REFINED_HDFS}/${key_location}
		     hdfs dfs -test -d ${hdfspath}
                     res=$?
                     if [[ $res -eq 0 ]]; then
                        log $INFO "Changing DATA_REFINED Space quota for ->${hdfspath} to ${quota}"
                        hdfs dfsadmin -setSpaceQuota ${quota} ${hdfspath}
                     else
                        log $ERROR "DATA_REFINED HDFS Path not Found...Please Check input ->$y"
                     fi
                elif [[ ${datadir_type} = "GROUP" ]]; then
                     hdfspath=${BASE_GROUP_HDFS}/${key_location}
		     hdfs dfs -test -d ${hdfspath}
                     res=$?
                     if [[ $res -eq 0 ]]; then
                        log $INFO "Changing GROUP Space quota for ->${hdfspath} to ${quota}"
                        hdfs dfsadmin -setSpaceQuota ${quota} ${hdfspath}
                     else
                        log $ERROR "GROUP HDFS path not Found...Please Check input ->$y"
                     fi
                else
                     hdfspath=${USER_HDFS}/${key_location}
                     hdfs dfs -test -d ${hdfspath}
                     res=$?
                     if [[ $res -eq 0 ]]; then
                        log $INFO "Changing USER Space quota for ->${hdfspath} to ${quota}"
                        hdfs dfsadmin -setSpaceQuota ${quota} ${hdfspath}
                     else
                        log $ERROR "USER HDFS Path not Found...Please Check input ->$y"
                     fi
 		fi
		IFS=","
            done
        fi
IFS="|"

}

create_views(){
echo "Work In progress "
}



#################################################################################
# Main
#################################################################################
source ~/run/workspace/scripts/workspace_env.sh
oldifs="$IFS"
#exec 3>&1 1>>${LOG_FILE} 2>&1

# Kinit to hdfs
/usr/bin/kinit hdfs -k -t ~/.keytab/hdfs.keytab

log() 
{
    local header=$INFO_STMT
    if [ $1 = $ERROR ]
    then
        header=$ERROR_STMT
    fi
    echo "${header}|$2" 
    echo "${header}|$2" >> $logfile
}

# Create the log file
logfile=${LOG_FILE}
if [ `ls  | wc -l`  -eq 0 ]
then
    log $INFO "No files to Validate"
    exit 1
fi


# Process all the files in input directory
for x in `ls ${INPUT_DIR}/${INPUT_WILDCARD}`
do 
    echo "************************************************************************************************"
    log $INFO "Workspace Validation Started : Processing File  -> $x"
    echo "************************************************************************************************"
    echo "                                                                                                "
    filename=`basename $x`
    log $INFO "Filename : $filename"
    for y in `cat $x` 
    do 
        #log $INFO "Processing Line ************ -> $y"
        # Split the line into arrays by | delimit
        IFS="|"
        tokens=( $y )

        # Validate that each command has enough information
        if [[ ${#tokens[@]} -lt 3 ]] 
        then 
            log $ERROR "Command elements count in the line is invalid->$y"
        else
            # Validate the line
            cmd=${tokens[0]}
            category=${tokens[1]}

            if [[ $cmd = "CREATE" ]] 
            then
                # Process the category
                case $category in
                    "GROUP") 
			create_group;; 
                    "STAGING") 
                        create_staging;; 
                    "USER") 
                        create_user;;
                    "DATABASE")
                        create_database;; 
                    "DATA_RAW")
                        create_data;;
	            "ROLE")
                        create_role_privileges;;
                    "DATA_REFINED")
                        create_data;;
		    "VIEWS")
			create_views;;
                    *) 
                       log $ERROR "Category is invalid -> $category";;
                esac
            elif [[ $cmd = "MODIFY" ]]; then
		case $category in 
		     "ACL")
			modify_acl;;
		     "QUOTA")
			modify_space_quota;;
		     *)
		      log $ERROR "Category is invalid -> $category";;
		esac
	     else
                log $ERROR "First command element in the line is invalid -> $cmd"
            fi
        fi
    done
    newfilename="$PROCESSED_DIR/${filename}.processed"
    log $INFO  "Update the file to processed - $newfilename"
    mv $x $newfilename
    IFS=$oldifs
done

IFS=$oldifs    
kdestroy
echo "                                                                           "
echo "***************************************************************************"
log $INFO "Workspace creation process finished."
echo "***************************************************************************"

# Mailing System
if [[ ${ENV} != POC ]]; then

email=`cat ${LOG_FILE} | egrep ERROR | wc -l`
    if [[ $email -eq 1 ]]; then
       cat ${LOG_FILE} | egrep "ERROR" | mailx -a ${LOG_FILE} -s "ERROR  in workspace creation in $ENV for usecase $newfilename" ${EMAIL_RECIPIENTS} 2>/dev/null

    else
       cat ${LOG_FILE} | egrep "INFO" | mailx -a "${LOG_FILE}" -s "Successfully created/modified  workspace in $ENV for usecase $newfilename" ${EMAIL_RECIPIENTS} 2>/dev/null
    fi
else
echo "No email Notification as it is POC "
exit 1
fi

