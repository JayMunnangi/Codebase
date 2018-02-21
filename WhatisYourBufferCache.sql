--Find out wether Ad Hoc Workloads is ON?

USE master
GO 
SELECT  CASE value_in_use
          WHEN 0 THEN 'Optimize for Ad Hoc Workloads is Turned Off'
          WHEN 1 THEN 'Optimize for Ad Hoc Workloads is Turned On'
        END AS [Optimize for Ad Hoc Workloads Current Status]
FROM    sys.configurations
WHERE   name = 'optimize for ad hoc workloads';
GO

-- find out Adhoc query plans occupy?

SELECT objtype AS [CacheType],
    COUNT_BIG(*) AS [Total Plans],
    SUM(CAST(size_in_bytes AS DECIMAL(18, 2))) / 1024 / 1024 AS [Total MBs],
    AVG(usecounts) AS [Avg Use Count],
    SUM(CAST((CASE WHEN usecounts = 1 THEN size_in_bytes
        ELSE 0
        END) AS DECIMAL(18, 2))) / 1024 / 1024 AS [Total MBs – USE Count 1],
    SUM(CASE WHEN usecounts = 1 THEN 1
        ELSE 0
        END) AS [Total Plans – USE Count 1]
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY [Total MBs – USE Count 1] DESC
GO