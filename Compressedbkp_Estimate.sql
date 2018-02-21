-- gives us the estimated space can be reduced per database

SELECT database_name ,100*(1-(compressed_backup_size/backup_size)) as [% Saving] 
FROM msdb.dbo.backupset where LEFT(backup_start_date,12) = (SELECT LEFT(MAX(backup_start_date),12) from msdb..backupset);
