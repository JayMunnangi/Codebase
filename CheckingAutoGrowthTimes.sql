DECLARE @curr_tracefilename VARCHAR(500), @indx int, @base_tracefilename VARCHAR(500);
SELECT @curr_tracefilename = path FROM sys.traces WHERE is_default = 1;
SET @curr_tracefilename = REVERSE(@curr_tracefilename);
SELECT @indx = PATINDEX('%\%', @curr_tracefilename) ;
SET @curr_tracefilename = REVERSE(@curr_tracefilename) ;
SET @base_tracefilename = LEFT( @curr_tracefilename,LEN(@curr_tracefilename) - @indx) + '\log.trc' ;
WITH AutoGrow_CTE (databaseid, filename, Growth, Duration, StartTime, EndTime)
AS
(
SELECT databaseid, filename, SUM(IntegerData*8) AS Growth, Duration, StartTime, EndTime--, CASE WHEN EventClass =
FROM ::fn_trace_gettable(@base_tracefilename, default)
WHERE EventClass >= 92 AND EventClass <= 95
	AND DATEDIFF(hh,StartTime,GETDATE()) < 24 -- Last 24h
GROUP BY databaseid, filename, IntegerData, Duration, StartTime, EndTime
)
SELECT DB_NAME(database_id) AS DatabaseName, 
	mf.name AS LogicalName,
	mf.size*8 AS CurrentSize_KB,
	mf.type_desc AS 'File_Type',
	CASE WHEN is_percent_growth = 1 THEN 'Percentage' ELSE 'Pages' END AS 'Growth_Type',
	ag.Growth AS Growth_KB,
	Duration/1000 AS Duration_ms,
	ag.StartTime,
	ag.EndTime
FROM sys.master_files mf
LEFT OUTER JOIN AutoGrow_CTE ag
ON mf.database_id=ag.databaseid
	AND mf.name=ag.filename
WHERE ag.Growth > 0 --Only where growth occurred
GROUP BY database_id, mf.name, mf.size, ag.Growth, ag.Duration, ag.StartTime, ag.EndTime, is_percent_growth, mf.growth, mf.type_desc
ORDER BY DatabaseName, LogicalName, ag.StartTime

