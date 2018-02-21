----Syntax
--USE [DatabaseName]
--GO 
--CREATE USER [UserName] FOR LOGIN [LoginName] WITH DEFAULT_SCHEMA =schema_name 
--GO
--EXEC sp_addrolemember 'db_datareader', 'UserName'

---Script For All Databases
---------------------------------------------------------------------
USE master
GO
DECLARE @LoginName varchar(256)
SET @LoginName ='Advisory\PannersR'

SELECT 'USE [' + Name + ']'
+ ';'
+ 'CREATE USER [' + @LoginName + '] FOR LOGIN [' + @LoginName + '] WITH DEFAULT_SCHEMA =dbo'
+ ';'
+ 'EXEC sp_addrolemember ''db_datareader'', '''+ @LoginName + ''''
AS ScriptToExecute

FROM sys.databases 
WHERE name NOT IN ('Master','tempdb','model','msdb','DBA_Archive') -- Avoid System Databases
	AND (state_desc ='ONLINE') -- Avoid Offline Databases
	AND (source_database_id Is Null) -- Avoid Database Snapshot
ORDER BY Name
