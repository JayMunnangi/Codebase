USE [master]
GO

/****** Object:  StoredProcedure [dbo].[spe_shrinklog_na]    Script Date: 12/27/2015 10:25:56 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spe_shrinklog_na]  
as  
Begin  
declare @dbname nvarchar(256)  
declare @logname nvarchar(256)  
declare log_cursor cursor   
for  
SELECT db.name DBName, mf.name DBLogicalName  
FROM sys.databases db join sys.master_files mf  
on db.database_id = mf.database_id  
WHERE  db.name not in ('master','model','msdb','tempdb')
AND type_desc = 'log' AND db.state_desc = 'online' AND db.is_read_only=0
 
  
open log_cursor  
FETCH NEXT FROM log_cursor INTO @dbname, @logname  
WHILE @@FETCH_STATUS = 0  
BEGIN  
  
EXEC(' use [' + @dbname + '] DBCC SHRINKFILE (''' + @logname + ''', 10)')  
print '"'+@dbname + '" - shrinked successfully'  
FETCH NEXT FROM log_cursor INTO @dbname, @logname  
END  
CLOSE log_cursor  
DEALLOCATE log_cursor  
end   



GO


------------------------------------

USE [msdb]
GO

/****** Object:  Job [Shrink_LDFs]    Script Date: 12/27/2015 10:58:20 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 12/27/2015 10:58:20 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Shrink_LDFs', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'This is intended to shrink all the database log files(LDFs) to 10 MB.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'CRIMSONAD\svc_onau-inftst01', 
		@notify_email_operator_name=N'', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Shrink_AllDB]    Script Date: 12/27/2015 10:58:20 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Shrink_AllDB', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec [spe_shrinklog_na]', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Shrink_AllDB', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=42, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20111012, 
		@active_end_date=99991231, 
		@active_start_time=203000, 
		@active_end_time=235959, 
		@schedule_uid=N'7f354504-6bbb-44f3-b313-130043e6143c'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO


