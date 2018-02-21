USE [AdventureWorks2012];
GO
 
EXEC sp_helpstats 'Sales.SalesOrderDetail', 'ALL';
GO
 
SELECT  [sch].[name] + '.' + [so].[name] AS [TableName] ,
        [si].[index_id] AS [Index ID] ,
        [ss].[name] AS [Statistic] ,
        STUFF(( SELECT  ', ' + [c].[name]
                FROM    [sys].[stats_columns] [sc]
                        JOIN [sys].[columns] [c]
                         ON [c].[column_id] = [sc].[column_id]
                            AND [c].[object_id] = [sc].[OBJECT_ID]
                WHERE   [sc].[object_id] = [ss].[object_id]
                        AND [sc].[stats_id] = [ss].[stats_id]
                ORDER BY [sc].[stats_column_id]
              FOR
                XML PATH('')
              ), 1, 2, '') AS [ColumnsInStatistic] ,
        [ss].[auto_Created] AS [WasAutoCreated] ,
        [ss].[user_created] AS [WasUserCreated] ,
        [ss].[has_filter] AS [IsFiltered] ,
        [ss].[filter_definition] AS [FilterDefinition] ,
        [ss].[is_temporary] AS [IsTemporary]
FROM    [sys].[stats] [ss]
        JOIN [sys].[objects] AS [so] ON [ss].[object_id] = [so].[object_id]
        JOIN [sys].[schemas] AS [sch] ON [so].[schema_id] = [sch].[schema_id]
        LEFT OUTER JOIN [sys].[indexes] AS [si]
              ON [so].[object_id] = [si].[object_id]
                 AND [ss].[name] = [si].[name]
WHERE   [so].[object_id] = OBJECT_ID(N'Sales.SalesOrderDetail')
ORDER BY [ss].[user_created] ,
        [ss].[auto_created] ,
        [ss].[has_filter];
GO

