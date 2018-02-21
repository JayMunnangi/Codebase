SET NOCOUNT ON
/*********************************************************************
TO EXTRACT DEFAULT FILL FACTOR CONFIGURED THOUGH SP_CONFIGURE SETTINGS
**********************************************************************/
EXEC sp_configure 'show advanced options',1
GO
RECONFIGURE WITH OVERRIDE
DECLARE @Fillfactor TABLE(Name VARCHAR(100),Minimum INT ,Maximum INT,config_value INT ,run_value INT)
INSERT INTO @Fillfactor EXEC sp_configure 'fill factor (%)'  

/*********************************************************************
 YOU CAN CHANGE THE VALUE OF BELOW PARAMETER AS PER YOUR REQUIREMENTS.
**********************************************************************/

DECLARE @MinPageCount INT = 100				-- Indexes which have more than 100 pages, BOL recomandation is 1000 pages
DECLARE @SORT_IN_TEMPDB Char(5) = 'OFF'     -- Specifies whether to store the sort results in tempdb. The default is OFF.
DECLARE @DefaultFillFactor TinyInt = 0      -- FILLFACTOR determines how much free space in an leaf nodes/data page.
DECLARE @PAD_INDEX Char(5) = 'OFF'			-- PAD_INDEX ON means apply FILLFACTOR to all layers,PAD_INDEX is only useful if FILLFACTOR is set.
DECLARE @ONLINE Char(5) = 'OFF'				/* Specifies whether underlying tables and associated indexes are available for 
											queries and data modification during the index operation, default is OFF, ENTERPRISE ONLY FEATURE.*/


DECLARE @SchemaName Varchar(500) 
DECLARE @TableName Varchar(500) 
DECLARE @IndexName Varchar(500) 
DECLARE @FragValue Numeric(5,2)
DECLARE @cmd nVarchar(max)

IF @DefaultFillFactor = 0
	SELECT @DefaultFillFactor  = CASE WHEN run_value = 0 THEN 100 ELSE  run_value  END  FROM @Fillfactor 
	
IF @DefaultFillFactor <> 100
	SELECT @PAD_INDEX = 'ON'
	
DECLARE db_reindex CURSOR FOR
	SELECT sc.name ShemaName, tb.name TableName, idx.name IndexName, frag.avg_fragmentation_in_percent FragValue
	FROM sys.dm_db_index_physical_stats (db_id(), NULL, NULL, NULL, 'LIMITED') AS Frag
	INNER JOIN sys.tables tb ON tb.object_id = frag.object_id
	INNER JOIN  sys.schemas sc ON tb.schema_id= sc.schema_id  
	INNER JOIN  sys.indexes idx  ON idx.object_id=frag.object_id and idx.index_id=frag.index_id
	where idx.index_id > 0 and avg_fragmentation_in_percent >= 10 And frag.page_count > @MinPageCount
	Order by tb.name , idx.name
	OPEN db_reindex
	FETCH NEXT from db_reindex into @SchemaName , @TableName , @IndexName , @FragValue
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @FragValue Between 10 And 30
			BEGIN
				PRINT 'REORGANIZING INDEX ' + @IndexName + ' ON ' + @SchemaName +'.['+ @TableName +']'
				SET @cmd = 'ALTER INDEX [' + @IndexName + '] ON '+ @SchemaName +'.['+ @TableName +']' + ' REORGANIZE'
				--PRINT @cmd	
				EXEC sp_executesql @cmd
				SET @cmd = 'UPDATE STATISTICS '+ @SchemaName +'.['+ @TableName +']'
				EXEC sp_executesql @cmd
			END
		ELSE
			BEGIN
				PRINT 'REBUILDING INDEX ' + @IndexName + ' ON ' + @SchemaName +'.['+ @TableName +'] '	
				SET @cmd = 'ALTER INDEX [' + @IndexName + '] ON '+ @SchemaName +'.['+ @TableName +']' + ' 
				REBUILD WITH (FILLFACTOR = ' + CAST (@DefaultFillFactor AS VARCHAR(10)) + 
				', SORT_IN_TEMPDB = '  + CAST (@SORT_IN_TEMPDB AS VARCHAR(10)) +
				', PAD_INDEX = '  + CAST (@PAD_INDEX AS VARCHAR(10)) +
				', ONLINE = '  + CAST (@ONLINE AS VARCHAR(10)) + ')'
				--PRINT @cmd	
				EXEC sp_executesql @cmd
			END
		FETCH NEXT from db_reindex into @SchemaName , @TableName , @IndexName , @FragValue	
	END
CLOSE db_reindex
DEALLOCATE db_reindex
EXEC sp_configure 'show advanced options',0
GO
RECONFIGURE WITH OVERRIDE