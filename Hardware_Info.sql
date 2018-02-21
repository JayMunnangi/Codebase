-- Hardware information from SQL Server 2008 R2  (Query 10) (Hardware Info)
-- (Cannot distinguish between HT and multi-core)
SELECT cpu_count AS [Logical CPU Count], hyperthread_ratio AS [Hyperthread Ratio],
cpu_count/hyperthread_ratio AS [Physical CPU Count], 
physical_memory_in_bytes/1048576 AS [Physical Memory (MB)], 
sqlserver_start_time, affinity_type_desc 
FROM sys.dm_os_sys_info WITH (NOLOCK) OPTION (RECOMPILE);