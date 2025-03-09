# pg_backups
## Opinionated local postgres backups

This script is a distiled version of the "pg_backup_rotated.sh" found in https://wiki.postgresql.org/wiki/Automated_Backup_on_Linux

It creates full custom zstd compressed local backups, using the user that runs the script.

The remaining options are included inside the script. You basically set the backup folder and run the script.

## Install and config
With the default backup folder you probably need to run as root:
```
mkdir -p /var/backups/postgres_"$HOSTNAME"/pg_backups/
chown postgres:postgres /var/backups/postgres_"$HOSTNAME"/pg_backups/
```

And then try to run the script as 'postgres' user:
```
su - postgres
wget https://github.com/ferfebles/pg_backups/raw/refs/heads/main/pg_backups.sh
chmod +x pg_backups.sh
./pg_backups.sh
```

To program the script to run every day, you can edit /etc/crontab __as root__: 
```
nano /etc/crontab

#Add this line
10 00  *  *  * postgres   /var/lib/pgsql/pg_backups.sh
```
