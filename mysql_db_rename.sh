#!/bin/bash

oldSchemaName=$1
newSchemaName=$2
host=$3
user=$4
password="$5"

#######################################################################################################################################################################
# FUNCTIONS
#######################################################################################################################################################################
function usage() {
    echo ""
    echo "usage: ./mysql_db_rename.sh oldSchemaName newSchemaName hostname username password"
    echo ""
    exit
}

function mysqlCheck() {
	if ! type mysql > /dev/null || ! type mysqldump > /dev/null; then
		echo "MySQL Client Programs (specifically 'mysql' and 'mysqldump') are required to run mysql_db_rename. Please download and install them."
		echo "Link: https://dev.mysql.com/doc/refman/5.7/en/programs-client.html"
		exit
	else 
		echo "Client programs mysql and mysqldump found!"
	fi
}

function renameEvents() {
	oldSchemaName=$1
	newSchemaName=$2
	host=$3
	user=$4
	password="$5"
	for event in $(mysql -h $host -u $user --password="$5" -s -N -e "select event_name from information_schema.events where event_schema='${oldSchemaName}'"); do
	  echo "Moving ${event} to new db"
	  mysql -h $host -u $user --password="$password" -e "ALTER EVENT ${oldSchemaName}.${event} RENAME TO ${newSchemaName}.${event}"
	done
}

function getTriggers() {
	oldSchemaName=$1
	newSchemaName=$2
	host=$3
	user=$4
	password="$5"
	for trigger in $(mysql -h $host -u $user --password="$password" -s -N -e "select trigger_name from information_schema.triggers where trigger_schema='${oldSchemaName}'"); do	  
          echo "Dumping ${trigger} to ${newSchemaName}_triggers.sql"
	  mysqldump -h $host -u $user --password="$password" --no-data --no-create-info --skip-opt --triggers --ignore-error --add-drop-table=FALSE ${oldSchemaName} >> ${newSchemaName}_triggers.sql
	  mysql -h $host -u $user --password="$password" -e "DROP TRIGGER ${oldSchemaName}.${trigger}"
	done
	# Note: sed command will only work with double quotes if passing variables
	sed -i "s/${oldSchemaName}/${newSchemaName}/g" "${newSchemaName}_triggers.sql" 
}

function loadTriggers() {
	oldSchemaName=$1
    newSchemaName=$2
    host=$3
	user=$4
	password="$5"
	if [ -f ${newSchemaName}_triggers.sql ]; then
  	  mysql -h $host -u $user --password="$password" ${newSchemaName} < ${newSchemaName}_triggers.sql
	else
	  echo "No triggers file"
	fi
}

function renameProcedures() {
	oldSchemaName=$1
	newSchemaName=$2
	host=$3
	user=$4
	password="$5"
	for proc in $(mysql -h $host -u $user --password="$password" -s -N -e "select name from mysql.proc where db='${oldSchemaName}'"); do
	  echo "Moving ${proc} to new db"
	  mysql -h $host -u $user --password="$password" -e "UPDATE mysql.proc SET db='${newSchemaName}' WHERE name='${proc}' and db='${oldSchemaName}'"
	done
}

function getViews() {
	oldSchemaName=$1
  newSchemaName=$2
  host=$3
	user=$4
	password="$5"
        for view in $(mysql -h $host -u $user --password="$password" -s -N -e "select table_name from information_schema.views where table_schema='${oldSchemaName}'"); do
          echo "Dumping ${view} to ${newSchemaName}_views.sql"
	  		  mysqldump -h $host -u $user --password="$password" --add-drop-table=FALSE ${oldSchemaName} ${view} >> ${newSchemaName}_views.sql
	  		  mysql -h $host -u $user --password="$5" -e "drop table ${oldSchemaName}.${view}"
        done
	# Note: sed command will only work with double quotes if passing variables
	sed -i "s/${oldSchemaName}/${newSchemaName}/g" "${newSchemaName}_views.sql"
}

function loadViews() {
	oldSchemaName=$1
	newSchemaName=$2
	host=$3
	user=$4
	password="$5"
	if [ -f ${newSchemaName}_views.sql ]; then
		# Get count of views from source_db
		declare -i oldSchemaName_num_views=`mysql -h ${host} -u ${user} --password="${password}" --skip-column-names --batch -e "select count(table_name) from tables where table_type = 'VIEW' and table_schema = '${oldSchemaName}'" information_schema`
		declare -i newSchemaName_num_views=0
		while [ ${newSchemaName_num_views} -le ${oldSchemaName_num_views} ];
		do
		  if [[ ${newSchemaName_num_views} -lt ${oldSchemaName_num_views} ]]; then
		    mysql -s -f -h ${host} -u ${user} --password="${password}" ${newSchemaName} < ${newSchemaName}_views.sql
		    declare -i newSchemaName_num_views=`mysql -h ${host} -u ${user} --password="${password}" --skip-column-names --batch -e "select count(table_name) from tables where table_type = 'VIEW' and table_schema = '${newSchemaName}'" information_schema`
		    echo "newSchemaName_num_views: $newSchemaName_num_views"
		    echo "oldSchemaName_num_views: $oldSchemaName_num_views"
		  elif [[ ${newSchemaName_num_views} -eq ${newSchemaName_num_views} ]]; then
		    echo "newSchemaName_num_views: $newSchemaName_num_views"
		    echo "oldSchemaName_num_views: $oldSchemaName_num_views"
		    break
		  fi
		done
	else
	  echo "No views file"
	fi
}

function renameTables() {
	oldSchemaName=$1
	newSchemaName=$2
	host=$3
	user=$4
	password="$5"
	for table in $(mysql -h $host -u $user --password="$password" -s -N -e "select table_name from information_schema.tables where table_schema='${oldSchemaName}' and table_type='BASE TABLE'"); do
	  echo "Moving Table: ${table}"
	  mysql -h $host -u $user --password="$5" -e "RENAME TABLE ${oldSchemaName}.${table} TO ${newSchemaName}.${table}"
 	done
}

function renameDb() {
	oldSchemaName=$1
	newSchemaName=$2
	host=$3
	user=$4
	password="$5"

	mysql -v -h $host -u $user --password="$password" -e "CREATE DATABASE ${newSchemaName}"

	echo "Dump Views"
	getViews $oldSchemaName $newSchemaName $host $user "$password"
	echo "Dump Triggers"
	getTriggers $oldSchemaName $newSchemaName $host $user "$password"
	echo "Move Tables"
	renameTables $oldSchemaName $newSchemaName $host $user "$password"
	echo "Move Procs"
	renameProcedures $oldSchemaName $newSchemaName $host $user "$password"
	echo "Move Events"
	renameEvents $oldSchemaName $newSchemaName $host $user "$password"
	echo "Load Views"
	loadViews $oldSchemaName $newSchemaName $host $user "$password"
	echo "Load Triggers"
	loadTriggers $oldSchemaName $newSchemaName $host $user "$password"
	mysql -h $host -u $user --password="$5" -e "DROP DATABASE ${oldSchemaName}"	
	echo "Done!"
}

function cleanupFiles() {
	newSchemaName=$1
	rm -fv ${newSchemaName}_views.sql ${newSchemaName}_triggers.sql
}

#######################################################################################################################################################################
# MAIN
#######################################################################################################################################################################
# Check if MySQL Client Programs are installed
mysqlCheck

# Run
renameDb ${oldSchemaName} ${newSchemaName} ${host} ${user} "${password}"
cleanupFiles ${newSchemaName}
