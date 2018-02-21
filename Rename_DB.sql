DECLARE @DatabaseName nvarchar(50)
DECLARE @NewDatabaseName nvarchar(50)
DECLARE @SQL varchar(max)

SET @DatabaseName = DB_NAME()
--SET @NewDatabaseName = REPLACE(@DatabaseName,'DB','TestDB') + '_NewToProduction'
SET @SQL = ''

/*IF (SELECT COUNT(*) from sys.databases where name = 'Old' + @DatabaseName ) > 0 
EXEC('ALTER DATABASE OLD' + @DatabaseName + ' MODIFY NAME = OLD' + @DatabaseName + '_ToBeDeleted')
ELSE PRINT 'OLD' + @DatabaseName +  ' not Found'*/

SELECT @SQL = @SQL + 'Kill ' + Convert(varchar, SPId) + ';'
FROM MASTER..SysProcesses
WHERE DBId = DB_ID(@DatabaseName) AND SPId <> @@SPId

--SELECT @SQL  --To Select how many process to kill
EXEC(@SQL)

EXEC sp_renamedb 'CCI_MH_STG', 'CCI_MH_STG_old'