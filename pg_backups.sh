#!/bin/bash

set -e # Exit if error
set -u # Exit if undefined var

##############################
## POSTGRESQL BACKUP CONFIG ##
##############################

# This dir will be created if it doesn't exist. This must be writable by the user the script is
# running as.
BACKUP_DIR=/var/backups/postgres_"$HOSTNAME"/pg_backups/

#### SETTINGS FOR ROTATED BACKUPS ####

# Which day to take the weekly backup from (1-7 = Monday-Sunday)
DAY_OF_WEEK_TO_KEEP=5

# Number of days to keep daily backups
DAYS_TO_KEEP=7

# How many weeks to keep weekly backups
WEEKS_TO_KEEP=5


###########################
#### START THE BACKUPS ####
###########################

function perform_backups()
{
    SUFFIX=$1
    FINAL_BACKUP_DIR=$BACKUP_DIR"$(date +%Y-%m-%d)$SUFFIX/"

    echo "Making backup directory in $FINAL_BACKUP_DIR"

    if ! mkdir -p "$FINAL_BACKUP_DIR"; then
        echo "Cannot create backup directory in $FINAL_BACKUP_DIR. Go and fix it!" 1>&2
        exit 1;
    fi;


    #######################
    ### GLOBALS BACKUPS ###
    #######################

    echo -e "\nPerforming globals backup"
    set -o pipefail
    if ! pg_dumpall -g | gzip > "$FINAL_BACKUP_DIR"globals.sql.gz.in_progress; then
        echo "[!!ERROR!!] Failed to produce globals backup" 1>&2
    else
        mv "$FINAL_BACKUP_DIR"globals.sql.gz.in_progress "$FINAL_BACKUP_DIR"globals.sql.gz
    fi
    set +o pipefail


    ###########################
    ###### FULL BACKUPS #######
    ###########################

    FULL_BACKUP_QUERY="select datname from pg_database where not datistemplate and datallowconn order by datname;"

    echo -e "\nPerforming full backups"
    for DATABASE in $(psql -At -c "$FULL_BACKUP_QUERY" postgres)
    do
        echo "Custom backup of $DATABASE"
        if ! pg_dump -Fc "$DATABASE" --compress=zstd -f "$FINAL_BACKUP_DIR""$DATABASE".custom.in_progress; then
            echo "[!!ERROR!!] Failed to produce custom backup database $DATABASE"
        else
            mv "$FINAL_BACKUP_DIR""$DATABASE".custom.in_progress "$FINAL_BACKUP_DIR""$DATABASE".custom
        fi
    done
    echo -e "\nAll database backups complete!"
}

# MONTHLY BACKUPS

DAY_OF_MONTH=$(date +%d)

if [ "$DAY_OF_MONTH" -eq 1 ];
then
    # Delete all expired monthly directories
    find "$BACKUP_DIR" -maxdepth 1 -name "*-monthly" -exec rm -rf '{}' ';'
    perform_backups "-monthly"
    exit 0;
fi

# WEEKLY BACKUPS

DAY_OF_WEEK=$(date +%u) #1-7 (Monday-Sunday)
EXPIRED_DAYS=$((WEEKS_TO_KEEP * 7 + 1))

if [ "$DAY_OF_WEEK" = "$DAY_OF_WEEK_TO_KEEP" ];
then
    # Delete all expired weekly directories
    find "$BACKUP_DIR" -maxdepth 1 -mtime +$EXPIRED_DAYS -name "*-weekly" -exec rm -rf '{}' ';'
    perform_backups "-weekly"
    exit 0;
fi

# DAILY BACKUPS

# Delete daily backups 7 days old or more
find "$BACKUP_DIR" -maxdepth 1 -mtime +$DAYS_TO_KEEP -name "*-daily" -exec rm -rf '{}' ';'

perform_backups "-daily"
