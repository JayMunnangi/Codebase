DECLARE @cmdKill VARCHAR(50)
DECLARE killCursor CURSOR FOR
SELECT 'KILL ' + Convert(VARCHAR(5), p.spid)
FROM master.dbo.sysprocesses AS p
WHERE p.dbid = db_id('MyDB')
OPEN killCursor
FETCH killCursor INTO @cmdKill
WHILE 0 = @@fetch_status
BEGIN
EXECUTE (@cmdKill) 
FETCH killCursor INTO @cmdKill
END
CLOSE killCursor
DEALLOCATE killCursor

--multiple ways of doing the same


--ALTER DATABASE [adb] SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE

--ALTER DATABASE [adb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE