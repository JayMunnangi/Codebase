-----------------------------------------------------------------------------
-- This SQL script will refresh all views in the database, regardless of the
-- schema. A cursor is created first, then the script loops through the list
-- of the views. sp_refreshview is called for each view inside the loop.
-- Zoltan Horvath
-----------------------------------------------------------------------------
SET NOCOUNT ON

DECLARE @ActualView varchar(255)

DECLARE viewlist CURSOR FAST_FORWARD
FOR
SELECT
	DISTINCT s.name + '.' + o.name AS ViewName
FROM sys.objects o JOIN sys.schemas s ON o.schema_id = s.schema_id 
WHERE	o.[type] = 'V'
		AND OBJECTPROPERTY(o.[object_id], 'IsSchemaBound') <> 1
		AND OBJECTPROPERTY(o.[object_id], 'IsMsShipped') <> 1

OPEN viewlist

FETCH NEXT FROM viewlist 
INTO @ActualView

WHILE @@FETCH_STATUS = 0
BEGIN

	--PRINT @ActualView
	EXEC sp_refreshview @ActualView
	
	FETCH NEXT FROM viewlist
	INTO @ActualView
	
END

CLOSE viewlist
DEALLOCATE viewlist
