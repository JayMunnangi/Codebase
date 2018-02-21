SELECT
	LEFT (@@version, 25),
	'Cores available:',
	COUNT (*)
FROM sys.dm_os_schedulers
WHERE [status] = 'VISIBLE ONLINE'

UNION ALL

SELECT
	[object_name],
	[counter_name],
	[cntr_value]
FROM sys.dm_os_performance_counters
WHERE [object_name] LIKE '%Memory Node%'
	AND [counter_name] = 'Target Node Memory (KB)'

UNION ALL

SELECT
	[object_name],
	[counter_name],
	[cntr_value]
FROM sys.dm_os_performance_counters
WHERE [object_name] LIKE '%Memory Node%'
	AND [counter_name] = 'Total Node Memory (KB)'

UNION ALL

SELECT
	[object_name] AS [ObjectName],
	[counter_name] AS [CounterName],
	[cntr_value] AS [CounterValue]
FROM sys.dm_os_performance_counters
WHERE [object_name] LIKE '%Buffer Node%'
	AND [counter_name] = 'Page life expectancy'

UNION ALL

SELECT
	[object_name],
	[counter_name],
	[cntr_value]
FROM sys.dm_os_performance_counters
WHERE [object_name] LIKE '%Buffer Manager%'
	AND [counter_name] = 'Page life expectancy';
GO