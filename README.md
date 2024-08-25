MySQL Database Backup Script
---------------------------------------------------------------------------------------
This script is designed to automate the backup of MySQL databases. It creates a 
compressed backup of specified databases, retains backups for a specified number of 
days, and synchronizes the backups to a remote server using rsync.

Recommended Usage:
To schedule this script to run automatically at 3:00 AM every day, add the following 
entry to your crontab:

0 3 * * * /path/to/mysql_backup.sh

Ensure the script has executable permissions:
chmod +x /path/to/mysql_backup.sh
