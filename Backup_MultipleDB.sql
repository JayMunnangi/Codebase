--declaring variables
DECLARE @dbname VARCHAR(100) -- database name
DECLARE @bupath VARCHAR(100) --path for backup location
DECLARE @filename VARCHAR(100) --filename used for backup files
DECLARE @datestamp VARCHAR(25) --date used for backup file timestamp
--specify database backup directory
SET @bupath = '\\ATXDPEWMDB-P02\DBBackup\'
--file date formatting
SELECT @datestamp = CONVERT(VARCHAR(20),GETDATE(),112) + REPLACE
(CONVERT(VARCHAR(20),GETDATE(),108),':','')
--specify databases to backup
DECLARE db_cursor CURSOR for
SELECT name
FROM master.dbo.sysdatabases
WHERE name IN ('CCM_BB_BMG01_STG',
 'CCM_BB_FPC01_STG',
 'CCM_BB_GFP01_STG',
 'CCM_BB_LFP01_STG',
 'CCM_BB_MATL01_STG',
 'CCM_StBernards_Allscripts_STG',
 'CCM_StBernards_Greenway_STG',
 'CCM_StBernards_MEDITECH_STG',
 'CCM_StBernards_MSSP01_STG',
 'CCM_StBernards_Nextgen_STG',
 'CCM_StBernards_OBGYN',
 'CCM_StBernards_SHC_STG') -- Include only these databases, if excluding multiple databases, seprate them by a comma
--backup process
OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @dbname
WHILE @@FETCH_STATUS = 0
BEGIN
   SET @filename = @bupath + @dbname + '_' + @datestamp + '.bak'
   BACKUP DATABASE @dbname TO DISK = @filename WITH COPY_ONLY, NOFORMAT,INIT,
   CHECKSUM; --init overwrites existing files with the same name, and checksum verifies the backup
       FETCH NEXT from db_cursor INTO @dbname
END
CLOSE db_cursor
DEALLOCATE db_cursor