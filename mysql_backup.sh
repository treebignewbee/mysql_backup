#!/bin/bash

# ---------------------------------------------------------------------------------------
# MySQL Database Backup Script
# ---------------------------------------------------------------------------------------
# This script is designed to automate the backup of MySQL databases. It creates a 
# compressed backup of specified databases, retains backups for a specified number of 
# days, and synchronizes the backups to a remote server using rsync.
#
# Recommended Usage:
# To schedule this script to run automatically at 3:00 AM every day, add the following 
# entry to your crontab:
# 
# 0 3 * * * /path/to/mysql_backup.sh
#
# Ensure the script has executable permissions:
# chmod +x /path/to/mysql_backup.sh
#
# ---------------------------------------------------------------------------------------

# ------------------------ Database Backup Configuration ------------------------

# MySQL username used for database backup (e.g., backup_user)
db_user="your_mysql_username"

# MySQL password for the specified user (e.g., yourpassword123)
db_password="your_mysql_password"

# MySQL host address, usually localhost, but can also be the IP address of a remote database (e.g., 127.0.0.1)
db_host="your_mysql_host"

# Name(s) of the database(s) to be backed up; for multiple databases, separate names with spaces (e.g., "db1 db2 db3")
all_db="your_database_name"

# Directory path where the backup files will be stored; make sure the directory exists and has enough storage space (e.g., /home/backup/mysql)
backup_dir="/path/to/backup/directory"

# Number of days to keep backups; backup files older than this number of days will be deleted (e.g., 10)
backup_day=10

# Path to the log file that records the backup process; ensure the directory exists (e.g., /var/log/mysql_backup.log)
logfile="/path/to/logfile/mysql_backup.log"

# Automatically detect mysql and mysqldump paths; usually no need to modify these
mysql="$(command -v mysql)"
mysqldump="$(command -v mysqldump)"

# Date format for backup file (e.g., YYYY-MM-DD)
time="$(date +"%Y-%m-%d")"

# ------------------------ Remote Synchronization Configuration ------------------------

# SSH port number used for remote synchronization (e.g., 22 for default SSH)
ssh_port=your_ssh_port

# Path to the SSH private key used for automated login during rsync synchronization (e.g., /root/.ssh/id_rsa)
id_rsa="/path/to/ssh/private_key"

# SSH username used for logging into the remote server during rsync synchronization (e.g., rsync_user)
id_rsa_user="your_ssh_username"

# Absolute path to the backup directory on the remote server; make sure this path exists on the remote server (e.g., /home/backup/mysql)
clientPath="/remote/server/backup/path"

# Absolute path to the local backup directory to be mirrored to the remote server (e.g., /home/backup/mysql)
serverPath="${backup_dir}"

# IP address or hostname of the remote server used for rsync synchronization (e.g., 192.168.0.2)
web_ip="remote_server_ip_or_hostname"

# ------------------------ Script Functions ------------------------

# Log a message with a timestamp
log() {
    echo "$(date +'%Y-%m-%d %T') $1" >> "${logfile}"
}

# Create necessary directories if they do not exist
create_directories() {
    mkdir -p "${backup_dir}" || { log "Failed to create backup directory"; exit 1; }
    mkdir -p "$(dirname "${logfile}")" || { log "Failed to create log directory"; exit 1; }
}

# Backup MySQL databases
mysql_backup() {
    for db in ${all_db}; do
        backname="${db}.${time}"
        dumpfile="${backup_dir}/${backname}.sql"
        
        log "Starting backup for database ${db}"
        if ${mysqldump} -F -u"${db_user}" -h"${db_host}" -p"${db_password}" "${db}" > "${dumpfile}" 2>>"${logfile}"; then
            log "Backup for ${db} completed, compressing ${dumpfile}"
            if tar -czf "${dumpfile}.tar.gz" -C "${backup_dir}" "${backname}.sql"; then
                rm -f "${dumpfile}"
                log "Backup file created: ${dumpfile}.tar.gz"
            else
                log "Failed to compress backup file ${dumpfile}"
                return 1
            fi
        else
            log "Backup for ${db} failed"
            return 1
        fi
    done
}

# Delete old backups
delete_old_backup() {
    log "Deleting old backup files"
    find "${backup_dir}" -type f -mtime +${backup_day} -exec rm -f {} \; -print >> "${logfile}"
}

# Rsync backups to remote server
rsync_mysql_backup() {
    log "Starting rsync to ${web_ip}"
    if rsync -avz --progress --delete -e "ssh -p ${ssh_port} -i ${id_rsa}" "${serverPath}" "${id_rsa_user}@${web_ip}:${clientPath}" >> "${logfile}" 2>&1; then
        log "Rsync to ${web_ip} completed"
    else
        log "Rsync to ${web_ip} failed"
        return 1
    fi
}

# ------------------------ Main Execution ------------------------

# Create required directories before proceeding
create_directories

# Change to the backup directory; exit if it fails
cd "${backup_dir}" || { log "Failed to change directory to ${backup_dir}"; exit 1; }

# Perform the backup; log and exit on failure
mysql_backup || { log "MySQL backup failed"; exit 1; }

# Delete old backups; log and exit on failure
delete_old_backup || { log "Failed to delete old backups"; exit 1; }

# Sync backups to the remote server; log and exit on failure
rsync_mysql_backup || { log "Rsync failed"; exit 1; }

# Log completion of the entire process
log "MySQL backup and rsync process completed successfully"
