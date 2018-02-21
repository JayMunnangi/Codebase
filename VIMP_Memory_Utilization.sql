SELECT [cntr_value] FROM sys.dm_os_performance_counters WHERE [object_name] LIKE '%Buffer Manager%' AND [counter_name] = 'Page life expectancy'
SELECT [cntr_value] FROM sys.dm_os_performance_counters WHERE [object_name] LIKE '%Buffer Manager%' AND [counter_name] = 'Buffer cache hit ratio'
SELECT [cntr_value] FROM sys.dm_os_performance_counters WHERE [object_name] LIKE '%Memory Manager%' AND [counter_name] IN ('Total Server Memory (KB)','Target Server Memory (KB)')
SELECT [cntr_value] FROM sys.dm_os_performance_counters WHERE [object_name] LIKE '%Memory Manager%' AND [counter_name] = 'Memory Grants Pending'
SELECT [cntr_value] FROM sys.dm_os_performance_counters WHERE [object_name] LIKE '%SQL Statistics%' AND [counter_name] = 'Batch Requests/sec'
SELECT [cntr_value] FROM sys.dm_os_performance_counters WHERE [object_name] LIKE '%SQL Statistics%' AND [counter_name] = 'SQL Compilations/sec'
SELECT ROUND (100.0 * (SELECT [cntr_value] FROM sys.dm_os_performance_counters WHERE [object_name] LIKE '%SQL Statistics%' AND [counter_name] = 'SQL Compilations/sec')
/(SELECT [cntr_value] FROM sys.dm_os_performance_counters WHERE [object_name] LIKE '%SQL Statistics%' AND [counter_name] = 'Batch Requests/sec'),2) as [Ratio]


-- https://blog.sqlrx.com/2015/05/07/sql-server-memory-in-task-manager-should-i-be-worried/