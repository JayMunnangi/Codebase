-- 2011-06-07 Pedro Lopes (Microsoft) pedro.lopes@microsoft.com (http://blogs.msdn.com/b/blogdoezequiel/)
--
-- Latch stats
--
-- 2013-03-05 - Added instantaneous latches vs. historical latches
--
-- 2014-04-04 - Added custom data collection interval duration

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
GO




/* 
References:
http://msdn.microsoft.com/en-us/library/ms175066.aspx
http://www.sqlskills.com/blogs/paul/post/Advanced-performance-troubleshooting-waits-latches-spinlocks.aspx
http://www.sqlskills.com/blogs/paul/most-common-latch-classes-and-what-they-mean
http://blogs.msdn.com/b/psssql/archive/2012/02/23/a-faster-checkdb-part-ii.aspx
*/

DECLARE @duration tinyint, @ErrorMessage VARCHAR(1000), @durationstr NVARCHAR(24)

/*
Set @duration to the number of seconds between data collection points.
Duration must be between 10s and 255s (4m 15s), with a default of 60s.
*/
SET @duration = 60

SELECT @ErrorMessage = 'Starting Latches collection (wait for ' + CONVERT(VARCHAR(3), @duration) + 's)'
RAISERROR (@ErrorMessage, 10, 1) WITH NOWAIT

-- DBCC SQLPERF ('sys.dm_os_latch_stats', CLEAR)

DECLARE @minctr DATETIME, @maxctr DATETIME

IF EXISTS (SELECT [object_id] FROM tempdb.sys.objects (NOLOCK) WHERE [object_id] = OBJECT_ID('tempdb.dbo.#tblLatches'))
DROP TABLE #tblLatches
IF NOT EXISTS (SELECT [object_id] FROM tempdb.sys.objects (NOLOCK) WHERE [object_id] = OBJECT_ID('tempdb.dbo.#tblLatches'))
CREATE TABLE [dbo].[#tblLatches](
	[retrieval_time] [datetime],
	[latch_class] [nvarchar](60) NOT NULL,
	[wait_time_ms] bigint NULL,
	[waiting_requests_count] [bigint] NULL
	);
	
IF EXISTS (SELECT [object_id] FROM tempdb.sys.objects (NOLOCK) WHERE [object_id] = OBJECT_ID('tempdb.dbo.#tblFinalLatches'))
DROP TABLE #tblFinalLatches
IF NOT EXISTS (SELECT [object_id] FROM tempdb.sys.objects (NOLOCK) WHERE [object_id] = OBJECT_ID('tempdb.dbo.#tblFinalLatches'))
CREATE TABLE [dbo].[#tblFinalLatches](
	[latch_class] [nvarchar](60) NOT NULL,
	[wait_time_s] [decimal](16, 6) NULL,
	[waiting_requests_count] [bigint] NULL,
	[pct] [decimal](12, 2) NULL,
	[rn] [bigint] NULL
	);	
	
INSERT INTO #tblLatches
SELECT GETDATE(), latch_class, wait_time_ms, waiting_requests_count
FROM sys.dm_os_latch_stats
WHERE /*latch_class NOT IN ('BUFFER')
	AND*/ wait_time_ms > 0;

IF @duration > 255
SET @duration = 255;

IF @duration < 10
SET @duration = 10;

SELECT @durationstr = 'WAITFOR DELAY ''00:' + CASE WHEN LEN(CONVERT(VARCHAR(3),@duration/60%60)) = 1 
	THEN '0' + CONVERT(VARCHAR(3),@duration/60%60) 
		ELSE CONVERT(VARCHAR(3),@duration/60%60) END 
	+ ':' + CONVERT(VARCHAR(3),@duration-(@duration/60)*60) + ''''
EXECUTE sp_executesql @durationstr;

INSERT INTO #tblLatches
SELECT GETDATE(), latch_class, wait_time_ms, waiting_requests_count
FROM sys.dm_os_latch_stats
WHERE /*latch_class NOT IN ('BUFFER')
	AND*/ wait_time_ms > 0;

SELECT @minctr = MIN([retrieval_time]), @maxctr = MAX([retrieval_time]) FROM #tblLatches;

;WITH cteLatches1 (latch_class,wait_time_ms,waiting_requests_count) AS (SELECT latch_class,wait_time_ms,waiting_requests_count FROM #tblLatches WHERE [retrieval_time] = @minctr),
	cteLatches2 (latch_class,wait_time_ms,waiting_requests_count) AS (SELECT latch_class,wait_time_ms,waiting_requests_count FROM #tblLatches WHERE [retrieval_time] = @maxctr)
INSERT INTO #tblFinalLatches
SELECT DISTINCT t1.latch_class,
		(t2.wait_time_ms-t1.wait_time_ms) / 1000.0 AS wait_time_s,
		(t2.waiting_requests_count-t1.waiting_requests_count) AS waiting_requests_count,
		100.0 * (t2.wait_time_ms-t1.wait_time_ms) / SUM(t2.wait_time_ms-t1.wait_time_ms) OVER() AS pct,
		ROW_NUMBER() OVER(ORDER BY t1.wait_time_ms DESC) AS rn
FROM cteLatches1 t1 INNER JOIN cteLatches2 t2 ON t1.latch_class = t2.latch_class
GROUP BY t1.latch_class, t1.wait_time_ms, t2.wait_time_ms, t1.waiting_requests_count, t2.waiting_requests_count
HAVING (t2.wait_time_ms-t1.wait_time_ms) > 0
ORDER BY wait_time_s DESC;

SELECT 'Latches_last_' + CONVERT(VARCHAR(3), @duration) + 's' AS [Information], W1.latch_class, 
	CAST(W1.wait_time_s AS DECIMAL(14, 2)) AS wait_time_s,
	W1.waiting_requests_count,
	CAST (W1.pct AS DECIMAL(14, 2)) AS pct,
	CAST(SUM(W1.pct) AS DECIMAL(12, 2)) AS overall_running_pct,
	CAST ((W1.wait_time_s / W1.waiting_requests_count) AS DECIMAL (14, 4)) AS avg_wait_s,
	CASE WHEN W1.latch_class LIKE N'ACCESS_METHODS_HOBT_COUNT' 
			OR W1.latch_class LIKE N'ACCESS_METHODS_HOBT_VIRTUAL_ROOT' THEN N'[HoBT - Metadata]'
		WHEN W1.latch_class LIKE N'ACCESS_METHODS_DATASET_PARENT' 
			OR W1.latch_class LIKE N'ACCESS_METHODS_SCAN_RANGE_GENERATOR' 
			OR W1.latch_class LIKE N'NESTING_TRANSACTION_FULL' THEN N'[Parallelism]'
		WHEN W1.latch_class LIKE N'LOG_MANAGER' THEN N'[IO - Log]'
		WHEN W1.latch_class LIKE N'TRACE_CONTROLLER' THEN N'[Trace]'
		WHEN W1.latch_class LIKE N'DBCC_MULTIOBJECT_SCANNER' THEN N'[Parallelism - DBCC CHECK_]'
		WHEN W1.latch_class LIKE N'FGCB_ADD_REMOVE' THEN N'[IO Operations]'
		WHEN W1.latch_class LIKE N'DATABASE_MIRRORING_CONNECTION' THEN N'[Mirroring - Busy]'
		WHEN W1.latch_class LIKE N'BUFFER' THEN N'[Buffer Pool - PAGELATCH or PAGEIOLATCH]'
		ELSE N'[Other]' END AS 'latch_category'
FROM #tblFinalLatches AS W1 INNER JOIN #tblFinalLatches AS W2 ON W2.rn <= W1.rn
GROUP BY W1.rn, W1.latch_class, W1.wait_time_s, W1.waiting_requests_count, W1.pct
HAVING SUM (W2.pct) - W1.pct < 95; -- percentage threshold

;WITH Latches AS
     (SELECT
         latch_class,
         wait_time_ms / 1000.0 AS wait_time_s,
         waiting_requests_count,
         100.0 * wait_time_ms / SUM(wait_time_ms) OVER() AS pct,
         ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS rn
     FROM sys.dm_os_latch_stats
     WHERE /*latch_class NOT IN ('BUFFER')
			AND*/ wait_time_ms > 0
 )
 SELECT 'Historical_Latches' AS [Information], W1.latch_class, 
    CAST(W1.wait_time_s AS DECIMAL(14, 2)) AS wait_time_s,
    W1.waiting_requests_count,
    CAST(W1.pct AS DECIMAL(14, 2)) AS pct,
	CAST(SUM(W1.pct) AS DECIMAL(12, 2)) AS overall_running_pct,
    CAST((W1.wait_time_s / W1.waiting_requests_count) AS DECIMAL (14, 4)) AS avg_wait_s,
	CASE WHEN W1.latch_class LIKE N'ACCESS_METHODS_HOBT_COUNT' 
		OR W1.latch_class LIKE N'ACCESS_METHODS_HOBT_VIRTUAL_ROOT' THEN N'[HoBT - Metadata]'
		WHEN W1.latch_class LIKE N'ACCESS_METHODS_DATASET_PARENT' 
			OR W1.latch_class LIKE N'ACCESS_METHODS_SCAN_RANGE_GENERATOR' 
			OR W1.latch_class LIKE N'NESTING_TRANSACTION_FULL' THEN N'[Parallelism]'
		WHEN W1.latch_class LIKE N'LOG_MANAGER' THEN N'[IO - Log]'
		WHEN W1.latch_class LIKE N'TRACE_CONTROLLER' THEN N'[Trace]'
		WHEN W1.latch_class LIKE N'DBCC_MULTIOBJECT_SCANNER ' THEN N'[Parallelism - DBCC CHECK_]'
		WHEN W1.latch_class LIKE N'FGCB_ADD_REMOVE' THEN N'[IO Operations]'
		WHEN W1.latch_class LIKE N'DATABASE_MIRRORING_CONNECTION ' THEN N'[Mirroring - Busy]'
		WHEN W1.latch_class LIKE N'BUFFER' THEN N'[Buffer Pool - PAGELATCH or PAGEIOLATCH]'
		ELSE N'Other' END AS 'latch_category'
FROM Latches AS W1
INNER JOIN Latches AS W2
    ON W2.rn <= W1.rn
GROUP BY W1.rn, W1.latch_class, W1.wait_time_s, W1.waiting_requests_count, W1.pct
HAVING SUM (W2.pct) - W1.pct < 100; -- percentage threshold
GO

