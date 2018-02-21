DECLARE @dbname VARCHAR(50)
DECLARE @statement NVARCHAR(max)
DECLARE db_cursor CURSOR
LOCAL FAST_FORWARD
FOR
SELECT name
FROM sys.databases
WHERE name IN ('CCI_CHPBuffalo_PRD')
OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @dbname
WHILE @@FETCH_STATUS = 0
BEGIN
SELECT @statement = 'use '+@dbname +';'+ 'IF NOT EXISTS(SELECT name from sys.database_principals where name =''ADVISORY\MuskuA'')
CREATE USER [ADVISORY\MuskuA]FOR LOGIN [ADVISORY\MuskuA];
EXEC sp_addrolemember N''db_datareader'',[ADVISORY\MuskuA]'
exec sp_executesql @statement
FETCH NEXT FROM db_cursor INTO @dbname
END
CLOSE db_cursor
DEALLOCATE db_cursor
GO