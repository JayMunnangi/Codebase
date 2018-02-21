EXEC sp_MSforeachdb '
DECLARE @name VARCHAR(500)
SELECT @name = ''?''
IF ''?'' not in (''tempdb'',''master'',''msdb'',''model'',''DBA_Archive'')
BEGIN
USE [?] IF DATABASEPROPERTYEX(''?'',''Status'') =''ONLINE'' AND DATABASEPROPERTYEX(''?'',''Updateability'')=''READ_WRITE''
BEGIN
IF NOT EXISTS(Select * from sys.sysusers where name = ''ADVISORY\SW_InformaticaSVC'')
BEGIN
CREATE USER [ADVISORY\SW_InformaticaSVC] FOR LOGIN [ADVISORY\SW_InformaticaSVC] PRINT ''Added User for ?''
END
EXEC sp_addrolemember ''db_datareader'', ''ADVISORY\SW_InformaticaSVC''
PRINT ''Added db_datareader for ?''
END
ELSE
PRINT ''SKIPPED the ? database''
END '