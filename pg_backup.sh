#!/usr/bin/env bash

# check the argument passed to the script (maybe it's the config file)
while [ $# -gt 0 ]; do
        case $1 in
                -c)
                        CONFIG_FILE_PATH="$2"
                        shift 2
                        ;;
                *)
                        ${ECHO} "Unknown Option \"$1\"" 1>&2
                        exit 2
                        ;;
        esac
done

# if config file isn't passed as an argument use the file nearby the script
if [ -z $CONFIG_FILE_PATH ] ; then
	SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
        CONFIG_FILE_PATH="${SCRIPT_DIR}/pg_backup.config"
fi

if [ ! -r ${CONFIG_FILE_PATH} ] ; then
        echo "Could not load config file from ${CONFIG_FILE_PATH}" 1>&2
        exit 1
fi

source "${CONFIG_FILE_PATH}"

function perform_backups()
{
	FINAL_BACKUP_DIR=$BACKUP_DIR"`date +\%Y-\%m-\%d`/"

	echo "Making backup directory in $FINAL_BACKUP_DIR"

	if ! mkdir -p $FINAL_BACKUP_DIR; then
		echo "Cannot create backup directory in $FINAL_BACKUP_DIR. Go and fix it!" 1>&2
		exit 1;
	fi;

	if [ "$DATABASES" != "" ]; then
		for DATABASE in ${DATABASES//,/ }
		do
			DATABASES_ONLY_CLAUSE="$DATABASES_ONLY_CLAUSE and datname ~ '$DATABASE'"
		done
	fi;

	FULL_BACKUP_QUERY="select datname from pg_database where not datistemplate and datallowconn"
	if [ "$DATABASES_ONLY_CLAUSE" != "" ]; then
		FULL_BACKUP_QUERY="$FULL_BACKUP_QUERY $DATABASES_ONLY_CLAUSE"
	fi;

	for DATABASE in `psql -h "$HOSTNAME" -p $PORT -U "$USERNAME" -At -c "$FULL_BACKUP_QUERY" defaultdb`
	do
			if ! pg_dump -Fc -h "$HOSTNAME" -p $PORT -U "$USERNAME" "$DATABASE" -f $FINAL_BACKUP_DIR"$DATABASE".custom.in_progress; then
				echo "[!!ERROR!!] Failed to produce custom backup database $DATABASE"
			else
				mv $FINAL_BACKUP_DIR"$DATABASE".custom.in_progress $FINAL_BACKUP_DIR"$DATABASE".custom
			fi
	done

	echo -e "\nAll database backups complete!"
}

# DAILY BACKUPS

# Delete daily backups 7 days old or more
find $BACKUP_DIR -maxdepth 1 -mtime +$DAYS_TO_KEEP -name "*" -exec rm -rf '{}' ';'

perform_backups
