--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
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
--------------------------------------------------------------------------------- 

-- Written by Pedro Lopes (Microsoft) 

SET NOCOUNT ON;
DECLARE @UpTime VARCHAR(12), @StartDate DATETIME, @sqlmajorver int, @sqlcmd NVARCHAR(500), @params NVARCHAR(500)
SELECT @sqlmajorver = CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff);

IF @sqlmajorver = 9
BEGIN
	SET @sqlcmd = N'SELECT @StartDateOUT = login_time, @UpTimeOUT = DATEDIFF(mi, login_time, GETDATE()) FROM master..sysprocesses WHERE spid = 1';
END
ELSE
BEGIN
	SET @sqlcmd = N'SELECT @StartDateOUT = sqlserver_start_time, @UpTimeOUT = DATEDIFF(mi,sqlserver_start_time,GETDATE()) FROM sys.dm_os_sys_info';
END

SET @params = N'@StartDateOUT DATETIME OUTPUT, @UpTimeOUT VARCHAR(12) OUTPUT';

EXECUTE sp_executesql @sqlcmd, @params, @StartDateOUT=@StartDate OUTPUT, @UpTimeOUT=@UpTime OUTPUT;

SELECT 'Uptime_Information' AS [Information], GETDATE() AS [Current_Time], @StartDate AS Last_Startup, CONVERT(VARCHAR(4),@UpTime/60/24) + 'd ' + CONVERT(VARCHAR(4),@UpTime/60%24) + 'h ' + CONVERT(VARCHAR(4),@UpTime%60) + 'm' AS Uptime

--SELECT DATEDIFF(hh,'2011-09-08 11:35:00',GETDATE()) AS since_lst_clear 
GO

-- Overall, by total CPU time
SELECT 'Total CPU time' AS Category, qp.query_plan,  
    high_cpu.total_worker_time/1000 AS 'total_CPU_time_ms',
	(high_cpu.total_worker_time / high_cpu.execution_count)/1000 AS 'avg_CPU_time_ms',	
    high_cpu.execution_count,
    high_cpu.plan_generation_num, -- Recompiles
	cp.refcounts, -- Number of cache objects that are referencing this cache object.
    high_cpu.last_elapsed_time/1000 AS 'last_elapsed_time_ms', 
    DB_NAME(q.dbid) AS 'database_name', -- NULL if Ad-Hoc or Prepared statements
    OBJECT_NAME(q.objectid, q.dbid) AS 'object_name', -- NULL if Ad-Hoc or Prepared statements
    high_cpu.creation_time, 
    high_cpu.last_execution_time, 
	cp.cacheobjtype,
    cp.objtype,
    cp.size_in_bytes,
    q.encrypted
FROM (SELECT TOP 25 qs.plan_handle, qs.total_worker_time, qs.creation_time, qs.last_execution_time, qs.execution_count, 
		qs.last_elapsed_time, qs.plan_generation_num, qs.sql_handle, qs.statement_start_offset, qs.statement_end_offset
		FROM sys.dm_exec_query_stats qs 
		ORDER BY qs.total_worker_time DESC) AS high_cpu 
INNER JOIN sys.dm_exec_cached_plans cp ON cp.plan_handle = high_cpu.plan_handle
    CROSS APPLY sys.dm_exec_sql_text(high_cpu.plan_handle) AS q 
    CROSS APPLY sys.dm_exec_query_plan (high_cpu.plan_handle) AS qp
	CROSS APPLY sys.dm_exec_sql_text(high_cpu.sql_handle) AS st
ORDER BY high_cpu.total_worker_time DESC
GO

-- Overall, by average CPU time per exec
SELECT 'CPU time per exec' AS Category, qp.query_plan,  
    high_cpu.total_worker_time/1000 AS 'total_CPU_time_ms',
	(high_cpu.total_worker_time / high_cpu.execution_count)/1000 AS 'avg_CPU_time_ms',	
    high_cpu.execution_count,
    high_cpu.plan_generation_num, -- Recompiles
	cp.refcounts, -- Number of cache objects that are referencing this cache object.
    high_cpu.last_elapsed_time/1000 AS 'last_elapsed_time_ms', 
    DB_NAME(q.dbid) AS 'database_name', -- NULL if Ad-Hoc or Prepared statements
    OBJECT_NAME(q.objectid, q.dbid) AS 'object_name', -- NULL if Ad-Hoc or Prepared statements
    high_cpu.creation_time, 
    high_cpu.last_execution_time,
	cp.cacheobjtype,
    cp.objtype,
    cp.size_in_bytes,
    q.encrypted
FROM (SELECT TOP 25 qs.plan_handle, qs.total_worker_time, qs.creation_time, qs.last_execution_time, qs.execution_count, 
		qs.last_elapsed_time, qs.plan_generation_num, qs.sql_handle, qs.statement_start_offset, qs.statement_end_offset
		FROM sys.dm_exec_query_stats qs 
		ORDER BY qs.total_worker_time DESC) AS high_cpu 
INNER JOIN sys.dm_exec_cached_plans cp ON cp.plan_handle = high_cpu.plan_handle
    CROSS APPLY sys.dm_exec_sql_text(high_cpu.plan_handle) AS q 
    CROSS APPLY sys.dm_exec_query_plan (high_cpu.plan_handle) AS qp
ORDER BY high_cpu.total_worker_time / high_cpu.execution_count DESC
GO

-- Overall, by total read IOs 
SELECT 'Total read IOs' AS Category, qp.query_plan,  
    high_io.total_logical_reads AS 'total_logical_reads',
	high_io.total_logical_reads / high_io.execution_count AS 'avg_logical_reads',	 
    high_io.execution_count,
	high_io.plan_generation_num, -- Recompiles
	cp.refcounts, -- Number of cache objects that are referencing this cache object.
    high_io.last_elapsed_time/1000 AS 'last_elapsed_time_ms', 
    DB_NAME(q.dbid) AS 'database_name', -- NULL if Ad-Hoc or Prepared statements
    OBJECT_NAME(q.objectid, q.dbid) AS 'object_name', -- NULL if Ad-Hoc or Prepared statements
    high_io.creation_time, 
    high_io.last_execution_time,
	cp.cacheobjtype,
    cp.objtype,
    cp.size_in_bytes,
    q.encrypted
FROM (SELECT TOP 25 qs.plan_handle, qs.total_logical_reads, qs.creation_time, qs.last_execution_time, qs.execution_count, 
		qs.last_elapsed_time, qs.plan_generation_num, qs.sql_handle, qs.statement_start_offset, qs.statement_end_offset
		FROM sys.dm_exec_query_stats qs 
		ORDER BY qs.total_logical_reads DESC) AS high_io 
INNER JOIN sys.dm_exec_cached_plans cp ON cp.plan_handle = high_io.plan_handle
    CROSS APPLY sys.dm_exec_sql_text(high_io.plan_handle) AS q 
    CROSS APPLY sys.dm_exec_query_plan (high_io.plan_handle) AS qp
ORDER BY high_io.total_logical_reads DESC
GO

-- Overall, by average read IOs per exec
SELECT 'Average read IOs per exec' AS Category, qp.query_plan,  
    high_io.total_logical_reads AS 'total_logical_reads',
	high_io.total_logical_reads / high_io.execution_count AS 'avg_logical_reads',	 
    high_io.execution_count, 
	high_io.plan_generation_num, -- Recompiles
	cp.refcounts, -- Number of cache objects that are referencing this cache object.
    high_io.last_elapsed_time/1000 AS 'last_elapsed_time_ms', 
    DB_NAME(q.dbid) AS 'database_name', -- NULL if Ad-Hoc or Prepared statements
    OBJECT_NAME(q.objectid, q.dbid) AS 'object_name', -- NULL if Ad-Hoc or Prepared statements
    high_io.creation_time, 
    high_io.last_execution_time,
	cp.cacheobjtype,
    cp.objtype,
    cp.size_in_bytes,
    q.encrypted
FROM (SELECT TOP 25 qs.plan_handle, qs.total_logical_reads, qs.creation_time, qs.last_execution_time, qs.execution_count, 
		qs.last_elapsed_time, qs.plan_generation_num, qs.sql_handle, qs.statement_start_offset, qs.statement_end_offset
		FROM sys.dm_exec_query_stats qs 
		ORDER BY qs.total_logical_reads / qs.execution_count DESC) AS high_io 
INNER JOIN sys.dm_exec_cached_plans cp ON cp.plan_handle = high_io.plan_handle
    CROSS APPLY sys.dm_exec_sql_text(high_io.plan_handle) AS q 
    CROSS APPLY sys.dm_exec_query_plan (high_io.plan_handle) AS qp
ORDER BY high_io.total_logical_reads / high_io.execution_count DESC
GO

-- Overall, by total recompiles
SELECT 'Total recompiles' AS Category, qp.query_plan,  
    recompiles.total_logical_reads AS 'total_logical_reads',
	recompiles.total_logical_reads / recompiles.execution_count AS 'avg_logical_reads',	 
    recompiles.execution_count,
	recompiles.plan_generation_num, -- Recompiles
	cp.refcounts, -- Number of cache objects that are referencing this cache object.
    recompiles.last_elapsed_time/1000 AS 'last_elapsed_time_ms', 
    DB_NAME(q.dbid) AS 'database_name', -- NULL if Ad-Hoc or Prepared statements
    OBJECT_NAME(q.objectid, q.dbid) AS 'object_name', -- NULL if Ad-Hoc or Prepared statements
    recompiles.creation_time, 
    recompiles.last_execution_time,
	cp.cacheobjtype,
    cp.objtype,
    cp.size_in_bytes,
    q.encrypted
FROM (SELECT TOP 25 qs.plan_handle, qs.total_logical_reads, qs.creation_time, qs.last_execution_time, qs.execution_count, 
		qs.last_elapsed_time, qs.plan_generation_num, qs.sql_handle, qs.statement_start_offset, qs.statement_end_offset
		FROM sys.dm_exec_query_stats qs 
		ORDER BY qs.plan_generation_num DESC) AS recompiles 
INNER JOIN sys.dm_exec_cached_plans cp ON cp.plan_handle = recompiles.plan_handle
    CROSS APPLY sys.dm_exec_sql_text(recompiles.plan_handle) AS q 
    CROSS APPLY sys.dm_exec_query_plan (recompiles.plan_handle) AS qp
ORDER BY recompiles.plan_generation_num DESC
GO

-- Overall, by average recompiles per exec
SELECT 'Average recompiles per exec' AS Category, qp.query_plan,  
    recompiles.total_logical_reads AS 'total_logical_reads',
	recompiles.total_logical_reads / recompiles.execution_count AS 'avg_logical_reads',	 
    recompiles.execution_count, 
	recompiles.plan_generation_num, -- Recompiles
	cp.refcounts, -- Number of cache objects that are referencing this cache object.
    recompiles.last_elapsed_time/1000 AS 'last_elapsed_time_ms', 
    DB_NAME(q.dbid) AS 'database_name', -- NULL if Ad-Hoc or Prepared statements
    OBJECT_NAME(q.objectid, q.dbid) AS 'object_name', -- NULL if Ad-Hoc or Prepared statements
    recompiles.creation_time, 
    recompiles.last_execution_time,
	cp.cacheobjtype,
    cp.objtype,
    cp.size_in_bytes,
    q.encrypted
FROM (SELECT TOP 25 qs.plan_handle, qs.total_logical_reads, qs.creation_time, qs.last_execution_time, qs.execution_count, 
		qs.last_elapsed_time, qs.plan_generation_num, qs.sql_handle, qs.statement_start_offset, qs.statement_end_offset
		FROM sys.dm_exec_query_stats qs 
		ORDER BY qs.plan_generation_num / qs.execution_count DESC) AS recompiles 
INNER JOIN sys.dm_exec_cached_plans cp ON cp.plan_handle = recompiles.plan_handle
    CROSS APPLY sys.dm_exec_sql_text(recompiles.plan_handle) AS q 
    CROSS APPLY sys.dm_exec_query_plan (recompiles.plan_handle) AS qp
ORDER BY recompiles.plan_generation_num / recompiles.execution_count DESC
GO

-- Overall, most executions
SELECT 'Most executed' AS Category, qp.query_plan,  
    execs.total_logical_reads AS 'total_logical_reads',
	execs.total_logical_reads / execs.execution_count AS 'avg_logical_reads',	 
    execs.execution_count, 
	execs.plan_generation_num, -- execs
	cp.refcounts, -- Number of cache objects that are referencing this cache object.
    execs.last_elapsed_time/1000 AS 'last_elapsed_time_ms', 
    DB_NAME(q.dbid) AS 'database_name', -- NULL if Ad-Hoc or Prepared statements
    OBJECT_NAME(q.objectid, q.dbid) AS 'object_name', -- NULL if Ad-Hoc or Prepared statements
    execs.creation_time, 
    execs.last_execution_time,
	cp.cacheobjtype,
    cp.objtype,
    cp.size_in_bytes,
    q.encrypted
FROM (SELECT TOP 25 qs.plan_handle, qs.total_logical_reads, qs.creation_time, qs.last_execution_time, qs.execution_count, 
		qs.last_elapsed_time, qs.plan_generation_num, qs.sql_handle, qs.statement_start_offset, qs.statement_end_offset
		FROM sys.dm_exec_query_stats qs 
		ORDER BY qs.execution_count DESC) AS execs 
INNER JOIN sys.dm_exec_cached_plans cp ON cp.plan_handle = execs.plan_handle
    CROSS APPLY sys.dm_exec_sql_text(execs.plan_handle) AS q 
    CROSS APPLY sys.dm_exec_query_plan (execs.plan_handle) AS qp
WHERE q.dbid > 4
ORDER BY execs.execution_count DESC
GO