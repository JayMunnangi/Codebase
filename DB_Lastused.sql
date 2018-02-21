-- gives the date when last accessed.
SELECT name, last_access =(
select X1= max(LA.xx)
from ( select xx =
max(last_user_seek)
where max(last_user_seek)is not null
union all
select xx = max(last_user_scan)
where max(last_user_scan)is not null
union all
select xx = max(last_user_lookup)
where max(last_user_lookup) is not null
union all
select xx =max(last_user_update)
where max(last_user_update) is not null) LA)
FROM master.dbo.sysdatabases sd 
left outer join sys.dm_db_index_usage_stats s 
on sd.dbid= s.database_id 
group by sd.name


-- gives the queries executed last time

Use [HLI]

GO

SELECT DB_NAME() as DatabaseName,
 s1.sql_handle,
 (SELECT TOP 1 SUBSTRING(s2.text,statement_start_offset / 2+1 ,
 ( (CASE WHEN statement_end_offset = -1
THEN (LEN(CONVERT(nvarchar(max),s2.text)) * 2)
 ELSE statement_end_offset END) - statement_start_offset) / 2+1)) AS sql_statement,
 execution_count,
 plan_generation_num,
 last_execution_time,
 total_worker_time,
 last_worker_time,
 min_worker_time,
 max_worker_time,
 total_physical_reads,
 last_physical_reads,
 min_physical_reads,
 max_physical_reads,
 total_logical_writes,
 last_logical_writes,
 min_logical_writes,
 max_logical_writes
FROM sys.dm_exec_query_stats AS s1
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS s2
WHERE s2.objectid is null
ORDER BY s1.sql_handle, s1.statement_start_offset, s1.statement_end_offset