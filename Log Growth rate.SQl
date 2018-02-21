-- Log Growth Rate
;WITH
 logs AS
   (SELECT DB.name AS DatabaseName
          ,MAX(DB.recovery_model_desc) AS RecoveryModel
          ,SUM(size * 8) AS TotalSizeKB
          ,SUM(CASE WHEN MF.is_percent_growth = 0
                    THEN MF.growth
                    ELSE MF.size * MF.growth / 100
                    END * 8) AS TotalGrowthKB
    FROM sys.master_files AS MF
         INNER JOIN sys.databases AS DB
             ON MF.database_id = DB.database_id
    WHERE MF.[type] = 1
    GROUP BY DB.name)
,total AS
   (SELECT OPC.[cntr_value] AS TotalCounter
    FROM sys.dm_os_performance_counters AS OPC
    WHERE OPC.[object_name] LIKE N'%SQL%:Databases%'
      AND OPC.[counter_name] = N'Log Growths'
      AND OPC.[instance_name] = N'_Total')
,growth AS
   (SELECT OPC.[instance_name] AS DatabaseName
          ,OPC.[cntr_value] AS Growths
    FROM sys.dm_os_performance_counters AS OPC
    WHERE OPC.[object_name] LIKE N'%SQL%:Databases%'
          AND OPC.[counter_name] = N'Log Growths'
          AND OPC.[instance_name] <> N'_Total')
,shrinks AS
   (SELECT OPC.[instance_name] AS DatabaseName
          ,OPC.[cntr_value] AS Shrinks
    FROM sys.dm_os_performance_counters AS OPC
    WHERE OPC.[object_name] LIKE N'%SQL%:Databases%'
          AND OPC.[counter_name] = N'Log Shrinks'
          AND OPC.[instance_name] <> N'_Total')
SELECT logs.DatabaseName
      ,logs.RecoveryModel
      ,logs.TotalSizeKB
      ,logs.TotalGrowthKB
      ,shrinks.Shrinks
      ,growth.Growths
      ,CONVERT(decimal(38, 2)
              ,CASE WHEN total.TotalCounter = 0
               THEN 0.0
               ELSE 100.0 * growth.Growths / total.TotalCounter
               END) AS [GrowthRate %]
FROM logs
     INNER JOIN growth
         ON logs.DatabaseName = growth.DatabaseName
     INNER JOIN shrinks
         ON logs.DatabaseName = shrinks.DatabaseName
     CROSS JOIN total
ORDER BY [GrowthRate %] DESC
        ,logs.DatabaseName ASC;