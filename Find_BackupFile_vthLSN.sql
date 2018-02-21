DECLARE @first_lsn nVarchar(100)
SET @first_lsn = '20000000022100001' --Change the LSN Number
 
SELECT database_name AS DatabaseName
   ,physical_device_name AS BackupLocation
   ,backup_start_date AS BackupStartDate
   ,backup_finish_date AS BackupEndDate
   ,CAST(backup_size/1024/1024 AS DECIMAL(10,3)) AS BackupSizeInMB
FROM msdb.dbo.backupset BS
INNER JOIN msdb.dbo.backupmediafamily BMF
ON BS.media_set_id=BMF.media_set_id
WHERE BS.first_lsn = @first_lsn
