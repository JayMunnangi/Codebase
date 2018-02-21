This metric needs to be considered alongside the Plan cache reuse metric that looks at the spread of plan reuse through your cache.

This metric measures how much the plan cache is being used. A high percentage here means that your SQL Server is not building a new plan for every query it is executing so is working effectively and efficiently. A low percentage here means that for some reason, the SQL Server is doing more work than it needs to. This metric needs to be considered alongside the Plan cache reuse metric which looks at the spread of plan reuse through your cache. 




WITH    cte1 
          AS ( SELECT [dopc].[object_name] , 
                    [dopc].[instance_name] , 
                    [dopc].[counter_name] , 
                    [dopc].[cntr_value] , 
                    [dopc].[cntr_type] , 
                    ROW_NUMBER() OVER ( PARTITION BY [dopc].[object_name], [dopc].[instance_name] ORDER BY [dopc].[counter_name] ) AS r_n 
                FROM [sys].[dm_os_performance_counters] AS dopc 
                WHERE [dopc].[counter_name] LIKE '%Cache Hit Ratio%' 
                    AND ( [dopc].[object_name] LIKE '%Plan Cache%' 
                          OR [dopc].[object_name] LIKE '%Buffer Cache%' 
                        ) 
                    AND [dopc].[instance_name] LIKE '%_Total%' 
             ) 
    SELECT CONVERT(DECIMAL(16, 2), ( [c].[cntr_value] * 1.0 / [c1].[cntr_value] ) * 100.0) AS [hit_pct] 
        FROM [cte1] AS c  
            INNER JOIN [cte1] AS c1 
                ON c.[object_name] = c1.[object_name] 
                   AND c.[instance_name] = c1.[instance_name] 
        WHERE [c].[r_n] = 1 
            AND [c1].[r_n] = 2; 


--PLAN CACHE REUSE

--This metric shows the percentage of cached plans that are being used more than once. If --a plan is cached but never reused, there may be an opportunity to tune your server to --work more effectively by rewriting the TSQL or creating a parameterized plan.



DECLARE @single DECIMAL(18, 2) 


DECLARE @reused DECIMAL(18, 2) 


DECLARE @total DECIMAL(18, 2) 


-- the above variables may need a precision greater than 18 on VLDB instances. This will incur a storage penalty in the RedgateMonitor database however. 


SELECT @single = SUM(CASE ( usecounts ) 
                       WHEN 1 THEN 1 
                       ELSE 0 
                     END) * 1.0 , 
        @reused = SUM(CASE ( usecounts ) 
                       WHEN 1 THEN 0 
                        ELSE 1 
                      END) * 1.0 , 
        @total = COUNT(usecounts) * 1.0 
    FROM sys.dm_exec_cached_plans; 
SELECT ( @single / @total ) * 100.0; 
