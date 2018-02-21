use master
go

EXEC sp_CONFIGURE 'show advanced options' , '1';
GO
RECONFIGURE WITH OVERRIDE;
GO

EXEC sp_CONFIGURE 'Ad Hoc Distributed Queries' , '1'
GO
RECONFIGURE WITH OVERRIDE;
GO

EXEC sp_CONFIGURE 'Database Mail XPs' , '1'
GO
RECONFIGURE WITH OVERRIDE;
GO

EXEC sp_CONFIGURE 'xp_cmdshell' , '1'
GO
RECONFIGURE WITH OVERRIDE;
GO

EXEC sp_CONFIGURE 'backup compression default' , '1'
GO
RECONFIGURE WITH OVERRIDE;
GO

EXEC sp_CONFIGURE 'optimize for ad hoc workloads' , '1'
GO
RECONFIGURE WITH OVERRIDE;
GO

EXEC sp_CONFIGURE 'default trace enabled' , '1'
GO
RECONFIGURE WITH OVERRIDE;
GO

declare @OldServerName varchar(50), @NewServerName varchar(50)
SET @NewServerName = cast(serverproperty('servername')as varchar)
SELECT @OldServerName = srvname FROM master..sysservers WHERE isremote =1
EXEC msdb.dbo.sp_dropserver @OldServerName
EXEC msdb.dbo.sp_addserver @server = @NewServerName , @local =  'local'
GO

EXEC sys.sp_configure N'fill factor (%)', N'80'
GO
RECONFIGURE WITH OVERRIDE;
GO

EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', REG_SZ, N'E:\SQLDATA\Data'
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', REG_SZ, N'F:\SQLDATA\Logs'
GO
EXEC sp_configure 'clr enabled', 1;
GO
RECONFIGURE WITH OVERRIDE;
GO

EXEC sp_CONFIGURE 'show advanced options' , '0';
GO
RECONFIGURE WITH OVERRIDE;
GO

-- Create a Database Mail profile 
EXECUTE msdb.dbo.sysmail_add_profile_sp 
@profile_name = 'SQLMailProfile'; 
--@description = 'Notification service for SQL Server' ; 

-- Create a Database Mail account 
EXECUTE msdb.dbo.sysmail_add_account_sp 
@account_name = 'SQLMail', 
@description = 'SQL Mail Account', 
@email_address = 'ADO-DatabaseAdministration@advisory.com', 
@display_name = 'SQLMail', 
@mailserver_name = 'smtp.crimsonad.local',
@use_default_credentials = 1; 

-- Add the account to the profile 
EXECUTE msdb.dbo.sysmail_add_profileaccount_sp 
@profile_name = 'SQLMailProfile', 
@account_name = 'SQLMail', 
@sequence_number =1 ; 

-- Grant access to the profile to the DBMailUsers role 
EXECUTE msdb.dbo.sysmail_add_principalprofile_sp 
@profile_name = 'SQLMailProfile', 
@principal_id = 0, 
@is_default = 1 ; 


--Add the Operator
IF not (EXISTS (SELECT name FROM msdb.dbo.sysoperators WHERE name = N'DBA'))
	EXECUTE msdb.dbo.sp_add_operator @name = N'DBA', @enabled = 1, @email_address = N'ADO-DatabaseAdministration@advisory.com', @category_name = N'[Uncategorized]', @weekday_pager_start_time = 80000, @weekday_pager_end_time = 180000, @saturday_pager_start_time = 80000, @saturday_pager_end_time = 180000, @sunday_pager_start_time = 80000, @sunday_pager_end_time = 180000, @pager_days = 62

	
USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1
GO
EXEC master.dbo.xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent', N'UseDatabaseMail', N'REG_DWORD', 1
GO
EXEC master.dbo.xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent', N'DatabaseMailProfile', N'REG_SZ', N'SQLMailProfile'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @jobhistory_max_rows=10000, 
		@jobhistory_max_rows_per_job=1000, 
		@email_save_in_sent_folder=1
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @alert_replace_runtime_tokens=1

USE [msdb]
GO
EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator=N'DBA', 
		@notificationmethod=1
GO

USE master
go
ALTER LOGIN [sa] DISABLE
GO
