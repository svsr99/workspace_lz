source /users/lzwsp/run/darshan_test/workspace/scripts/workspace_env.sh      
  /usr/bin/kinit ${APP_ID} -k -t ~/.keytab/${KEY_TAB}
                        beeline --silent -u "${BEELINE_JDBC}/${sourcedb};${BEELINE_PRINCIPAL}" --showHeader=false  -e "show roles;" > table_list.txt
                        #egrep "^\|" table_list.txt | sed -e 's/ /|//g' > tables_list.txt.1
                        egrep "^\|" table_list.txt | sed 's/[| ]//g' >> tables_list.txt.1
                	cat table_list.txt     
		   cat tables_list.txt.1 | while read table
                        do
                                table_name=${table}
                               echo "$table_name"
				 echo "use default;GRANT SELECT ON default.landing_zone_default TO ROLE $table_name WITH GRANT OPTION;" >> lz_tables_select_access.sql
                        done
                        rm -f table_list.txt tables_list.txt.1
                        echo  "Executing SQL Statements for SELECT on ALL Tables"
                        beeline --silent -u "${BEELINE_CONNECT_STR}" -f lz_tables_select_access.sql >> ${sourcedb}_${sentry_role}.log 2>&1

