IF EXISTS (SELECT * FROM [tempdb].[sys].[objects]
    WHERE [name] LIKE N'#PSR_tracestatus%')
    DROP TABLE [#PSR_tracestatus];
GO

CREATE TABLE [#PSR_tracestatus] (
    [TraceFlag] INT, [Status] INT, [Global] INT, [Session] INT);

INSERT INTO #PSR_tracestatus EXEC ('DBCC TRACESTATUS (1117) WITH NO_INFOMSGS');
INSERT INTO #PSR_tracestatus EXEC ('DBCC TRACESTATUS (1118) WITH NO_INFOMSGS');

SELECT
	[os].[cores],
	(SELECT [Global] FROM #PSR_tracestatus WHERE [TraceFlag] = 1117) AS [1117],
	(SELECT [Global] FROM #PSR_tracestatus WHERE [TraceFlag] = 1118) AS [1118],
	[file_id], [type_desc], [size], [max_size], [growth], [is_percent_growth]
FROM
	tempdb.sys.database_files AS [df],
	(
		SELECT COUNT (*) AS [cores]
		FROM sys.dm_os_schedulers
		WHERE status = 'VISIBLE ONLINE'
	) AS [os];

DROP TABLE [#PSR_tracestatus];
GO