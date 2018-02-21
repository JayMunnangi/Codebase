--Make sense of FILESTREAM data
--Execute thru DAC

SET NOCOUNT ON;
DBCC TRACEON (3604) WITH NO_INFOMSGS;
DECLARE @tblname VARCHAR(255), @filenum int, @pagenum int, @sqlcmd VARCHAR(255), @value VARCHAR(255), @field VARCHAR(9)
CREATE TABLE #tblout (ParentObject VARCHAR(100), [Object] VARCHAR(255), Field VARCHAR(30), Value VARCHAR(255))
CREATE TABLE #tblout_filtered (ParentTable VARCHAR(255), Field VARCHAR(30), Value VARCHAR(255))
CREATE TABLE #tblfslist (ParentTable VARCHAR(255), [filename] VARCHAR(255), [ntfs_filename] VARCHAR(255))
DECLARE curTbls CURSOR FAST_FORWARD FOR SELECT OBJECT_NAME(object_id) FROM sys.all_columns WHERE is_filestream = 1
OPEN curTbls
FETCH NEXT FROM curTbls INTO @tblname
WHILE @@FETCH_STATUS = 0
BEGIN
	WITH ntbl AS (SELECT OBJECT_NAME (sp.object_id) AS [Object Name],
	CONVERT (VARCHAR(6), CONVERT (INT, SUBSTRING (sa.first_page, 6, 1) + SUBSTRING (sa.first_page, 5, 1))) AS [FileNum],
	CONVERT (VARCHAR(20), CONVERT (INT, SUBSTRING (sa.first_page, 4, 1) + SUBSTRING (sa.first_page, 3, 1) + SUBSTRING (sa.first_page, 2, 1) + SUBSTRING (sa.first_page, 1, 1))) AS [PageNum]
	FROM sys.system_internals_allocation_units sa INNER JOIN sys.partitions sp ON sa.container_id = sp.partition_id
	WHERE sp.object_id = OBJECT_ID(@tblname) 
		AND sp.index_id = 0
	)
	SELECT @filenum = [FileNum], @pagenum = [PageNum] FROM ntbl WHERE [FileNum] > 0
	SET @sqlcmd = 'DBCC PAGE (' + DB_NAME() + ', ' + CONVERT(VARCHAR, @filenum) + ', ' + CONVERT(VARCHAR, @pagenum) + ', 3) WITH TABLERESULTS;'
	PRINT @sqlcmd
	INSERT INTO #tblout
	EXEC (@sqlcmd)
	INSERT INTO #tblout_filtered
	SELECT @tblname, Field, Value FROM #tblout WHERE Field = 'FileName' OR Field = 'CreateLSN' --Here is were having listed the filename in a column starts making sense.
	TRUNCATE TABLE #tblout
	FETCH NEXT FROM curTbls INTO @tblname
END
CLOSE curTbls
DEALLOCATE curTbls;

DECLARE curFinal CURSOR FAST_FORWARD FOR SELECT ParentTable, Field, Value FROM #tblout_filtered
OPEN curFinal
FETCH NEXT FROM curFinal INTO @tblname, @field, @value
WHILE @@FETCH_STATUS = 0
BEGIN
	IF @field = 'FileName'
		BEGIN
			INSERT INTO #tblfslist (ParentTable, [filename])
			SELECT @tblname, @value
		END
	ELSE
		BEGIN
			UPDATE #tblfslist 
			SET [ntfs_filename] = REPLACE(LEFT(@value, CHARINDEX('(',@value)-2),':','-')
			WHERE [ntfs_filename] IS NULL
		END
	FETCH NEXT FROM curFinal INTO @tblname, @field, @value
END
CLOSE curFinal
DEALLOCATE curFinal;

SELECT o.name AS [Table], cp.name AS [Column], p.partition_number AS [Partition], 
	CONVERT(CHAR(36), CAST(r.rsguid AS UNIQUEIDENTIFIER)) AS [1st_Level],
	CONVERT(CHAR(36), CAST(rs.colguid AS UNIQUEIDENTIFIER)) AS [2nd_Level],
	tb.[filename], tb.[ntfs_filename]
FROM sys.sysrowsets r CROSS APPLY sys.sysrscols rs
	INNER JOIN sys.partitions p ON rs.rsid = p.partition_id
	INNER JOIN sys.objects o ON o.object_id = p.object_id
	INNER JOIN sys.syscolpars cp ON cp.colid = rs.rscolid
	INNER JOIN #tblfslist tb ON o.name = tb.ParentTable
WHERE rs.colguid IS NOT NULL 
	AND o.object_id = cp.id
	AND r.rsguid IS NOT NULL 
	AND r.rowsetid = rs.rsid;
		
DROP TABLE #tblout;
DROP TABLE #tblout_filtered;
DROP TABLE #tblfslist;
GO

