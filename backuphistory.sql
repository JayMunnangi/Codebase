--The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 

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
	  ORDER  BY bs.backup_start_date ASC






