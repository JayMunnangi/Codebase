-- Query to find out the Index usage Per DB, Replace the DBName and IndexName

WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT
	DB_NAME(E.dbid) AS [DBName],
	object_name(E.objectid, dbid) AS [ObjectName],
	P.cacheobjtype AS [CacheObjType],
	P.objtype AS [ObjType],
	E.query_plan.query('count(//RelOp[@LogicalOp = ''Index Scan'' or @LogicalOp = ''Clustered Index Scan'']/*/Object[@Index=''[MyIndex]''])') AS [ScanCount],
	E.query_plan.query('count(//RelOp[@LogicalOp = ''Index Seek'' or @LogicalOp = ''Clustered Index Seek'']/*/Object[@Index=''[MyIndex]''])') AS [SeekCount],
	E.query_plan.query('count(//Update/Object[@Index=''[MyIndex]''])') AS [UpdateCount],
	P.refcounts AS [RefCounts],
	P.usecounts AS [UseCounts],
	E.query_plan AS [QueryPlan]
FROM sys.dm_exec_cached_plans P
CROSS APPLY sys.dm_exec_query_plan(P.plan_handle) E
WHERE
	E.dbid = DB_ID('CQR_CHS_MEDENT01_STG') AND -- Raplce with DBNAME
	E.query_plan.exist('//*[@Index=''[IDX_HL7_CCDMessage_ClinicId]'']') = 1 -- Replcae with Indexname
 