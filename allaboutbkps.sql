
SELECT bs.server_name AS ServerName,
       CASE bs.compatibility_level 
	     WHEN 90 THEN 'SQL Server 2005'
         WHEN 100 THEN 'SQL Server 2008 or SQL Server 2008 R2' 
         WHEN 110 THEN 'SQL Server 2012' 
		 WHEN 120 THEN 'SQL Server 2014'
       END AS ServerVersion, 
	   bs.database_name AS DatabseName,
       CASE bs.type 
         WHEN 'D' THEN 'Full' 
         WHEN 'I' THEN 'Database Differential' 
         WHEN 'L' THEN 'Log' 
         WHEN 'F' THEN 'File or filegroup'
		 WHEN 'G' THEN 'Differential file'
		 WHEN 'P' THEN 'Partial'
		 WHEN 'Q' THEN 'Differential partial' 
       END AS BackupType,
       bs.backup_start_date AS BackupStartDate,
       bs.backup_finish_date AS BackupFinishDate, 
	   CASE bmf.device_type 
         WHEN 2 THEN 'Disk' 
		 WHEN 5 THEN 'Tape'
		 WHEN 7 THEN 'Virtual device'   
         WHEN 105 THEN 'A permanent backup device' 
         ELSE 'Other Device' 
       END AS DeviceType,
       bmf.physical_device_name AS PhysicalDevice,
       bs.backup_size/(1024*1024) AS [BackupSize(MB)], 
       bs.compressed_backup_size/(1024*1024) AS [ConmpressedBackupSize(MB)]

FROM  msdb.dbo.backupset bs 
      INNER JOIN msdb.dbo.backupmediafamily bmf 
      ON  bs.media_set_id = bmf.media_set_id 
	 Where bs.database_name like 'AbiomedMbrTurbo_CR'
	  ORDER  BY bs.backup_start_date DESC