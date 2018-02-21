
/* Create Database for storing all the sampling details */

USE [master]
GO

/****** Object:  Database [DBA_Archive]    Script Date: 02/18/2014 02:25:09 ******/
IF NOT EXISTS(SELECT 1 FROM sys.databases WHERE name = 'DBA_Archive')
CREATE DATABASE [DBA_Archive] 
-- ON  PRIMARY ( NAME = N'DBA_Archive', FILENAME = N'E:\Databases\DBA_Archive.mdf' , SIZE = 10485760KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
-- LOG ON 
-- ( NAME = N'DBA_Archive_log', FILENAME = N'F:\DBLogs\DBA_Archive_log.ldf' , SIZE = 524288KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO

IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [DBA_Archive].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO

ALTER DATABASE [DBA_Archive] SET ANSI_NULL_DEFAULT OFF 
GO

ALTER DATABASE [DBA_Archive] SET ANSI_NULLS OFF 
GO

ALTER DATABASE [DBA_Archive] SET ANSI_PADDING OFF 
GO

ALTER DATABASE [DBA_Archive] SET ANSI_WARNINGS OFF 
GO

ALTER DATABASE [DBA_Archive] SET ARITHABORT OFF 
GO

ALTER DATABASE [DBA_Archive] SET AUTO_CLOSE OFF 
GO

ALTER DATABASE [DBA_Archive] SET AUTO_CREATE_STATISTICS ON 
GO

ALTER DATABASE [DBA_Archive] SET AUTO_SHRINK OFF 
GO

ALTER DATABASE [DBA_Archive] SET AUTO_UPDATE_STATISTICS ON 
GO

ALTER DATABASE [DBA_Archive] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO

ALTER DATABASE [DBA_Archive] SET CURSOR_DEFAULT  GLOBAL 
GO

ALTER DATABASE [DBA_Archive] SET CONCAT_NULL_YIELDS_NULL OFF 
GO

ALTER DATABASE [DBA_Archive] SET NUMERIC_ROUNDABORT OFF 
GO

ALTER DATABASE [DBA_Archive] SET QUOTED_IDENTIFIER OFF 
GO

ALTER DATABASE [DBA_Archive] SET RECURSIVE_TRIGGERS OFF 
GO

ALTER DATABASE [DBA_Archive] SET  DISABLE_BROKER 
GO

ALTER DATABASE [DBA_Archive] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO

ALTER DATABASE [DBA_Archive] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO

ALTER DATABASE [DBA_Archive] SET TRUSTWORTHY OFF 
GO

ALTER DATABASE [DBA_Archive] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO

ALTER DATABASE [DBA_Archive] SET PARAMETERIZATION SIMPLE 
GO

ALTER DATABASE [DBA_Archive] SET READ_COMMITTED_SNAPSHOT OFF 
GO

ALTER DATABASE [DBA_Archive] SET HONOR_BROKER_PRIORITY OFF 
GO

ALTER DATABASE [DBA_Archive] SET  READ_WRITE 
GO

ALTER DATABASE [DBA_Archive] SET RECOVERY SIMPLE 
GO

ALTER DATABASE [DBA_Archive] SET  MULTI_USER 
GO

ALTER DATABASE [DBA_Archive] SET PAGE_VERIFY CHECKSUM  
GO

ALTER DATABASE [DBA_Archive] SET DB_CHAINING OFF 
GO






/* Sample Server configuration details daily once
This script will capture and preserve only those parameters that are different from the default values */

USE [DBA_Archive]
GO
/****** Object:  Table [dbo].[hist_wait_info]    Script Date: 06/05/2014 02:12:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[hist_wait_info](
	[EventType] [nvarchar](128) NULL,
	[EventTime] [datetime] NULL,
	[SessionXML] [xml] NULL,
	[wait_type] [varchar](255) NULL,
	[duration] [int] NULL,
	[max_duration] [int] NULL,
	[session_id] [int] NULL,
	[StatementText] [xml] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[hist_sql_statement_completed]    Script Date: 06/05/2014 02:12:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[hist_sql_statement_completed](
	[EventType] [nvarchar](128) NULL,
	[EventTime] [datetime] NULL,
	[SessionXML] [xml] NULL,
	[source_database] [nvarchar](128) NULL,
	[Obj] [int] NULL,
	[object_type] [int] NULL,
	[cpu] [int] NULL,
	[duration] [numeric](31, 10) NULL,
	[durationMin] [varchar](32) NULL,
	[reads] [int] NULL,
	[writes] [int] NULL,
	[StatementText] [xml] NULL,
	[query_plan] [xml] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[hist_error_reported]    Script Date: 06/05/2014 02:12:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[hist_error_reported](
	[EventType] [nvarchar](128) NULL,
	[EventTime] [datetime] NULL,
	[SessionXML] [xml] NULL,
	[wait_type] [int] NULL,
	[severity] [int] NULL,
	[state] [int] NULL,
	[message] [varchar](4000) NULL,
	[StatementText] [xml] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[hist_deadlocks]    Script Date: 06/05/2014 02:12:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[hist_deadlocks](
	[EventTime] [datetime] NULL,
	[SessionXML] [xml] NULL,
	[XML_Report] [xml] NULL,
	[victimProcess] [varchar](255) NULL,
	[victimProcessQuery] [xml] NULL,
	[ID] [int] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
SET ANSI_PADDING OFF
GO


USE [DBA_Archive]
GO

/****** Object:  Table [dbo].[_hist_non_default_config_values]    Script Date: 02/14/2014 04:44:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = '_hist_non_default_config_values')
CREATE TABLE [dbo].[_hist_non_default_config_values](
	[name] [nvarchar](35) NOT NULL,
	[value_in_use] [sql_variant] NULL,
	[DefaultValue] [sql_variant] NULL,
	[transaction_date] datetime NOT NULL DEFAULT getdate()
) ON [PRIMARY]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE name = 'sp__Sample_server_config')
	DROP PROCEDURE sp__Sample_server_config
GO
CREATE PROCEDURE sp__Sample_server_config
AS
-- Know product version since values may defer based on version
BEGIN
DECLARE @ProductVersion nvarchar(128);
DECLARE @charindex bigint;
DECLARE @MajorVersion nvarchar(max);
SELECT @ProductVersion = CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128));
SELECT @charindex = CHARINDEX('.', @ProductVersion);
SET @MajorVersion = SUBSTRING(@ProductVersion, 1, @charindex-1);
DECLARE @tempValue sql_variant;

-- Create table of default values
DECLARE @tvDefaultValues TABLE (Id int IDENTITY(1,1), ConfigurationOption nvarchar(128), Value sql_variant);
INSERT INTO @tvDefaultValues VALUES ('access check cache bucket count', 0);
INSERT INTO @tvDefaultValues VALUES ('access check cache quota', 0);
INSERT INTO @tvDefaultValues VALUES ('ad hoc distributed queries', 0);
INSERT INTO @tvDefaultValues VALUES ('affinity I/O mask', 0);
INSERT INTO @tvDefaultValues VALUES ('affinity64 I/O mask', 0);
INSERT INTO @tvDefaultValues VALUES ('affinity mask', 0);
INSERT INTO @tvDefaultValues VALUES ('affinity64 mask', 0);
INSERT INTO @tvDefaultValues VALUES ('allow updates', 0);
INSERT INTO @tvDefaultValues VALUES ('backup compression default', 0);
INSERT INTO @tvDefaultValues VALUES ('blocked process threshold', 0);
INSERT INTO @tvDefaultValues VALUES ('c2 audit mode', 0);
INSERT INTO @tvDefaultValues VALUES ('clr enabled', 0);
INSERT INTO @tvDefaultValues VALUES ('common criteria compliance enabled', 0);
INSERT INTO @tvDefaultValues VALUES ('contained database authentication', 0);
INSERT INTO @tvDefaultValues VALUES ('cost threshold for parallelism', 5);
INSERT INTO @tvDefaultValues VALUES ('cross db ownership chaining', 0);
INSERT INTO @tvDefaultValues VALUES ('cursor threshold', -1);
INSERT INTO @tvDefaultValues VALUES ('Database Mail XPs', 0);
INSERT INTO @tvDefaultValues VALUES ('default full-text language', 1033);
INSERT INTO @tvDefaultValues VALUES ('default language', 0);
INSERT INTO @tvDefaultValues VALUES ('default trace enabled', 1);
INSERT INTO @tvDefaultValues VALUES ('disallow results from triggers', 0);
INSERT INTO @tvDefaultValues VALUES ('EKM provider enabled', 0);
INSERT INTO @tvDefaultValues VALUES ('filestream_access_level', 0);
INSERT INTO @tvDefaultValues VALUES ('fill factor', 0);
INSERT INTO @tvDefaultValues VALUES ('ft crawl bandwidth (max)', 100);
INSERT INTO @tvDefaultValues VALUES ('ft crawl bandwidth (min)', 0);
INSERT INTO @tvDefaultValues VALUES ('ft notify bandwidth (max)', 100);
INSERT INTO @tvDefaultValues VALUES ('ft notify bandwidth (min)', 0);
INSERT INTO @tvDefaultValues VALUES ('index create memory', 0);
INSERT INTO @tvDefaultValues VALUES ('in-doubt xact resolution', 0);
INSERT INTO @tvDefaultValues VALUES ('lightweight pooling', 0);
INSERT INTO @tvDefaultValues VALUES ('locks', 0);
INSERT INTO @tvDefaultValues VALUES ('max degree of parallelism', 0);
INSERT INTO @tvDefaultValues VALUES ('max full-text crawl range', 4);
INSERT INTO @tvDefaultValues VALUES ('max server memory', 2147483647);	-- actual name may also include 'MB', keeping per MSDN definition in link mentioned above.
INSERT INTO @tvDefaultValues VALUES ('max text repl size', 65536);
INSERT INTO @tvDefaultValues VALUES ('max worker threads', 0);
INSERT INTO @tvDefaultValues VALUES ('media retention', 0);
INSERT INTO @tvDefaultValues VALUES ('min memory per query', 1024);
INSERT INTO @tvDefaultValues VALUES ('min server memory', 0);
INSERT INTO @tvDefaultValues VALUES ('nested triggers', 1);
INSERT INTO @tvDefaultValues VALUES ('network packet size', 4096);
INSERT INTO @tvDefaultValues VALUES ('Ole Automation Procedures', 0);
INSERT INTO @tvDefaultValues VALUES ('open objects', 0);
INSERT INTO @tvDefaultValues VALUES ('optimize for ad hoc workloads', 0);
INSERT INTO @tvDefaultValues VALUES ('PH_timeout', 60);
INSERT INTO @tvDefaultValues VALUES ('precompute rank', 0);
INSERT INTO @tvDefaultValues VALUES ('priority boost', 0);
INSERT INTO @tvDefaultValues VALUES ('query governor cost limit', 0);
INSERT INTO @tvDefaultValues VALUES ('query wait', -1);
INSERT INTO @tvDefaultValues VALUES ('recovery interval', 0);
INSERT INTO @tvDefaultValues VALUES ('remote access', 1);
INSERT INTO @tvDefaultValues VALUES ('remote admin connections', 0);
IF @MajorVersion IN (9, 10) SET @tempValue = 20 ELSE SET @tempValue = 10;
INSERT INTO @tvDefaultValues VALUES ('remote login timeout', @tempValue);
INSERT INTO @tvDefaultValues VALUES ('remote proc trans', 0);
INSERT INTO @tvDefaultValues VALUES ('remote query timeout', 600);
INSERT INTO @tvDefaultValues VALUES ('Replication XPs Option', 0);
INSERT INTO @tvDefaultValues VALUES ('scan for startup procs', 0);
INSERT INTO @tvDefaultValues VALUES ('server trigger recursion', 1);
INSERT INTO @tvDefaultValues VALUES ('set working set size', 0);
INSERT INTO @tvDefaultValues VALUES ('show advanced options', 0);
INSERT INTO @tvDefaultValues VALUES ('SMO and DMO XPs', 1);
INSERT INTO @tvDefaultValues VALUES ('transform noise words', 0);
INSERT INTO @tvDefaultValues VALUES ('two digit year cutoff', 2049);
INSERT INTO @tvDefaultValues VALUES ('user connections', 0);
INSERT INTO @tvDefaultValues VALUES ('user options', 0);
INSERT INTO @tvDefaultValues VALUES ('xp_cmdshell', 0);

INSERT DBA_Archive.._hist_non_default_config_values(name,value_in_use,DefaultValue)
SELECT sc.name, sc.value_in_use, DF.Value AS DefaultValue 
FROM @tvDefaultValues DF JOIN sys.configurations sc 
ON sc.name LIKE '%' + DF.ConfigurationOption + '%' AND DF.Value <> sc.value_in_use 
WHERE sc.name <> 'show advanced options' ORDER BY sc.name
END
GO


USE [msdb]
GO

/****** Object:  Job [Sample_Server_Configuration]    Script Date: 02/18/2014 03:20:24 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 02/18/2014 03:20:24 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Sample_Server_Configuration', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Sample]    Script Date: 02/18/2014 03:20:25 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Sample', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec sp__Sample_server_config', 
		@database_name=N'DBA_Archive', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20140108, 
		@active_end_date=99991231, 
		@active_start_time=80000, 
		@active_end_time=235959, 
		@schedule_uid=N'ed2c7eb2-296e-4b6f-b226-f2da5537fcf6'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/* Sample database sizes of all the databases daily once */

USE [DBA_Archive]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
/****Table that preserves the size information locally on the server, in DBA_Archive database****/

IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'hist_database_size')
CREATE TABLE [dbo].[hist_database_size](
	[dbid] [int] NOT NULL,
	[dbname] [sysname] NOT NULL,
	[data_file_size_KB] [int] NOT NULL,
	[log_file_size_KB] [int] NOT NULL,
	[data_reserved_KB] [int] NOT NULL,
	[data_used_KB] [int] NOT NULL,
	[transaction_date] [datetime] NOT NULL,
	[Id] [numeric](16, 0) IDENTITY(1,1) NOT NULL
) ON [PRIMARY]
GO


USE [master]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/***Stored procedure that calculates & stores the database size in the table***/
CREATE PROC [dbo].[sp__sample_database_size]
AS 

DECLARE @query VARCHAR(8000)

set nocount on  

SET @query = 
'declare @pages bigint   
  ,@dbname sysname  
  ,@dbsize bigint  
  ,@logsize bigint  
  ,@reservedpages  bigint  
  ,@usedpages  bigint  
select @dbsize  = sum(convert(bigint,case when status & 64 = 0 then size else 0 end))
       ,@logsize = sum(convert(bigint,case when status & 64 <> 0 then size else 0 end))  
  from dbo.sysfiles  
select @reservedpages = sum(a.total_pages),  
       @usedpages = sum(a.used_pages),  
       @pages = sum(  
            CASE  
             When it.internal_type IN (202,204) Then 0  
             When a.type <> 1    Then a.used_pages  
             When p.index_id < 2 Then a.data_pages  
             Else 0  
            END  
       )  
  from sys.partitions p 
  join sys.allocation_units a 
    on p.partition_id = a.container_id  
  left join sys.internal_tables it 
    on p.object_id = it.object_id  
 /* unallocated space could not be negative */  
 INSERT DBA_Archive..hist_database_size
 (dbid,
  dbname,
  data_file_size_KB,
  log_file_size_KB,
  data_reserved_KB,
  data_used_KB,
  transaction_date
  )
 select db_id(),
        db_name(),  
        data_file_size = @dbsize * 8,
        log_file_size  = @logsize * 8,
        data_reserved  = @reservedpages * 8,
        data_used      = @usedpages * 8,
        getutcdate()
go'
EXEC (@query)
GO


USE [DBA_Archive]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/***Stored procedure that invokes the earlier stored procedure for all the databases that are online***/
CREATE PROC [dbo].[sample_database_sizes]
AS 
DECLARE @name varchar(100)
DECLARE @query varchar(1000)
DECLARE db_cursor CURSOR FOR 
SELECT name
FROM master.sys.databases
WHERE state_desc = 'ONLINE'
	
OPEN db_cursor 
FETCH NEXT FROM db_cursor INTO @name  
While @@FETCH_STATUS = 0
BEGIN
	SELECT @query = 'EXEC [' + @name + '].[dbo].[sp__sample_database_size]'
	Exec(@query)
	FETCH NEXT FROM db_cursor INTO @name
END	
Close db_cursor
DEALLOCATE db_cursor
GO



/*** Stored procedure that gives the trend information over the period of time along with the daily growth in size of that database***/
CREATE  PROCEDURE [dbo].[sp__get_daily_db_growth] 
@dbname sysname, 
@from_date datetime,
@to_date datetime = NULL
AS 

BEGIN

IF @to_date IS NOT NULL
BEGIN
	IF (@to_date < @from_date) 
	BEGIN
		PRINT 'Invalid Date range'
		RETURN (0)
	END
END
ELSE
	select @to_date = getdate()

DECLARE @daily TABLE
( sample_date DATETIME,
  data_used BIGINT,
  data_reserved BIGINT
)

IF @dbname = 'All'
  SELECT @dbname = NULL

 INSERT @daily
 SELECT  CONVERT(DATETIME,CONVERT(varchar(10),s.transaction_date,111)) AS sample_date,
         SUM(s.data_used_KB) as data_used,
         SUM(s.data_file_size_KB) as data_reserved
    FROM DBA_Archive..hist_database_size s
    JOIN ( SELECT CONVERT(varchar(10),transaction_date,111) as date, 
                  dbid,
                  MAX(transaction_date) as transaction_date
		     FROM DBA_Archive..hist_database_size 
            WHERE dbid = ISNULL(DB_ID(@dbname),dbid)
              AND transaction_date >= @from_date
              AND transaction_date <= DATEADD(DD, 2,@to_date)
            GROUP BY CONVERT(varchar(10),transaction_date,111), dbid
		 ) as d
      ON (s.transaction_date = d.transaction_date and d.dbid =
s.dbid)
   WHERE s.dbid = ISNULL(DB_ID(@dbname),s.dbid)
   GROUP BY CONVERT(DATETIME,CONVERT(varchar(10),s.transaction_date,111))

SELECT CONVERT(VARCHAR(10), this_day.sample_date, 111) as day,
       this_day.sample_date,
       this_day.data_reserved/1024.0 as data_reserved_in_MB,
       this_day.data_used/1024.0 as data_used_in_MB,
       (next_day.data_used - this_day.data_used)/1024.0 as growth_in_MB
  FROM @daily this_day
  LEFT JOIN @daily next_day
    ON (next_day.sample_date = DATEADD(DD, 1, this_day.sample_date)) 
    where this_day.sample_date < DATEADD(DD,1,@to_date)
 ORDER BY sample_date ASC
END
GO

USE [msdb]
GO

/****** Object:  Job [Sample_Database_Sizes]    Script Date: 02/18/2014 03:45:12 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 02/18/2014 03:45:12 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Sample_Database_Sizes', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Sample]    Script Date: 02/18/2014 03:45:12 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Sample', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec sample_database_sizes', 
		@database_name=N'DBA_Archive', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20140108, 
		@active_end_date=99991231, 
		@active_start_time=80000, 
		@active_end_time=235959, 
		@schedule_uid=N'ed2c7eb2-296e-4b6f-b226-f2da5537fcf6'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO


/* Sample disk/drive space utilization 
of all the drives on this machine
*/
USE [DBA_Archive]
GO
CREATE TABLE hist_drive_space
(
	[Drive] varchar(5) NOT NULL,
	[Capacity_MB] int NOT NULL,
	[FreeSpace_MB] int NOT NULL,
	transaction_date datetime NOT NULL default getdate()
)
go

CREATE PROCEDURE sp__Sample_Drive_space
AS
BEGIN
declare @svrName varchar(255)
declare @sql varchar(400)
--by default it will take the current server name, we can the set the server name as well
set @svrName = @@SERVERNAME
set @sql = 'powershell.exe -c "Get-WmiObject -ComputerName ' + QUOTENAME(@svrName,'''') + ' -Class Win32_Volume -Filter ''DriveType = 3'' | select name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1048576+''%''+$_.freespace/1048576+''*''}"'
--creating a temporary table
CREATE TABLE #output
(line varchar(255))
--inserting disk name, total space and free space value in to temporary table
insert #output
EXEC xp_cmdshell @sql
--script to retrieve the values in MB from PS Script output
INSERT hist_drive_space(Drive,Capacity_MB,FreeSpace_MB)
select rtrim(ltrim(SUBSTRING(line,1,CHARINDEX('|',line) -1))) as drivename
      ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('|',line)+1,
      (CHARINDEX('%',line) -1)-CHARINDEX('|',line)) )) as Float),0) as 'capacity(MB)'
      ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('%',line)+1,
      (CHARINDEX('*',line) -1)-CHARINDEX('%',line)) )) as Float),0) as 'freespace(MB)'
from #output
where line like '[A-Z][:]%'
order by drivename
drop table #output
END
go


USE [msdb]
GO

/****** Object:  Job [Sample_Disk_Space]    Script Date: 02/19/2014 23:49:51 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 02/19/2014 23:49:52 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Sample_Disk_Space', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Sample]    Script Date: 02/19/2014 23:49:52 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Sample', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec sp__Sample_Drive_space', 
		@database_name=N'DBA_Archive', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20140108, 
		@active_end_date=99991231, 
		@active_start_time=80000, 
		@active_end_time=235959, 
		@schedule_uid=N'ed2c7eb2-296e-4b6f-b226-f2da5537fcf6'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


USE [DBA_Archive]
GO

IF NOT EXISTS (select 1 from sys.objects where object_id = object_id ( N'[dbo].[hist_performance_counters]') and OBJECTPROPERTY(object_id, N'IsUserTable') = 1)
	CREATE TABLE [dbo].[hist_performance_counters](
		[object_name] [nchar](128) NOT NULL,
		[counter_name] [nchar](128) NOT NULL,
		[instance_name] [nchar](128) NULL,
		[cntr_value] [bigint] NOT NULL,
		[cntr_type] [int] NOT NULL,
		transaction_date datetime NOT NULL default getdate()
	) ON [PRIMARY]
GO

USE [DBA_Archive]
GO
CREATE PROC [dbo].[sp__sample_performance_counters]
AS 
	INSERT into DBA_Archive..hist_performance_counters(object_name,counter_name,instance_name,cntr_value,cntr_type)
	select object_name,counter_name,instance_name,cntr_value,cntr_type from sys.dm_os_performance_counters
	where 
	/*****down the line, I will be placing these counters and objects in a lookup table so we don't have to hardcode anything. The status 
	flag would give us the flexibility to enable or disable the stats collection at anypoint *****/
		counter_name in (
			'Buffer cache hit ratio',
			'Page life expectancy',
			'Lazy writes/sec',
			'Checkpoint pages/sec',
			'Page Splits/sec',
			'Page reads/sec',
			'Page writes/sec'
			) 
		OR
		object_name in (
			'SQLServer:Wait Statistics',
			'SQLServer:Access Methods',
			'SQLServer:Locks'
			)

GO

USE [DBA_Archive]
GO

IF NOT EXISTS (select 1 from sys.objects where object_id = object_id ( N'[dbo].[waitstats]') and OBJECTPROPERTY(object_id, N'IsUserTable') = 1)
	CREATE TABLE [dbo].[waitstats] (
		[wait_type] nvarchar(60) not null, 
		[waiting_tasks_count] bigint not null,
		[wait_time_ms] bigint not null,
		[max_wait_time_ms] bigint not null,
		[signal_wait_time_ms] bigint not null,
		transaction_date datetime not null default getdate()
	)
GO

CREATE proc [dbo].[sp__sample_wait_statistics] 
AS
BEGIN
			DECLARE @now date = getdate()
            insert into [dbo].[waitstats] ([wait_type], [waiting_tasks_count], [wait_time_ms], [max_wait_time_ms], [signal_wait_time_ms], transaction_date)	
			select [wait_type], [waiting_tasks_count], [wait_time_ms], [max_wait_time_ms], [signal_wait_time_ms], @now
				from sys.dm_os_wait_stats
			insert into [dbo].[waitstats] ([wait_type], [waiting_tasks_count], [wait_time_ms], [max_wait_time_ms], [signal_wait_time_ms], transaction_date)	
				select 'Total',sum([waiting_tasks_count]), sum([wait_time_ms]), 0, sum([signal_wait_time_ms]),@now
				from [dbo].[waitstats]
				where transaction_date = @now
END
GO


USE [DBA_Archive]
GO

/****** Object:  Table [dbo].[hist_filestats]    Script Date: 02/20/2014 00:48:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[hist_filestats](
	[dbname] [varchar](128) NULL,
	[fName] [varchar](2048) NULL,
	[timeStart]  datetime NOT NULL, 
	[readsNum] bigint, 
    [readsBytes] bigint, 
    [readsIoStall] bigint, 
    [writesNum] bigint, 
    [writesBytes] bigint, 
    [writesIoStall] bigint, 
    [ioStall] bigint, 
    [timeEnd] datetime NOT NULL, 
	[timeDiff] [bigint] NULL,
	[readsNumDiff] [bigint] NULL,
	[readsBytesDiff] [bigint] NULL,
	[readsIOStallDiff] [bigint] NULL,
	[writesNumDiff] [bigint] NULL,
	[writesBytesDiff] [bigint] NULL,
	[writesIOStallDiff] [bigint] NULL,
	[ioStallDiff] [bigint] NULL
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO

USE DBA_Archive
GO 
CREATE PROCEDURE sp__capture_filestats
AS
BEGIN
CREATE TABLE #filestats 
    (dbname  VARCHAR(128), 
    fName  VARCHAR(2048),  
    timeStart  datetime, 
    timeEnd datetime, 
    timeDiff bigint, 
    readsNum1 bigint, 
    readsNum2 bigint, 
    readsBytes1 bigint, 
    readsBytes2 bigint, 
    readsIoStall1 bigint, 
    readsIoStall2 bigint, 
    writesNum1 bigint, 
    writesNum2 bigint, 
    writesBytes1 bigint, 
    writesBytes2 bigint, 
    writesIoStall1 bigint, 
    writesIoStall2 bigint, 
    ioStall1 bigint, 
    ioStall2 bigint 
) 

-- insert first segment counters 
INSERT INTO #filestats 
   (dbname, 
   fName,  
   TimeStart, 
   readsNum1, 
   readsBytes1, 
   readsIoStall1,  
   writesNum1, 
   writesBytes1, 
   writesIoStall1,  
   IoStall1 
   ) 
SELECT  
   DB_NAME(a.dbid) AS Database_name, 
   b.filename, 
   GETDATE(), 
   numberReads, 
   BytesRead, 
   IoStallReadMS, 
   NumberWrites, 
   BytesWritten, 
   IoStallWriteMS, 
   IoStallMS 
FROM  
   fn_virtualfilestats(NULL,NULL) a INNER JOIN 
   master..sysaltfiles b ON a.dbid = b.dbid AND a.fileid = b.fileid 
ORDER BY  
   Database_Name 

/*Delay second read */ 
WAITFOR DELAY '000:01:00' 

-- add second segment counters 
UPDATE #filestats  
SET  
   timeEnd = GETDATE(), 
   readsNum2 = a.numberReads, 
   readsBytes2 = a.BytesRead, 
   readsIoStall2 = a.IoStallReadMS , 
   writesNum2 = a.NumberWrites, 
   writesBytes2 = a.BytesWritten, 
   writesIoStall2 = a.IoStallWriteMS, 
   IoStall2 = a.IoStallMS, 
   timeDiff = DATEDIFF(s,timeStart,GETDATE()) 
FROM  
   fn_virtualfilestats(NULL,NULL) a INNER JOIN 
   master..sysaltfiles b ON a.dbid = b.dbid AND a.fileid = b.fileid 
WHERE    
   fName= b.filename AND dbname=DB_NAME(a.dbid) 

-- select data 
INSERT hist_filestats(dbname,fName,timeStart,timeEnd,readsNum, readsBytes, readsIoStall,writesNum,writesBytes,writesIoStall,ioStall,
timeDiff,readsNumDiff,readsBytesDiff,readsIOStallDiff,writesNumDiff,writesBytesDiff,writesIOStallDiff,ioStallDiff)
SELECT  
   dbname, 
   fName, 
   timeStart,
   timeEnd,
   readsNum1, 
   readsBytes1, 
   readsIoStall1,  
   writesNum1, 
   writesBytes1, 
   writesIoStall1,  
   IoStall1,
   timeDiff, 
   readsNum2 - readsNum1 AS readsNumDiff, 
   readsBytes2 - readsBytes1 AS readsBytesDiff, 
   readsIoStall2 - readsIOStall1 AS readsIOStallDiff, 
   writesNum2 - writesNum1 AS writesNumDiff, 
   writesBytes2 - writesBytes1 AS writesBytesDiff, 
   writesIoStall2 - writesIOStall1 AS writesIOStallDiff,    
   ioStall2 - ioStall1 AS ioStallDiff 
FROM #filestats  
DROP TABLE #filestats
END
GO


USE [msdb]
GO

/****** Object:  Job [Sample_counters]    Script Date: 02/20/2014 01:14:46 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 02/20/2014 01:14:46 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Sample_counters', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Sample Performance counters]    Script Date: 02/20/2014 01:14:46 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Sample Performance counters', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC DBA_Archive..sp__sample_performance_counters
GO', 
		@database_name=N'DBA_Archive', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Sample wait statistics]    Script Date: 02/20/2014 01:14:46 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Sample wait statistics', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC DBA_Archive..sp__sample_wait_statistics
go', 
		@database_name=N'DBA_Archive', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Sample filestats]    Script Date: 02/20/2014 01:14:46 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Sample filestats', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC DBA_Archive..sp__capture_filestats
GO', 
		@database_name=N'DBA_Archive', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every 4 hours', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=4, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20140220, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'11682648-3309-4acc-a59f-bfd17c6d4b48'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO





/* Session to capture the following events
	- PLE less than 12000 seconds
	- SQL statement execution taking more than 10 seconds
	- DEADLOCK events
	- all the errors reported on the server
	- usage of any deprecated features
*/

IF (@@VERSION like 'Microsoft SQL Server 2008 R2%')
BEGIN
IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='Server_Monitor')
    DROP EVENT SESSION [Server_Monitor] ON SERVER;
CREATE EVENT SESSION [Server_Monitor]
ON SERVER
ADD EVENT sqlserver.xml_deadlock_report(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, package0.collect_system_time, sqlserver.database_id, sqlserver.transaction_id, sqlserver.tsql_stack, sqlserver.username)),
ADD EVENT sqlserver.error_reported(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.client_pid, sqlserver.database_id, sqlserver.nt_username, sqlserver.session_id, sqlserver.tsql_stack, sqlserver.username)),
ADD EVENT sqlserver.deprecation_announcement(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_id, sqlserver.session_id, sqlserver.tsql_stack)),
ADD EVENT sqlserver.deprecation_final_support(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_id, sqlserver.session_id, sqlserver.tsql_stack, sqlserver.username)),
ADD EVENT sqlos.wait_info(
     ACTION (package0.callstack, sqlserver.session_id, sqlserver.sql_text)
     WHERE (([duration]>(15000) AND ([wait_type]>(31) AND ([wait_type]>(47) AND [wait_type]<(54) OR [wait_type]<(38) OR [wait_type]>(63) AND [wait_type]<(70) OR [wait_type]>(96) AND [wait_type]<(100) OR [wait_type]=(107) OR [wait_type]=(113) OR [wait_type]>(174) AND [wait_type]<(179) OR [wait_type]=(186) OR [wait_type]=(207) OR [wait_type]=(269) OR [wait_type]=(283) OR [wait_type]=(284)) OR [duration]>(30000) AND [wait_type]<(22))))),
ADD EVENT sqlos.wait_info_external(
     ACTION (package0.callstack, sqlserver.session_id, sqlserver.sql_text)
     WHERE (([duration]>(5000) AND ([wait_type]>(365) AND [wait_type]<(372) OR [wait_type]>(372) AND [wait_type]<(377) OR [wait_type]>(377) AND [wait_type]<(383) OR [wait_type]>(420) AND [wait_type]<(424) OR [wait_type]>(426) AND [wait_type]<(432) OR [wait_type]>(432) AND [wait_type]<(435) OR [duration]>(45000) AND ([wait_type]>(382) AND [wait_type]<(386) OR [wait_type]>(423) AND [wait_type]<(427) OR [wait_type]>(434) AND [wait_type]<(437) OR [wait_type]>(442) AND [wait_type]<(451) OR [wait_type]>(451) AND [wait_type]<(473) OR [wait_type]>(484) AND [wait_type]<(499) OR [wait_type]=(365) OR [wait_type]=(372) OR [wait_type]=(377) OR [wait_type]=(387) OR [wait_type]=(432) OR [wait_type]=(502)))))),
ADD EVENT sqlserver.buffer_manager_page_life_expectancy(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_context, sqlserver.database_id, sqlserver.tsql_stack, sqlserver.username)
     WHERE (([count]<(6000)))),
ADD EVENT sqlserver.sp_statement_completed(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_id, sqlserver.nt_username, sqlserver.sql_text, sqlserver.tsql_stack, sqlserver.username)
     WHERE (([duration]>(10)))),
ADD EVENT sqlserver.sql_statement_completed(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_id, sqlserver.sql_text, sqlserver.tsql_stack, sqlserver.username)
     WHERE (([duration]>(10)))),
ADD EVENT sqlserver.rpc_completed(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_id, sqlserver.sql_text, sqlserver.tsql_stack, sqlserver.username)
     WHERE (([duration]>(5000))))
ADD TARGET package0.ring_buffer
WITH (MAX_MEMORY = 4096KB, EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY = 30 SECONDS, MAX_EVENT_SIZE = 0KB, MEMORY_PARTITION_MODE = NONE, TRACK_CAUSALITY = OFF, STARTUP_STATE = ON)
END
ELSE
BEGIN
IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='Server_Monitor')
    DROP EVENT SESSION [Server_Monitor] ON SERVER;
CREATE EVENT SESSION [Server_Monitor]
ON SERVER
ADD EVENT sqlserver.xml_deadlock_report(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, package0.collect_system_time, sqlserver.database_id, sqlserver.transaction_id, sqlserver.tsql_stack, sqlserver.username)),
ADD EVENT sqlserver.error_reported(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.client_pid, sqlserver.database_id, sqlserver.nt_username, sqlserver.session_id, sqlserver.tsql_stack, sqlserver.username)),
ADD EVENT sqlserver.deprecation_announcement(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_id, sqlserver.session_id, sqlserver.tsql_stack)),
ADD EVENT sqlserver.deprecation_final_support(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_id, sqlserver.session_id, sqlserver.tsql_stack, sqlserver.username)),
ADD EVENT sqlos.wait_info(
     ACTION (package0.callstack, sqlserver.session_id, sqlserver.sql_text)
     WHERE (([duration]>(15000) AND ([wait_type]>(31) AND ([wait_type]>(47) AND [wait_type]<(54) OR [wait_type]<(38) OR [wait_type]>(63) AND [wait_type]<(70) OR [wait_type]>(96) AND [wait_type]<(100) OR [wait_type]=(107) OR [wait_type]=(113) OR [wait_type]>(174) AND [wait_type]<(179) OR [wait_type]=(186) OR [wait_type]=(207) OR [wait_type]=(269) OR [wait_type]=(283) OR [wait_type]=(284)) OR [duration]>(30000) AND [wait_type]<(22))))),
ADD EVENT sqlos.wait_info_external(
     ACTION (package0.callstack, sqlserver.session_id, sqlserver.sql_text)
     WHERE (([duration]>(5000) AND ([wait_type]>(365) AND [wait_type]<(372) OR [wait_type]>(372) AND [wait_type]<(377) OR [wait_type]>(377) AND [wait_type]<(383) OR [wait_type]>(420) AND [wait_type]<(424) OR [wait_type]>(426) AND [wait_type]<(432) OR [wait_type]>(432) AND [wait_type]<(435) OR [duration]>(45000) AND ([wait_type]>(382) AND [wait_type]<(386) OR [wait_type]>(423) AND [wait_type]<(427) OR [wait_type]>(434) AND [wait_type]<(437) OR [wait_type]>(442) AND [wait_type]<(451) OR [wait_type]>(451) AND [wait_type]<(473) OR [wait_type]>(484) AND [wait_type]<(499) OR [wait_type]=(365) OR [wait_type]=(372) OR [wait_type]=(377) OR [wait_type]=(387) OR [wait_type]=(432) OR [wait_type]=(502)))))),
ADD EVENT sqlserver.buffer_manager_page_life_expectancy(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_name, sqlserver.database_id, sqlserver.tsql_stack, sqlserver.username)
     WHERE (([count]<(6000)))),
ADD EVENT sqlserver.sp_statement_completed(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_id, sqlserver.nt_username, sqlserver.sql_text, sqlserver.tsql_stack, sqlserver.username)
     WHERE (([duration]>(10)))),
ADD EVENT sqlserver.sql_statement_completed(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_id, sqlserver.sql_text, sqlserver.tsql_stack, sqlserver.username)
     WHERE (([duration]>(10)))),
ADD EVENT sqlserver.rpc_completed(
     ACTION (sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.database_id, sqlserver.sql_text, sqlserver.tsql_stack, sqlserver.username)
     WHERE (([duration]>(5000))))
ADD TARGET package0.ring_buffer
WITH (MAX_MEMORY = 4096KB, EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY = 30 SECONDS, MAX_EVENT_SIZE = 0KB, MEMORY_PARTITION_MODE = NONE, TRACK_CAUSALITY = OFF, STARTUP_STATE = ON)
END
GO
ALTER EVENT SESSION [Server_Monitor] ON SERVER STATE = START
GO


USE [DBA_Archive]
GO

/****** Object:  Table [dbo].[hist_server_events]    Script Date: 02/20/2014 01:57:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[hist_server_events](
	[event_name] [varchar](400) NULL,
	[event_timestamp] [datetime] NULL,
	[unique_event_id] [bigint] NULL,
	[buffer_manager_page_life_expectancy.client_app_name] [varchar](max) NULL,
	[buffer_manager_page_life_expectancy.client_hostname] [varchar](max) NULL,
	[buffer_manager_page_life_expectancy.count] [decimal](28, 0) NULL,
	[buffer_manager_page_life_expectancy.database_context] [varchar](max) NULL,
	[buffer_manager_page_life_expectancy.database_id] [varchar](max) NULL,
	[buffer_manager_page_life_expectancy.tsql_stack] [xml] NULL,
	[buffer_manager_page_life_expectancy.username] [varchar](max) NULL,
	[deprecation_announcement.client_app_name] [varchar](max) NULL,
	[deprecation_announcement.client_hostname] [varchar](max) NULL,
	[deprecation_announcement.database_id] [varchar](max) NULL,
	[deprecation_announcement.feature] [varchar](max) NULL,
	[deprecation_announcement.message] [varchar](max) NULL,
	[deprecation_announcement.session_id] [varchar](max) NULL,
	[deprecation_announcement.tsql_stack] [xml] NULL,
	[deprecation_final_support.client_app_name] [varchar](max) NULL,
	[deprecation_final_support.client_hostname] [varchar](max) NULL,
	[deprecation_final_support.database_id] [varchar](max) NULL,
	[deprecation_final_support.feature] [varchar](max) NULL,
	[deprecation_final_support.message] [varchar](max) NULL,
	[deprecation_final_support.session_id] [varchar](max) NULL,
	[deprecation_final_support.tsql_stack] [xml] NULL,
	[deprecation_final_support.username] [varchar](max) NULL,
	[error_reported.client_app_name] [varchar](max) NULL,
	[error_reported.client_hostname] [varchar](max) NULL,
	[error_reported.client_pid] [varchar](max) NULL,
	[error_reported.database_id] [varchar](max) NULL,
	[error_reported.error] [int] NULL,
	[error_reported.message] [varchar](max) NULL,
	[error_reported.nt_username] [varchar](max) NULL,
	[error_reported.session_id] [varchar](max) NULL,
	[error_reported.severity] [int] NULL,
	[error_reported.state] [int] NULL,
	[error_reported.tsql_stack] [xml] NULL,
	[error_reported.user_defined] [varchar](max) NULL,
	[error_reported.username] [varchar](max) NULL,
	[page_split.client_app_name] [varchar](max) NULL,
	[page_split.client_hostname] [varchar](max) NULL,
	[page_split.database_context] [varchar](max) NULL,
	[page_split.database_id] [varchar](max) NULL,
	[page_split.file_id] [int] NULL,
	[page_split.is_system] [varchar](max) NULL,
	[page_split.page_id] [bigint] NULL,
	[page_split.plan_handle] [varchar](max) NULL,
	[page_split.session_id] [varchar](max) NULL,
	[page_split.session_nt_username] [varchar](max) NULL,
	[page_split.tsql_stack] [xml] NULL,
	[page_split.username] [varchar](max) NULL,
	[sql_statement_completed.client_app_name] [varchar](max) NULL,
	[sql_statement_completed.client_hostname] [varchar](max) NULL,
	[sql_statement_completed.cpu] [bigint] NULL,
	[sql_statement_completed.database_id] [varchar](max) NULL,
	[sql_statement_completed.duration] [bigint] NULL,
	[sql_statement_completed.object_id] [bigint] NULL,
	[sql_statement_completed.object_type] [int] NULL,
	[sql_statement_completed.reads] [decimal](28, 0) NULL,
	[sql_statement_completed.source_database_id] [int] NULL,
	[sql_statement_completed.sql_text] [varchar](max) NULL,
	[sql_statement_completed.tsql_stack] [xml] NULL,
	[sql_statement_completed.username] [varchar](max) NULL,
	[sql_statement_completed.writes] [decimal](28, 0) NULL,
	[wait_info.callstack] [varchar](max) NULL,
	[wait_info.completed_count] [decimal](28, 0) NULL,
	[wait_info.duration] [decimal](28, 0) NULL,
	[wait_info.max_duration] [decimal](28, 0) NULL,
	[wait_info.opcode] [varchar](max) NULL,
	[wait_info.session_id] [varchar](max) NULL,
	[wait_info.signal_duration] [decimal](28, 0) NULL,
	[wait_info.sql_text] [varchar](max) NULL,
	[wait_info.total_duration] [decimal](28, 0) NULL,
	[wait_info.wait_type] [varchar](max) NULL,
	[wait_info_external.callstack] [varchar](max) NULL,
	[wait_info_external.completed_count] [decimal](28, 0) NULL,
	[wait_info_external.duration] [decimal](28, 0) NULL,
	[wait_info_external.max_duration] [decimal](28, 0) NULL,
	[wait_info_external.opcode] [varchar](max) NULL,
	[wait_info_external.session_id] [varchar](max) NULL,
	[wait_info_external.sql_text] [varchar](max) NULL,
	[wait_info_external.total_duration] [decimal](28, 0) NULL,
	[wait_info_external.wait_type] [varchar](max) NULL,
	[xml_deadlock_report.client_app_name] [varchar](max) NULL,
	[xml_deadlock_report.client_hostname] [varchar](max) NULL,
	[xml_deadlock_report.collect_system_time] [varchar](max) NULL,
	[xml_deadlock_report.database_id] [varchar](max) NULL,
	[xml_deadlock_report.transaction_id] [varchar](max) NULL,
	[xml_deadlock_report.tsql_stack] [xml] NULL,
	[xml_deadlock_report.username] [varchar](max) NULL,
	[xml_deadlock_report.xml_report] [varchar](max) NULL
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO


USE [msdb]
GO

/****** Object:  Job [Sample_ring_buffer_data]    Script Date: 06/05/2014 02:06:30 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 06/05/2014 02:06:30 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Sample_ring_buffer_data', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Sample]    Script Date: 06/05/2014 02:06:30 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Sample', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=2, 
		@on_fail_action=4, 
		@on_fail_step_id=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET NUMERIC_ROUNDABORT OFF
SET QUOTED_IDENTIFIER ON
/* SQL to read Server_Monitor session data from ring buffer*/
DECLARE @session_name VARCHAR(200) = ''Server_Monitor''
DECLARE @timestamp datetime = DATEADD(MI,-15,getdate()) --- Default would be to capture the events in the last 15 minutes
/* If the hist_server_events table already has events the next query would pick the time of the last event */
IF (( select MAX(event_timestamp) from DBA_Archive..hist_server_events) IS NOT NULL)
   Select @timestamp = MAX(event_timestamp) from DBA_Archive..hist_server_events

INSERT INTO [DBA_Archive].[dbo].[hist_server_events]
           ([event_name]
           ,[event_timestamp]
           ,[unique_event_id]
           ,[buffer_manager_page_life_expectancy.client_app_name]
           ,[buffer_manager_page_life_expectancy.client_hostname]
           ,[buffer_manager_page_life_expectancy.count]
           ,[buffer_manager_page_life_expectancy.database_context]
           ,[buffer_manager_page_life_expectancy.database_id]
           ,[buffer_manager_page_life_expectancy.tsql_stack]
           ,[buffer_manager_page_life_expectancy.username]
           ,[deprecation_announcement.client_app_name]
           ,[deprecation_announcement.client_hostname]
           ,[deprecation_announcement.database_id]
           ,[deprecation_announcement.feature]
           ,[deprecation_announcement.message]
           ,[deprecation_announcement.session_id]
           ,[deprecation_announcement.tsql_stack]
           ,[deprecation_final_support.client_app_name]
           ,[deprecation_final_support.client_hostname]
           ,[deprecation_final_support.database_id]
           ,[deprecation_final_support.feature]
           ,[deprecation_final_support.message]
           ,[deprecation_final_support.session_id]
           ,[deprecation_final_support.tsql_stack]
           ,[deprecation_final_support.username]
           ,[error_reported.client_app_name]
           ,[error_reported.client_hostname]
           ,[error_reported.client_pid]
           ,[error_reported.database_id]
           ,[error_reported.error]
           ,[error_reported.message]
           ,[error_reported.nt_username]
           ,[error_reported.session_id]
           ,[error_reported.severity]
           ,[error_reported.state]
           ,[error_reported.tsql_stack]
           ,[error_reported.user_defined]
           ,[error_reported.username]
           ,[page_split.client_app_name]
           ,[page_split.client_hostname]
           ,[page_split.database_context]
           ,[page_split.database_id]
           ,[page_split.file_id]
           ,[page_split.is_system]
           ,[page_split.page_id]
           ,[page_split.plan_handle]
           ,[page_split.session_id]
           ,[page_split.session_nt_username]
           ,[page_split.tsql_stack]
           ,[page_split.username]
           ,[sql_statement_completed.client_app_name]
           ,[sql_statement_completed.client_hostname]
           ,[sql_statement_completed.cpu]
           ,[sql_statement_completed.database_id]
           ,[sql_statement_completed.duration]
           ,[sql_statement_completed.object_id]
           ,[sql_statement_completed.object_type]
           ,[sql_statement_completed.reads]
           ,[sql_statement_completed.source_database_id]
           ,[sql_statement_completed.sql_text]
           ,[sql_statement_completed.tsql_stack]
           ,[sql_statement_completed.username]
           ,[sql_statement_completed.writes]
           ,[wait_info.callstack]
           ,[wait_info.completed_count]
           ,[wait_info.duration]
           ,[wait_info.max_duration]
           ,[wait_info.opcode]
           ,[wait_info.session_id]
           ,[wait_info.signal_duration]
           ,[wait_info.sql_text]
           ,[wait_info.total_duration]
           ,[wait_info.wait_type]
           ,[wait_info_external.callstack]
           ,[wait_info_external.completed_count]
           ,[wait_info_external.duration]
           ,[wait_info_external.max_duration]
           ,[wait_info_external.opcode]
           ,[wait_info_external.session_id]
           ,[wait_info_external.sql_text]
           ,[wait_info_external.total_duration]
           ,[wait_info_external.wait_type]
           ,[xml_deadlock_report.client_app_name]
           ,[xml_deadlock_report.client_hostname]
           ,[xml_deadlock_report.collect_system_time]
           ,[xml_deadlock_report.database_id]
           ,[xml_deadlock_report.transaction_id]
           ,[xml_deadlock_report.tsql_stack]
           ,[xml_deadlock_report.username]
           ,[xml_deadlock_report.xml_report])
 SELECT 
	pivoted_data.* 
FROM 
( 
	SELECT 
		MIN(event_name) as event_name, 
		MIN(event_timestamp) as event_timestamp, 
		unique_event_id, 
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''buffer_manager_page_life_expectancy'' and 
						d_name = ''client_app_name'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [buffer_manager_page_life_expectancy.client_app_name],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''buffer_manager_page_life_expectancy'' and 
						d_name = ''client_hostname'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [buffer_manager_page_life_expectancy.client_hostname],
		CONVERT 
		( 
			DECIMAL(28,0), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''buffer_manager_page_life_expectancy'' and 
						d_name = ''count'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [buffer_manager_page_life_expectancy.count],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''buffer_manager_page_life_expectancy'' and 
						d_name = ''database_context'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [buffer_manager_page_life_expectancy.database_context],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''buffer_manager_page_life_expectancy'' and 
						d_name = ''database_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [buffer_manager_page_life_expectancy.database_id],
		CONVERT 
		( 
			XML, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''buffer_manager_page_life_expectancy'' and 
						d_name = ''tsql_stack'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [buffer_manager_page_life_expectancy.tsql_stack],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''buffer_manager_page_life_expectancy'' and 
						d_name = ''username'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [buffer_manager_page_life_expectancy.username],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_announcement'' and 
						d_name = ''client_app_name'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_announcement.client_app_name],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_announcement'' and 
						d_name = ''client_hostname'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_announcement.client_hostname],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_announcement'' and 
						d_name = ''database_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_announcement.database_id],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_announcement'' and 
						d_name = ''feature'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_announcement.feature],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_announcement'' and 
						d_name = ''message'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_announcement.message],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_announcement'' and 
						d_name = ''session_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_announcement.session_id],
		CONVERT 
		( 
			XML, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_announcement'' and 
						d_name = ''tsql_stack'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_announcement.tsql_stack],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_final_support'' and 
						d_name = ''client_app_name'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_final_support.client_app_name],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_final_support'' and 
						d_name = ''client_hostname'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_final_support.client_hostname],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_final_support'' and 
						d_name = ''database_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_final_support.database_id],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_final_support'' and 
						d_name = ''feature'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_final_support.feature],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_final_support'' and 
						d_name = ''message'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_final_support.message],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_final_support'' and 
						d_name = ''session_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_final_support.session_id],
		CONVERT 
		( 
			XML, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_final_support'' and 
						d_name = ''tsql_stack'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_final_support.tsql_stack],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''deprecation_final_support'' and 
						d_name = ''username'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [deprecation_final_support.username],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''client_app_name'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.client_app_name],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''client_hostname'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.client_hostname],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''client_pid'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.client_pid],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''database_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.database_id],
		CONVERT 
		( 
			INT, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''error'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.error],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''message'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.message],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''nt_username'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.nt_username],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''session_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.session_id],
		CONVERT 
		( 
			INT, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''severity'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.severity],
		CONVERT 
		( 
			INT, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''state'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.state],
		CONVERT 
		( 
			XML, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''tsql_stack'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.tsql_stack],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''user_defined'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.user_defined],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''error_reported'' and 
						d_name = ''username'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [error_reported.username],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''page_split'' and 
						d_name = ''client_app_name'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [page_split.client_app_name],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''page_split'' and 
						d_name = ''client_hostname'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [page_split.client_hostname],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''page_split'' and 
						d_name = ''database_context'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [page_split.database_context],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''page_split'' and 
						d_name = ''database_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [page_split.database_id],
		CONVERT 
		( 
			INT, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''page_split'' and 
						d_name = ''file_id'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [page_split.file_id],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''page_split'' and 
						d_name = ''is_system'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [page_split.is_system],
		CONVERT 
		( 
			BIGINT, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''page_split'' and 
						d_name = ''page_id'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [page_split.page_id],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''page_split'' and 
						d_name = ''plan_handle'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [page_split.plan_handle],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''page_split'' and 
						d_name = ''session_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [page_split.session_id],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''page_split'' and 
						d_name = ''session_nt_username'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [page_split.session_nt_username],
		CONVERT 
		( 
			XML, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''page_split'' and 
						d_name = ''tsql_stack'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [page_split.tsql_stack],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''page_split'' and 
						d_name = ''username'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [page_split.username],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''client_app_name'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.client_app_name],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''client_hostname'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.client_hostname],
		CONVERT 
		( 
			BIGINT, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''cpu'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.cpu],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''database_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.database_id],
		CONVERT 
		( 
			BIGINT, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''duration'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.duration],
		CONVERT 
		( 
			BIGINT, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''object_id'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.object_id],
		CONVERT 
		( 
			INT, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''object_type'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.object_type],
		CONVERT 
		( 
			DECIMAL(28,0), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''reads'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.reads],
		CONVERT 
		( 
			INT, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''source_database_id'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.source_database_id],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''sql_text'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.sql_text],
		CONVERT 
		( 
			XML, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''tsql_stack'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.tsql_stack],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''username'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.username],
		CONVERT 
		( 
			DECIMAL(28,0), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''sql_statement_completed'' and 
						d_name = ''writes'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [sql_statement_completed.writes],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info'' and 
						d_name = ''callstack'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info.callstack],
		CONVERT 
		( 
			DECIMAL(28,0), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info'' and 
						d_name = ''completed_count'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info.completed_count],
		CONVERT 
		( 
			DECIMAL(28,0), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info'' and 
						d_name = ''duration'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info.duration],
		CONVERT 
		( 
			DECIMAL(28,0), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info'' and 
						d_name = ''max_duration'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info.max_duration],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info'' and 
						d_name = ''opcode'' and 
						d_package IS NULL 
							THEN d_text
				END 
			) 
		) AS [wait_info.opcode],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info'' and 
						d_name = ''session_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info.session_id],
		CONVERT 
		( 
			DECIMAL(28,0), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info'' and 
						d_name = ''signal_duration'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info.signal_duration],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info'' and 
						d_name = ''sql_text'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info.sql_text],
		CONVERT 
		( 
			DECIMAL(28,0), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info'' and 
						d_name = ''total_duration'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info.total_duration],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info'' and 
						d_name = ''wait_type'' and 
						d_package IS NULL 
							THEN d_text
				END 
			) 
		) AS [wait_info.wait_type],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info_external'' and 
						d_name = ''callstack'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info_external.callstack],
		CONVERT 
		( 
			DECIMAL(28,0), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info_external'' and 
						d_name = ''completed_count'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info_external.completed_count],
		CONVERT 
		( 
			DECIMAL(28,0), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info_external'' and 
						d_name = ''duration'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info_external.duration],
		CONVERT 
		( 
			DECIMAL(28,0), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info_external'' and 
						d_name = ''max_duration'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info_external.max_duration],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info_external'' and 
						d_name = ''opcode'' and 
						d_package IS NULL 
							THEN d_text
				END 
			) 
		) AS [wait_info_external.opcode],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info_external'' and 
						d_name = ''session_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info_external.session_id],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info_external'' and 
						d_name = ''sql_text'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info_external.sql_text],
		CONVERT 
		( 
			DECIMAL(28,0), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info_external'' and 
						d_name = ''total_duration'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [wait_info_external.total_duration],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''wait_info_external'' and 
						d_name = ''wait_type'' and 
						d_package IS NULL 
							THEN d_text
				END 
			) 
		) AS [wait_info_external.wait_type],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''xml_deadlock_report'' and 
						d_name = ''client_app_name'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [xml_deadlock_report.client_app_name],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''xml_deadlock_report'' and 
						d_name = ''client_hostname'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [xml_deadlock_report.client_hostname],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''xml_deadlock_report'' and 
						d_name = ''collect_system_time'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [xml_deadlock_report.collect_system_time],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''xml_deadlock_report'' and 
						d_name = ''database_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [xml_deadlock_report.database_id],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''xml_deadlock_report'' and 
						d_name = ''transaction_id'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [xml_deadlock_report.transaction_id],
		CONVERT 
		( 
			XML, 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''xml_deadlock_report'' and 
						d_name = ''tsql_stack'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [xml_deadlock_report.tsql_stack],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''xml_deadlock_report'' and 
						d_name = ''username'' and 
						d_package IS NOT NULL 
							THEN d_value
				END 
			) 
		) AS [xml_deadlock_report.username],
		CONVERT 
		( 
			VARCHAR(MAX), 
			MIN 
			( 
				CASE 
					WHEN 
						event_name = ''xml_deadlock_report'' and 
						d_name = ''xml_report'' and 
						d_package IS NULL 
							THEN d_value
				END 
			) 
		) AS [xml_deadlock_report.xml_report]
	FROM 
	( 
		SELECT 
			*, 
			CONVERT(VARCHAR(400), NULL) AS attach_activity_id 
		FROM 
		( 
			SELECT 
				event.value(''(@name)[1]'', ''VARCHAR(400)'') as event_name, 
				event.value(''(@timestamp)[1]'', ''DATETIME'') as event_timestamp, 
				DENSE_RANK() OVER (ORDER BY event) AS unique_event_id, 
				n.value(''(@name)[1]'', ''VARCHAR(400)'') AS d_name, 
				n.value(''(@package)[1]'', ''VARCHAR(400)'') AS d_package, 
				n.value(''((value)[1]/text())[1]'', ''VARCHAR(MAX)'') AS d_value, 
				n.value(''((text)[1]/text())[1]'', ''VARCHAR(MAX)'') AS d_text 
			FROM 
			( 
				SELECT 
					( 
						SELECT 
							CONVERT(xml, target_data) 
						FROM sys.dm_xe_session_targets st 
						JOIN sys.dm_xe_sessions s ON 
							s.address = st.event_session_address 
						WHERE 
							s.name = @session_name 
							AND st.target_name = ''ring_buffer'' 
					) AS [x] 
				FOR XML PATH(''''), TYPE 
			) AS the_xml(x) 
			CROSS APPLY x.nodes(''//event'') e (event) 
			CROSS APPLY event.nodes(''*'') AS q (n) 
			where event.value(''(@timestamp)[1]'', ''DATETIME'') > @timestamp
		) AS data_data 
	) AS activity_data 
	GROUP BY 
		unique_event_id 
) AS pivoted_data; 

', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Sample-2]    Script Date: 06/05/2014 02:06:30 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Sample-2', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET NUMERIC_ROUNDABORT OFF
SET QUOTED_IDENTIFIER ON

DECLARE @session_name VARCHAR(200) = ''Server_Monitor''
DECLARE @timestamp datetime = DATEADD(MI,-15,getdate())

Create Table #T(ID Int Identity(1,1) Primary Key, SessionXML XML)
CREATE PRIMARY XML INDEX IDX_XML ON #T(SessionXML);

Create Table #XML(
		ID Int Identity(1,1) Primary Key, 
		EventTime DATETIME, 
		SessionXML XML,
		EventType nvarchar(128))
CREATE PRIMARY XML INDEX IDX_XML ON #XML(SessionXML);

Create Table #DeadLocks(
		ID Int Identity(1,1) Primary Key, 
		EventTime DATETIME, 
		SessionXML XML,
		XML_Report XML
		)
CREATE PRIMARY XML INDEX IDX_XML ON #DeadLocks(SessionXML);

Insert  #T
SELECT	CAST(target_data AS xml) AS SessionXML
FROM	sys.dm_xe_session_targets st
INNER JOIN 
		sys.dm_xe_sessions s 
ON		s.address = st.event_session_address
WHERE	name = @session_name
		and target_name=''ring_buffer''
		
INSERT	#XML (EventTime,SessionXML, EventType)
SELECT	DATEADD(hh,-5,MyEvent.value(''@timestamp'', ''datetime'')) AS EventTime,
		MyEvent.query(''.'') as SessionXML,
		MyEvent.value(''@name'', ''nvarchar(128)'')
FROM	#T s
CROSS APPLY 
		SessionXML.nodes (''//RingBufferTarget/event'') AS t (MyEvent)


 --- Default would be to capture the events in the last 15 minutes
/* If the hist_server_events table already has events the next query would pick the time of the last event */
IF (( select MAX(EventTime) from DBA_Archive..hist_sql_statement_completed) IS NOT NULL)
   Select @timestamp = MAX(EventTime) from DBA_Archive..hist_sql_statement_completed

INSERT hist_sql_statement_completed
SELECT	EventType,
		EventTime,
		SessionXML,
		DB_Name(SessionXML.value(''(/event/data[@name=''''source_database_id'''']/value)[1]'',''VARCHAR(100)'')) AS source_database,
		SessionXML.value(''(/event/data[@name=''''object_id'''']/value)[1]'',''INT'') AS Obj,
		SessionXML.value(''(/event/data[@name=''''object_type'''']/value)[1]'',''INT'') AS object_type, --http://msdn.microsoft.com/en-us/library/ms180953.aspx
		SessionXML.value(''(/event/data[@name=''''cpu'''']/value)[1]'',''INT'') AS cpu,
		(SessionXML.value(''(/event/data[@name=''''duration'''']/value)[1]'',''BIGINT'')*1.00)/1000000 AS duration,
		CASE WHEN ((SessionXML.value(''(/event/data[@name=''''duration'''']/value)[1]'',''BIGINT'')*1.00)/1000000/60)  < 1 THEN  
			Convert(Varchar,Convert(DECIMAL(18,2),(SessionXML.value(''(/event/data[@name=''''duration'''']/value)[1]'',''BIGINT'')*1.00)/1000000))+'' s'' 
			ELSE 
			Convert(Varchar,Convert(DECIMAL(18,2),((SessionXML.value(''(/event/data[@name=''''duration'''']/value)[1]'',''BIGINT'')*1.00)/1000000/60)))+'' m''
		End
		AS durationMin,
		SessionXML.value(''(/event/data[@name=''''reads'''']/value)[1]'',''INT'') AS reads,
		SessionXML.value(''(/event/data[@name=''''writes'''']/value)[1]'',''INT'') AS writes,
		CONVERT(XML,REPLACE(REPLACE(REPLACE(
					SessionXML.value(''(/event/action[@name=''''sql_text'''']/value)[1]'',''Varchar(max)'') 
				,NCHAR(0),N''''),''&'',''&amp;''),''<'',''&lt;'')) AS StatementText ,
		QP.query_plan
FROM	#XML
OUTER APPLY 
		sys.dm_exec_query_plan(convert(varbinary(max),substring(SessionXML.value(''(/event/action[@name=''''plan_handle'''']/value)[1]'',''nvarchar(max)''),15,50),1)) AS QP
WHERE	EventType=''sql_statement_completed''
AND EventTime > @timestamp
ORDER BY 2 Desc

SELECT @timestamp = DATEADD(MI,-15,getdate())
IF (( select MAX(EventTime) from DBA_Archive..hist_error_reported) IS NOT NULL)
   Select @timestamp = MAX(EventTime) from DBA_Archive..hist_error_reported

INSERT hist_error_reported 
SELECT	EventType,
		EventTime,
		SessionXML,
		SessionXML.value(''(/event/data[@name=''''wait_type'''']/value)[1]'',''INT'') AS wait_type,
		SessionXML.value(''(/event/data[@name=''''severity'''']/value)[1]'',''INT'') AS severity,
		SessionXML.value(''(/event/data[@name=''''state'''']/value)[1]'',''INT'') AS [state],
		SessionXML.value(''(/event/data[@name=''''message'''']/value)[1]'',''Varchar(8000)'') AS [message],
		CONVERT(XML,REPLACE(REPLACE(REPLACE(
					SessionXML.value(''(/event/action[@name=''''sql_text'''']/value)[1]'',''Varchar(max)'') 
				,NCHAR(0),N''''),''&'',''&amp;''),''<'',''&lt;'')) AS StatementText 
FROM	#XML
OUTER APPLY 
		sys.dm_exec_query_plan(convert(varbinary(max),substring(SessionXML.value(''(/event/action[@name=''''plan_handle'''']/value)[1]'',''nvarchar(max)''),15,50),1)) AS QP
WHERE	EventType=''error_reported''
and EventTime > @timestamp
ORDER BY 2 Desc


SELECT @timestamp  = DATEADD(MI,-15,getdate())
IF (( select MAX(EventTime) from DBA_Archive..hist_wait_info) IS NOT NULL)
   Select @timestamp = MAX(EventTime) from DBA_Archive..hist_wait_info
INSERT hist_wait_info
SELECT	EventType,
		EventTime,
		SessionXML,
		SessionXML.value(''(/event/data[@name=''''wait_type'''']/text)[1]'',''Varchar(255)'') AS wait_type,
		SessionXML.value(''(/event/data[@name=''''duration'''']/value)[1]'',''INT'') AS duration,
		SessionXML.value(''(/event/data[@name=''''max_duration'''']/value)[1]'',''INT'') AS max_duration,
		SessionXML.value(''(/event/action[@name=''''session_id'''']/value)[1]'',''INT'') AS session_id,
		CONVERT(XML,REPLACE(REPLACE(REPLACE(
					SessionXML.value(''(/event/action[@name=''''sql_text'''']/value)[1]'',''Varchar(max)'') 
				,NCHAR(0),N''''),''&'',''&amp;''),''<'',''&lt;'')) AS StatementText 
FROM	#XML
WHERE	EventType=''wait_info''
AND EventTime > @timestamp
ORDER BY 2 Desc


SELECT @timestamp  = DATEADD(MI,-15,getdate())
IF (( select MAX(EventTime) from DBA_Archive..hist_deadlocks) IS NOT NULL)
   Select @timestamp = MAX(EventTime) from DBA_Archive..hist_deadlocks
Insert #Deadlocks(
	EventTime, 
	SessionXML, 
	XML_Report)
SELECT	Top 10 	
		EventTime,
		SessionXML,
		Convert(XML,SessionXML.value(''(/event/data[@name=''''xml_report'''']/value)[1]'',''Varchar(max)'')) AS xml_report
FROM	#XML
WHERE	EventType=''xml_deadlock_report''
AND EventTime > @timestamp
ORDER BY 1 Desc

INSERT hist_deadlocks (ID,EventTime,SessionXML,XML_Report,victimProcess,victimProcessQuery)
Select	*,
		XML_Report.value(''(deadlock/victim-list/victimProcess/@id)[1]'',''Varchar(255)'') AS victimProcess ,
		XML_Report.query(''(deadlock/process-list/process[1]/inputbuf)'') AS victimProcessQuery 
from	#Deadlocks A

DROP TABLE #T
DROP TABLE #XML
DROP TABLE #DeadLocks', 
		@database_name=N'DBA_Archive', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every 15 minutes', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20140220, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'475d6628-c8c0-4a49-bf79-9991e8a41bde'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO


USE [msdb]
GO
/****** Object:  Job [Purge DBA_Archive]    Script Date: 11/19/2015 12:47:23 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 11/19/2015 12:47:23 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Purge DBA_Archive', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Batch delete]    Script Date: 11/19/2015 12:47:23 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Batch delete', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'use DBA_Archive
go
DECLARE @r INT;
SET @r = 1;
WHILE @r > 0
BEGIN
  BEGIN TRANSACTION;
   DELETE FROM 
   [dbo].[waitstats]
    WHERE transaction_date < DATEADD (MM,-12,GETDATE())
   SET @r = @@ROWCOUNT;
   COMMIT TRANSACTION;
END
go
CHECKPOINT;
go
DECLARE @r INT;
SET @r = 1;
WHILE @r > 0
BEGIN
  BEGIN TRANSACTION;
   DELETE FROM 
   [dbo].[hist_database_size]
    WHERE transaction_date < DATEADD (MM,-12,GETDATE())
   SET @r = @@ROWCOUNT;
   COMMIT TRANSACTION;
END
go
checkpoint;
go
DECLARE @r INT;
SET @r = 1;
WHILE @r > 0
BEGIN
  BEGIN TRANSACTION;
   DELETE FROM 
   [dbo].[hist_deadlocks]
    WHERE EventTime < DATEADD (MM,-12,GETDATE())
   SET @r = @@ROWCOUNT;
   COMMIT TRANSACTION;
END
go
checkpoint;
go
DECLARE @r INT;
SET @r = 1;
WHILE @r > 0
BEGIN
  BEGIN TRANSACTION;
   DELETE FROM 
   [dbo].[hist_performance_counters]
    WHERE transaction_date < DATEADD (MM,-12,GETDATE())
   SET @r = @@ROWCOUNT;
   COMMIT TRANSACTION;
END
go
checkpoint;
go 
DECLARE @r INT;
SET @r = 1;
WHILE @r > 0
BEGIN
  BEGIN TRANSACTION;
   DELETE FROM 
   [dbo].[hist_error_reported]
    WHERE EventTime < DATEADD (MM,-3,GETDATE())
   SET @r = @@ROWCOUNT;
   COMMIT TRANSACTION;
END
go
checkpoint;
go
DECLARE @r INT;
SET @r = 1;
WHILE @r > 0
BEGIN
  BEGIN TRANSACTION;
   DELETE FROM 
   [dbo].[hist_sql_statement_completed]
    WHERE EventTime < DATEADD (MM,-3,GETDATE())
   SET @r = @@ROWCOUNT;
   COMMIT TRANSACTION;
END
go
checkpoint;
go 
DECLARE @r INT;
SET @r = 1;
WHILE @r > 0
BEGIN
  BEGIN TRANSACTION;
   DELETE FROM 
   [dbo].[hist_wait_info]
    WHERE EventTime < DATEADD (MM,-12,GETDATE())
   SET @r = @@ROWCOUNT;
   COMMIT TRANSACTION;
END
go
checkpoint;
go
DECLARE @r INT;
SET @r = 1;
WHILE @r > 0
BEGIN
  BEGIN TRANSACTION;
   DELETE FROM 
   [dbo].[MasterDDLEvents]
    WHERE EventDate < DATEADD (MM,-3,GETDATE())
   SET @r = @@ROWCOUNT;
   COMMIT TRANSACTION;
END
go
checkpoint;
go
DECLARE @r INT;
SET @r = 1;
WHILE @r > 0
BEGIN
  BEGIN TRANSACTION;
   DELETE FROM 
   [dbo].[_hist_non_default_config_values]
    WHERE transaction_date < DATEADD (MM,-12,GETDATE())
   SET @r = @@ROWCOUNT;
   COMMIT TRANSACTION;
END
go
checkpoint;
go  
DECLARE @r INT;
SET @r = 1;
WHILE @r > 0
BEGIN
  BEGIN TRANSACTION;
   DELETE FROM 
   [dbo].[hist_filestats]
    WHERE timeStart < DATEADD (MM,-3,GETDATE())
   SET @r = @@ROWCOUNT;
   COMMIT TRANSACTION;
END
go
checkpoint;
go 
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Weekends', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20150415, 
		@active_end_date=99991231, 
		@active_start_time=140000, 
		@active_end_time=235959, 
		@schedule_uid=N'3e82c479-1b32-4977-867c-4d95a395f5b8'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO


USE [master]
GO

IF NOT EXISTS (SELECT name from sys.objects where name = 'DDLEvents')
BEGIN 
CREATE TABLE [dbo].[DDLEvents](
	[EventDate] [datetime] NOT NULL default getdate() ,
	[EventType] [nvarchar](64) NULL,
	[EventDDL] [nvarchar](max) NULL,
	[EventXML] [xml] NULL,
	[DatabaseName] [nvarchar](255) NULL,
	[SchemaName] [nvarchar](255) NULL,
	[ObjectName] [nvarchar](255) NULL,
	[HostName] [varchar](64) NULL,
	[IPAddress] [varchar](32) NULL,
	[ProgramName] [nvarchar](255) NULL,
	[LoginName] [nvarchar](255) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO


IF EXISTS (select name from sys.server_triggers where name = 'DDLEvents_trg')
	DROP TRIGGER [DDLEvents_trg] ON ALL SERVER
GO

CREATE TRIGGER [DDLEvents_trg] 
ON ALL SERVER
FOR CREATE_DATABASE,ALTER_DATABASE,DROP_DATABASE,CREATE_LOGIN,ALTER_LOGIN,DROP_LOGIN
AS
BEGIN
    DECLARE @EventData XML 
    select @EventData = EVENTDATA()

    DECLARE
        @ip VARCHAR(32) 
        
        
            SELECT @ip = client_net_address
                FROM sys.dm_exec_connections
                WHERE session_id = @@SPID
        
        
    INSERT DDLEvents
    (
        EventType,
        EventDDL,
        EventXML,
        DatabaseName,
        SchemaName,
        ObjectName,
        HostName,
        IPAddress,
        ProgramName,
        LoginName
    )
    SELECT
        @EventData.value('(/EVENT_INSTANCE/EventType)[1]',   'NVARCHAR(100)'),
        @EventData.value('(/EVENT_INSTANCE/TSQLCommand)[1]', 'NVARCHAR(MAX)'),
        @EventData,
        DB_NAME(),
        @EventData.value('(/EVENT_INSTANCE/SchemaName)[1]',  'NVARCHAR(255)'),
        @EventData.value('(/EVENT_INSTANCE/DatabaseName)[1]',  'NVARCHAR(255)'),
        HOST_NAME(),
        @ip,
        PROGRAM_NAME(),
        SUSER_SNAME()
END
GO

ENABLE TRIGGER [DDLEvents_trg] ON ALL SERVER
GO


USE DBA_Archive
GO


CREATE TABLE dbo.MasterDDLEvents
(
    EventDate    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    EventType    NVARCHAR(64),
    EventDDL     NVARCHAR(MAX),
    EventXML     XML,
    DatabaseName NVARCHAR(255),
    SchemaName   NVARCHAR(255),
    ObjectName   NVARCHAR(255),
    HostName     VARCHAR(64),
    IPAddress    VARCHAR(32),
    ProgramName  NVARCHAR(255),
    LoginName    NVARCHAR(255)
);

USE master;
GO


CREATE TRIGGER DDLTrigger_Master
    ON DATABASE
    FOR DDL_DATABASE_LEVEL_EVENTS
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE
        @EventData XML = EVENTDATA();
 
    DECLARE 
        @ip VARCHAR(32) =
        (
            SELECT client_net_address
                FROM sys.dm_exec_connections
                WHERE session_id = @@SPID
        );
 
    INSERT DBA_Archive.dbo.MasterDDLEvents
    (
        EventType,
        EventDDL,
        EventXML,
        DatabaseName,
        SchemaName,
        ObjectName,
        HostName,
        IPAddress,
        ProgramName,
        LoginName
    )
    SELECT
        @EventData.value('(/EVENT_INSTANCE/EventType)[1]',   'NVARCHAR(100)'), 
        @EventData.value('(/EVENT_INSTANCE/TSQLCommand)[1]', 'NVARCHAR(MAX)'),
        @EventData,
        DB_NAME(),
        @EventData.value('(/EVENT_INSTANCE/SchemaName)[1]',  'NVARCHAR(255)'), 
        @EventData.value('(/EVENT_INSTANCE/ObjectName)[1]',  'NVARCHAR(255)'),
        HOST_NAME(),
        @ip,
        PROGRAM_NAME(),
        SUSER_SNAME();
END
GO


/** Add indexes to DB_Archive tables ****/

USE [DBA_Archive]
GO

/****** Object:  Index [NonClusteredIndex-Transaction_Date_hist_non_default_config_values]    Script Date: 11/19/2015 1:06:35 AM ******/
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-Transaction_Date_hist_non_default_config_values')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-Transaction_Date_hist_non_default_config_values] ON [dbo].[_hist_non_default_config_values]
(
	[transaction_date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


USE [DBA_Archive]
GO

/****** Object:  Index [NonClusteredIndex-Transaction_date_hist_database_size]    Script Date: 11/19/2015 1:06:51 AM ******/
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-Transaction_date_hist_database_size')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-Transaction_date_hist_database_size] ON [dbo].[hist_database_size]
(
	[transaction_date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


USE [DBA_Archive]
GO

/****** Object:  Index [NonClusteredIndex-EventTime_Hist_deadlocks]    Script Date: 11/19/2015 1:07:20 AM ******/
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-EventTime_Hist_deadlocks')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-EventTime_Hist_deadlocks] ON [dbo].[hist_deadlocks]
(
	[EventTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


USE [DBA_Archive]
GO

/****** Object:  Index [NonClusteredIndex-Transaction_date_hist_drive_space]    Script Date: 11/19/2015 1:07:35 AM ******/
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-Transaction_date_hist_drive_space')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-Transaction_date_hist_drive_space] ON [dbo].[hist_drive_space]
(
	[transaction_date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


USE [DBA_Archive]
GO

/****** Object:  Index [NonClusteredIndex-EventTime_Histerror_repored]    Script Date: 11/19/2015 1:07:48 AM ******/
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-EventTime_Histerror_repored')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-EventTime_Histerror_repored] ON [dbo].[hist_error_reported]
(
	[EventTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


USE [DBA_Archive]
GO

/****** Object:  Index [NonClusteredIndex-Timestart_hist_filestats]    Script Date: 11/19/2015 1:07:59 AM ******/
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-Timestart_hist_filestats')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-Timestart_hist_filestats] ON [dbo].[hist_filestats]
(
	[timeStart] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


USE [DBA_Archive]
GO

/****** Object:  Index [NonClusteredIndex-Transaction_date_hist_performance_counters]    Script Date: 11/19/2015 1:08:11 AM ******/
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-Transaction_date_hist_performance_counters')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-Transaction_date_hist_performance_counters] ON [dbo].[hist_performance_counters]
(
	[transaction_date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


USE [DBA_Archive]
GO

/****** Object:  Index [NonClusteredIndex-Event_timestamp_hist_server_events]    Script Date: 11/19/2015 1:08:21 AM ******/
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-Event_timestamp_hist_server_events')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-Event_timestamp_hist_server_events] ON [dbo].[hist_server_events]
(
	[event_timestamp] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


USE [DBA_Archive]
GO

/****** Object:  Index [NonClusteredIndex-EventTime_hist_sql_statement_completed]    Script Date: 11/19/2015 1:08:33 AM ******/
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-EventTime_hist_sql_statement_completed')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-EventTime_hist_sql_statement_completed] ON [dbo].[hist_sql_statement_completed]
(
	[EventTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


USE [DBA_Archive]
GO

/****** Object:  Index [NonClusteredIndex-Event_Time_hist_wait_info]    Script Date: 11/19/2015 1:08:45 AM ******/
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-Event_Time_hist_wait_info')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-Event_Time_hist_wait_info] ON [dbo].[hist_wait_info]
(
	[EventTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


USE [DBA_Archive]
GO

/****** Object:  Index [NonClusteredIndex-EventDate_MasterDDLEvents]    Script Date: 11/19/2015 1:08:58 AM ******/
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-EventDate_MasterDDLEvents')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-EventDate_MasterDDLEvents] ON [dbo].[MasterDDLEvents]
(
	[EventDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


USE [DBA_Archive]
GO

/****** Object:  Index [NonClusteredIndex-transaction_date_waitstats]    Script Date: 11/19/2015 1:09:08 AM ******/
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-transaction_date_waitstats')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-transaction_date_waitstats] ON [dbo].[waitstats]
(
	[transaction_date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


USE [DBA_Archive]

GO
IF NOT EXISTS(SELECT * FROM SYS.INDEXES WHERE NAME='NonClusteredIndex-Timeend_hist_filestats')
CREATE NONCLUSTERED INDEX [NonClusteredIndex-Timeend_hist_filestats] ON [dbo].[hist_filestats]
(
	[timeEnd] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

GO


