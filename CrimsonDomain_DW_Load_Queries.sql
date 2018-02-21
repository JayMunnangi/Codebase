--- On the centralized monitoring server: ATXEDMWMDB-P01
--- OneTime
use master
go

sp_configure 'xp_cmdshell',1
go
reconfigure
go

--- On the server to be monitored
--- This needs to be executed only after the standard monitoring is setup by executing Master_Script_for_Monitoring.sql 

USE msdb;
GO
EXEC sp_syscollector_set_warehouse_instance_name N'ATXEDMWMDB-P01'
GO
EXEC sp_syscollector_set_warehouse_database_name N'DBA_Central_Repository';
GO
EXEC dbo.sp_syscollector_enable_collector;
GO

USE msdb ;
GO

EXEC sp_add_schedule
    @schedule_name = N'MDW_Daily_Schedule' ,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 050000 ;
GO

USE master
GO


Begin Transaction
Begin Try
Declare @collection_set_id_21 int
Declare @collection_set_uid_22 uniqueidentifier
EXEC [msdb].[dbo].[sp_syscollector_create_collection_set] @name=N'Drive Space Usage', @collection_mode=1, @description=N'Collects data about the space utilization of all the drives on the machine', @logging_level=0, @days_until_expiration=0, @schedule_name=N'MDW_Daily_Schedule', @collection_set_id=@collection_set_id_21 OUTPUT, @collection_set_uid=@collection_set_uid_22 OUTPUT
Select @collection_set_id_21, @collection_set_uid_22

Declare @collector_type_uid_23 uniqueidentifier
Select @collector_type_uid_23 = collector_type_uid From [msdb].[dbo].[syscollector_collector_types] Where name = N'Generic T-SQL Query Collector Type';
Declare @collection_item_id_24 int
EXEC [msdb].[dbo].[sp_syscollector_create_collection_item] @name=N'Drive Space Usage', @parameters=N'<ns:TSQLQueryCollector xmlns:ns="DataCollectorType"><Query><Value>
Select @@SERVERNAME as Server_Name, transaction_date, Drive, Capacity_MB, FreeSpace_MB
FROM DBA_Archive..hist_drive_space
where transaction_date &gt; DATEADD(DD,-1,GETDATE()) 
</Value><OutputTable>Drive_Space_Usage</OutputTable></Query></ns:TSQLQueryCollector>', @collection_item_id=@collection_item_id_24 OUTPUT, @frequency=60, @collection_set_id=@collection_set_id_21, @collector_type_uid=@collector_type_uid_23
Select @collection_item_id_24

Commit Transaction;
End Try
Begin Catch
Rollback Transaction;
DECLARE @ErrorMessage NVARCHAR(4000);
DECLARE @ErrorSeverity INT;
DECLARE @ErrorState INT;
DECLARE @ErrorNumber INT;
DECLARE @ErrorLine INT;
DECLARE @ErrorProcedure NVARCHAR(200);
SELECT @ErrorLine = ERROR_LINE(),
       @ErrorSeverity = ERROR_SEVERITY(),
       @ErrorState = ERROR_STATE(),
       @ErrorNumber = ERROR_NUMBER(),
       @ErrorMessage = ERROR_MESSAGE(),
       @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-');
RAISERROR (14684, @ErrorSeverity, 1 , @ErrorNumber, @ErrorSeverity, @ErrorState, @ErrorProcedure, @ErrorLine, @ErrorMessage);

End Catch;

GO





Begin Transaction
Begin Try
Declare @collection_set_id_25 int
Declare @collection_set_uid_26 uniqueidentifier
EXEC [msdb].[dbo].[sp_syscollector_create_collection_set] @name=N'Database Space Usage', @collection_mode=1, @description=N'Collects data about the space utilization of all the Database on the server', @logging_level=0, @days_until_expiration=0, @schedule_name=N'MDW_Daily_Schedule', @collection_set_id=@collection_set_id_25 OUTPUT, @collection_set_uid=@collection_set_uid_26 OUTPUT
Select @collection_set_id_25, @collection_set_uid_26

Declare @collector_type_uid_27 uniqueidentifier
Select @collector_type_uid_27 = collector_type_uid From [msdb].[dbo].[syscollector_collector_types] Where name = N'Generic T-SQL Query Collector Type';
Declare @collection_item_id_28 int
EXEC [msdb].[dbo].[sp_syscollector_create_collection_item] @name=N'Database Space Usage', @parameters=N'<ns:TSQLQueryCollector xmlns:ns="DataCollectorType"><Query><Value>
Select @@SERVERNAME as Server_Name,[dbid], [dbname], [data_file_size_KB], [log_file_size_KB], 
[data_reserved_KB], [data_used_KB],[transaction_date]
FROM DBA_Archive..[hist_database_size]
where transaction_date &gt; DATEADD(DD,-1,GETDATE()) 
</Value><OutputTable>Database_Space_Usage</OutputTable></Query></ns:TSQLQueryCollector>', @collection_item_id=@collection_item_id_28 OUTPUT, @frequency=60, @collection_set_id=@collection_set_id_25, @collector_type_uid=@collector_type_uid_27
Select @collection_item_id_28

Commit Transaction;
End Try
Begin Catch
Rollback Transaction;
DECLARE @ErrorMessage NVARCHAR(4000);
DECLARE @ErrorSeverity INT;
DECLARE @ErrorState INT;
DECLARE @ErrorNumber INT;
DECLARE @ErrorLine INT;
DECLARE @ErrorProcedure NVARCHAR(200);
SELECT @ErrorLine = ERROR_LINE(),
       @ErrorSeverity = ERROR_SEVERITY(),
       @ErrorState = ERROR_STATE(),
       @ErrorNumber = ERROR_NUMBER(),
       @ErrorMessage = ERROR_MESSAGE(),
       @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-');
RAISERROR (14684, @ErrorSeverity, 1 , @ErrorNumber, @ErrorSeverity, @ErrorState, @ErrorProcedure, @ErrorLine, @ErrorMessage);

End Catch;

GO



Begin Transaction
Begin Try
Declare @collection_set_id_29 int
Declare @collection_set_uid_30 uniqueidentifier
EXEC [msdb].[dbo].[sp_syscollector_create_collection_set] @name=N'Deadlock Count', @collection_mode=1, @description=N'Collects data about the number of deadlocks happening on the server', @logging_level=0, @days_until_expiration=0, @schedule_name=N'MDW_Daily_Schedule', @collection_set_id=@collection_set_id_29 OUTPUT, @collection_set_uid=@collection_set_uid_30 OUTPUT
Select @collection_set_id_29, @collection_set_uid_30

Declare @collector_type_uid_31 uniqueidentifier
Select @collector_type_uid_31 = collector_type_uid From [msdb].[dbo].[syscollector_collector_types] Where name = N'Generic T-SQL Query Collector Type';
Declare @collection_item_id_32 int
EXEC [msdb].[dbo].[sp_syscollector_create_collection_item] @name=N'Deadlock Count', @parameters=N'<ns:TSQLQueryCollector xmlns:ns="DataCollectorType"><Query><Value>
Select @@SERVERNAME as Server_Name,convert(date,EventTime,101) as Date,COUNT(ID) as Deadlock_Count
FROM DBA_Archive..hist_deadlocks
where EventTime &gt; DATEADD(DD,-1,GETDATE())
GROUP BY convert(date,EventTime,101) 
</Value><OutputTable>Deadlock_Count</OutputTable></Query></ns:TSQLQueryCollector>', @collection_item_id=@collection_item_id_32 OUTPUT, @frequency=60, @collection_set_id=@collection_set_id_29, @collector_type_uid=@collector_type_uid_31
Select @collection_item_id_32

Commit Transaction;
End Try
Begin Catch
Rollback Transaction;
DECLARE @ErrorMessage NVARCHAR(4000);
DECLARE @ErrorSeverity INT;
DECLARE @ErrorState INT;
DECLARE @ErrorNumber INT;
DECLARE @ErrorLine INT;
DECLARE @ErrorProcedure NVARCHAR(200);
SELECT @ErrorLine = ERROR_LINE(),
       @ErrorSeverity = ERROR_SEVERITY(),
       @ErrorState = ERROR_STATE(),
       @ErrorNumber = ERROR_NUMBER(),
       @ErrorMessage = ERROR_MESSAGE(),
       @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-');
RAISERROR (14684, @ErrorSeverity, 1 , @ErrorNumber, @ErrorSeverity, @ErrorState, @ErrorProcedure, @ErrorLine, @ErrorMessage);

End Catch;

GO


Begin Transaction
Begin Try
Declare @collection_set_id_33 int
Declare @collection_set_uid_34 uniqueidentifier
EXEC [msdb].[dbo].[sp_syscollector_create_collection_set] @name=N'Backup Failure Report', @collection_mode=1, @description=N'Collects data regarding those databases that were not backed up as part of the standard backup schedule', @logging_level=0, @days_until_expiration=0, @schedule_name=N'MDW_Daily_Schedule', @collection_set_id=@collection_set_id_33 OUTPUT, @collection_set_uid=@collection_set_uid_34 OUTPUT
Select @collection_set_id_33, @collection_set_uid_34

Declare @collector_type_uid_35 uniqueidentifier
Select @collector_type_uid_35 = collector_type_uid From [msdb].[dbo].[syscollector_collector_types] Where name = N'Generic T-SQL Query Collector Type';
Declare @collection_item_id_36 int
EXEC [msdb].[dbo].[sp_syscollector_create_collection_item] @name=N'Backup Failure Report', @parameters=N'<ns:TSQLQueryCollector xmlns:ns="DataCollectorType"><Query><Value>
SELECT     
	@@SERVERNAME AS Server, 
	msdb.dbo.backupset.database_name  COLLATE DATABASE_DEFAULT AS [Database], 
	MAX(msdb.dbo.backupset.backup_finish_date) AS [Last Backup Date], 
    DATEDIFF(hh, MAX(msdb.dbo.backupset.backup_finish_date), 
	GETDATE()) AS [Backup Age (Hours)], 
	''No Backups in last 24 hours'' AS Description
FROM         
	msdb.dbo.backupset INNER JOIN dbo.sysdatabases 
	ON msdb.dbo.backupset.database_name COLLATE DATABASE_DEFAULT = dbo.sysdatabases.name COLLATE DATABASE_DEFAULT 
	INNER JOIN sys.databases ON dbo.sysdatabases.dbid = sys.databases.database_id AND sys.databases.state_desc != ''OFFLINE''
	where master.dbo.sysdatabases.name not in (''master'',''model'',''msdb'',''tempdb'',''northwind'')
	and master.dbo.sysdatabases.name not like ''ReportServer%''
	and master.dbo.sysdatabases.name not like ''AdventureWorks%''
	and master.dbo.sysdatabases.name not like ''%_Archive''
	and master.dbo.sysdatabases.name not like ''Test%'' 
	and DATEADD(HH,-24,getdate()) &gt; master.dbo.sysdatabases.crdate
	GROUP BY msdb.dbo.backupset.database_name
HAVING (DATEADD(dd, - 1, GETDATE()) &gt; MAX(msdb.dbo.backupset.backup_finish_date))
</Value><OutputTable>Backup_Failure_Report</OutputTable></Query></ns:TSQLQueryCollector>', @collection_item_id=@collection_item_id_36 OUTPUT, @frequency=60, @collection_set_id=@collection_set_id_33, @collector_type_uid=@collector_type_uid_35
Select @collection_item_id_36

Commit Transaction;
End Try
Begin Catch
Rollback Transaction;
DECLARE @ErrorMessage NVARCHAR(4000);
DECLARE @ErrorSeverity INT;
DECLARE @ErrorState INT;
DECLARE @ErrorNumber INT;
DECLARE @ErrorLine INT;
DECLARE @ErrorProcedure NVARCHAR(200);
SELECT @ErrorLine = ERROR_LINE(),
       @ErrorSeverity = ERROR_SEVERITY(),
       @ErrorState = ERROR_STATE(),
       @ErrorNumber = ERROR_NUMBER(),
       @ErrorMessage = ERROR_MESSAGE(),
       @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-');
RAISERROR (14684, @ErrorSeverity, 1 , @ErrorNumber, @ErrorSeverity, @ErrorState, @ErrorProcedure, @ErrorLine, @ErrorMessage);

End Catch;

GO





use DBA_Archive
go
alter table hist_error_reported alter column message varchar(4000)
GO

use master
go

Begin Transaction
Begin Try
Declare @collection_set_id_37 int
Declare @collection_set_uid_38 uniqueidentifier
EXEC [msdb].[dbo].[sp_syscollector_create_collection_set] @name=N'Critical Errors Report', @collection_mode=1, @description=N'Collects information regarding the critical errors that were reported on the server', @logging_level=0, @days_until_expiration=0, @schedule_name=N'MDW_Daily_Schedule', @collection_set_id=@collection_set_id_37 OUTPUT, @collection_set_uid=@collection_set_uid_38 OUTPUT
Select @collection_set_id_37, @collection_set_uid_38
Declare @collector_type_uid_39 uniqueidentifier
Select @collector_type_uid_39 = collector_type_uid From [msdb].[dbo].[syscollector_collector_types] Where name = N'Generic T-SQL Query Collector Type';
Declare @collection_item_id_40 int
EXEC [msdb].[dbo].[sp_syscollector_create_collection_item] @name=N'Critical Errors Report', @parameters=N'<ns:TSQLQueryCollector xmlns:ns="DataCollectorType"><Query><Value>
select @@servername as Server_Name,EventType,EventTime,severity,message from DBA_Archive..hist_error_reported
where EventTime &gt; DATEADD(DD,-1,getdate()) 
and severity =  20
</Value><OutputTable>Critical_Errors_Report</OutputTable></Query></ns:TSQLQueryCollector>', @collection_item_id=@collection_item_id_40 OUTPUT, @frequency=60, @collection_set_id=@collection_set_id_37, @collector_type_uid=@collector_type_uid_39
Select @collection_item_id_40

Commit Transaction;
End Try
Begin Catch
Rollback Transaction;
DECLARE @ErrorMessage NVARCHAR(4000);
DECLARE @ErrorSeverity INT;
DECLARE @ErrorState INT;
DECLARE @ErrorNumber INT;
DECLARE @ErrorLine INT;
DECLARE @ErrorProcedure NVARCHAR(200);
SELECT @ErrorLine = ERROR_LINE(),
       @ErrorSeverity = ERROR_SEVERITY(),
       @ErrorState = ERROR_STATE(),
       @ErrorNumber = ERROR_NUMBER(),
       @ErrorMessage = ERROR_MESSAGE(),
       @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-');
RAISERROR (14684, @ErrorSeverity, 1 , @ErrorNumber, @ErrorSeverity, @ErrorState, @ErrorProcedure, @ErrorLine, @ErrorMessage);
End Catch;
GO



Begin Transaction
Begin Try
Declare @collection_set_id_41 int
Declare @collection_set_uid_42 uniqueidentifier
EXEC [msdb].[dbo].[sp_syscollector_create_collection_set] @name=N'Backup History Report', @collection_mode=1, @description=N'Collects information regarding the critical errors that were reported on the server', @logging_level=0, @days_until_expiration=0, @schedule_name=N'MDW_Daily_Schedule', @collection_set_id=@collection_set_id_41 OUTPUT, @collection_set_uid=@collection_set_uid_42 OUTPUT
Select @collection_set_id_41, @collection_set_uid_42

Declare @collector_type_uid_43 uniqueidentifier
Select @collector_type_uid_43 = collector_type_uid From [msdb].[dbo].[syscollector_collector_types] Where name = N'Generic T-SQL Query Collector Type';
Declare @collection_item_id_44 int
EXEC [msdb].[dbo].[sp_syscollector_create_collection_item] @name=N'Backup History Report', @parameters=N'<ns:TSQLQueryCollector xmlns:ns="DataCollectorType"><Query><Value>
select @@SERVERNAME as Server_Name, database_name,user_name,database_creation_date,backup_start_date,backup_finish_date,type,is_copy_only,recovery_model
from msdb..backupset where 
backup_start_date &gt; DATEADD(DD,-1,getdate())
</Value><OutputTable>Backup_History_Report</OutputTable></Query></ns:TSQLQueryCollector>', @collection_item_id=@collection_item_id_44 OUTPUT, @frequency=60, @collection_set_id=@collection_set_id_41, @collector_type_uid=@collector_type_uid_43
Select @collection_item_id_44

Commit Transaction;
End Try
Begin Catch
Rollback Transaction;
DECLARE @ErrorMessage NVARCHAR(4000);
DECLARE @ErrorSeverity INT;
DECLARE @ErrorState INT;
DECLARE @ErrorNumber INT;
DECLARE @ErrorLine INT;
DECLARE @ErrorProcedure NVARCHAR(200);
SELECT @ErrorLine = ERROR_LINE(),
       @ErrorSeverity = ERROR_SEVERITY(),
       @ErrorState = ERROR_STATE(),
       @ErrorNumber = ERROR_NUMBER(),
       @ErrorMessage = ERROR_MESSAGE(),
       @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-');
RAISERROR (14684, @ErrorSeverity, 1 , @ErrorNumber, @ErrorSeverity, @ErrorState, @ErrorProcedure, @ErrorLine, @ErrorMessage);
End Catch;
GO


Begin Transaction
Begin Try
Declare @collection_set_id_45 int
Declare @collection_set_uid_46 uniqueidentifier
EXEC [msdb].[dbo].[sp_syscollector_create_collection_set] @name=N'SQL Statements Report', @collection_mode=1, @description=N'Collects information regarding the critical errors that were reported on the server', @logging_level=0, @days_until_expiration=0, @schedule_name=N'MDW_Daily_Schedule', @collection_set_id=@collection_set_id_45 OUTPUT, @collection_set_uid=@collection_set_uid_46 OUTPUT
Select @collection_set_id_45, @collection_set_uid_46

Declare @collector_type_uid_47 uniqueidentifier
Select @collector_type_uid_47 = collector_type_uid From [msdb].[dbo].[syscollector_collector_types] Where name = N'Generic T-SQL Query Collector Type';
Declare @collection_item_id_48 int
EXEC [msdb].[dbo].[sp_syscollector_create_collection_item] @name=N'SQL Statements Report', @parameters=N'<ns:TSQLQueryCollector xmlns:ns="DataCollectorType"><Query><Value>
select @@SERVERNAME as Server_Name,EventTime,cpu,reads,writes, duration as Duration_Secs, 
SUBSTRING (cast(StatementText as varchar(4000)), 0,4000)   as Statement_Text
from DBA_Archive.dbo.hist_sql_statement_completed 
where duration &gt; 1
and EventTime &gt; DATEADD(DD,-1,getdate())
</Value><OutputTable>SQL_Statements_Report</OutputTable></Query></ns:TSQLQueryCollector>', @collection_item_id=@collection_item_id_48 OUTPUT, @frequency=60, @collection_set_id=@collection_set_id_45, @collector_type_uid=@collector_type_uid_47
Select @collection_item_id_48

Commit Transaction;
End Try
Begin Catch
Rollback Transaction;
DECLARE @ErrorMessage NVARCHAR(4000);
DECLARE @ErrorSeverity INT;
DECLARE @ErrorState INT;
DECLARE @ErrorNumber INT;
DECLARE @ErrorLine INT;
DECLARE @ErrorProcedure NVARCHAR(200);
SELECT @ErrorLine = ERROR_LINE(),
       @ErrorSeverity = ERROR_SEVERITY(),
       @ErrorState = ERROR_STATE(),
       @ErrorNumber = ERROR_NUMBER(),
       @ErrorMessage = ERROR_MESSAGE(),
       @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-');
RAISERROR (14684, @ErrorSeverity, 1 , @ErrorNumber, @ErrorSeverity, @ErrorState, @ErrorProcedure, @ErrorLine, @ErrorMessage);
End Catch;
GO


Begin Transaction
Begin Try
Declare @collection_set_id_25 int
Declare @collection_set_uid_26 uniqueidentifier
EXEC [msdb].[dbo].[sp_syscollector_create_collection_set] @name=N'Database Size Utilization', @collection_mode=1, @description=N'Collects data about the database size utilization', @logging_level=0, @days_until_expiration=0, @schedule_name=N'MDW_Daily_Schedule', @collection_set_id=@collection_set_id_25 OUTPUT, @collection_set_uid=@collection_set_uid_26 OUTPUT
Select @collection_set_id_25, @collection_set_uid_26

Declare @collector_type_uid_27 uniqueidentifier
Select @collector_type_uid_27 = collector_type_uid From [msdb].[dbo].[syscollector_collector_types] Where name = N'Generic T-SQL Query Collector Type';
Declare @collection_item_id_28 int
EXEC [msdb].[dbo].[sp_syscollector_create_collection_item] @name=N'Database Size Utilization', @parameters=N'<ns:TSQLQueryCollector xmlns:ns="DataCollectorType"><Query><Value>
Select @@SERVERNAME as Server_Name,	[dbid],[dbname],[data_size_MB],[log_size_MB],[DB_Size_GB],[transaction_date]
FROM DBA_Archive..[hist_database_size_latest]
where transaction_date &gt; DATEADD(DD,-1,GETDATE()) 
</Value><OutputTable>Database_Size_Utilization</OutputTable></Query></ns:TSQLQueryCollector>', @collection_item_id=@collection_item_id_28 OUTPUT, @frequency=60, @collection_set_id=@collection_set_id_25, @collector_type_uid=@collector_type_uid_27
Select @collection_item_id_28

Commit Transaction;
End Try
Begin Catch
Rollback Transaction;
DECLARE @ErrorMessage NVARCHAR(4000);
DECLARE @ErrorSeverity INT;
DECLARE @ErrorState INT;
DECLARE @ErrorNumber INT;
DECLARE @ErrorLine INT;
DECLARE @ErrorProcedure NVARCHAR(200);
SELECT @ErrorLine = ERROR_LINE(),
       @ErrorSeverity = ERROR_SEVERITY(),
       @ErrorState = ERROR_STATE(),
       @ErrorNumber = ERROR_NUMBER(),
       @ErrorMessage = ERROR_MESSAGE(),
       @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-');
RAISERROR (14684, @ErrorSeverity, 1 , @ErrorNumber, @ErrorSeverity, @ErrorState, @ErrorProcedure, @ErrorLine, @ErrorMessage);

End Catch;

GO


msdb..sp_syscollector_start_collection_set   @name =  'Database Size Utilization'
GO



MSDB..sp_syscollector_start_collection_set   @name =  'Backup Failure Report'
GO
MSDB..sp_syscollector_start_collection_set   @name =  'Backup History Report'
GO
MSDB..sp_syscollector_start_collection_set   @name =  'Critical Errors Report'
GO
MSDB..sp_syscollector_start_collection_set   @name =  'Database Space Usage'
GO
MSDB..sp_syscollector_start_collection_set   @name =  'Deadlock Count'
GO
MSDB..sp_syscollector_start_collection_set   @name =  'Drive Space Usage'
GO
MSDB..sp_syscollector_start_collection_set   @name =  'SQL Statements Report'
GO
