/**********************************************
--Script to find out currently executing query
**********************************************/

SELECT r.session_id,r.command,CONVERT(NUMERIC(6,2),r.percent_complete)
AS [Percent Complete],CONVERT(VARCHAR(20),DATEADD(ms,r.estimated_completion_time,GetDate()),20) AS [ETA Completion Time],
CONVERT(NUMERIC(10,2),r.total_elapsed_time/1000.0/60.0) AS [Elapsed Min],
CONVERT(NUMERIC(10,2),r.estimated_completion_time/1000.0/60.0) AS [ETA Min],
CONVERT(NUMERIC(10,2),r.estimated_completion_time/1000.0/60.0/60.0) AS [ETA Hours],
CONVERT(VARCHAR(1000),(SELECT SUBSTRING(text,r.statement_start_offset/2,
CASE WHEN r.statement_end_offset = -1 THEN 1000 ELSE (r.statement_end_offset-r.statement_start_offset)/2 END)
FROM sys.dm_exec_sql_text(sql_handle)))
FROM sys.dm_exec_requests r WHERE command IN ('RESTORE DATABASE','BACKUP DATABASE')


/**********************************************
--Missing Index Script
**********************************************/

SELECT TOP 25
dm_mid.database_id AS DatabaseID,
dm_migs.avg_user_impact*(dm_migs.user_seeks+dm_migs.user_scans) Avg_Estimated_Impact,
dm_migs.last_user_seek AS Last_User_Seek,
OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id) AS [TableName],
'CREATE INDEX [IX_' + OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id) + '_'
+ REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.equality_columns,''),', ','_'),'[',''),']','') +
CASE
WHEN dm_mid.equality_columns IS NOT NULL AND dm_mid.inequality_columns IS NOT NULL THEN '_'
ELSE ''
END
+ REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.inequality_columns,''),', ','_'),'[',''),']','')
+ ']'
+ ' ON ' + dm_mid.statement
+ ' (' + ISNULL (dm_mid.equality_columns,'')
+ CASE WHEN dm_mid.equality_columns IS NOT NULL AND dm_mid.inequality_columns IS NOT NULL THEN ',' ELSE
'' END
+ ISNULL (dm_mid.inequality_columns, '')
+ ')'
+ ISNULL (' INCLUDE (' + dm_mid.included_columns + ')', '') AS Create_Statement
FROM sys.dm_db_missing_index_groups dm_mig
INNER JOIN sys.dm_db_missing_index_group_stats dm_migs
ON dm_migs.group_handle = dm_mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details dm_mid
ON dm_mig.index_handle = dm_mid.index_handle
WHERE dm_mid.database_ID = DB_ID()
ORDER BY Avg_Estimated_Impact DESC
GO

 
/**********************************************
--To kill existing connection
**********************************************/
	DECLARE @DBNAME VARCHAR(25)
	SET @DBNAME = DB_NAME()
	USE [master] 
	DECLARE @KILLSPID VARCHAR(10) 
	DECLARE @SPID INT 
	DECLARE SPID_Cr CURSOR FOR SELECT SPID FROM Master..sysprocesses WHERE DBID = DB_ID(@DBNAME)
	OPEN SPID_Cr 
	FETCH NEXT FROM SPID_Cr INTO @SPID 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
	 SET @KILLSPID = 'KILL '+ CAST(@SPID AS VARCHAR(10)) 
	 Exec (@KILLSPID) 
	FETCH NEXT FROM SPID_Cr INTO @SPID 
	END 
	CLOSE SPID_Cr 
	DEALLOCATE SPID_Cr

/**********************************************
--To get create user script before restore
**********************************************/
	DECLARE @DBNAME VARCHAR(128)
	SET @DBNAME = DB_NAME()
	DECLARE @TblUser TABLE (UserNM VARCHAR(128),GroupNM VARCHAR(128),LoginNM VARCHAR(128),DefDBNM VARCHAR(128),DefSchNM VARCHAR(128),UserID INT, SID varbinary(128)) INSERT INTO @TblUser EXEC sp_helpuser 
	--Create Statement
	SELECT +'USE '+@DBNAME+' IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'''+UserNM+''') 
	CREATE USER ['+UserNM+'] FOR LOGIN ['+LoginNM+'] 
	EXEC sp_addrolemember N'''+GroupNM+''', N'''+UserNM+'''' AS UserInfo 
	FROM @TblUser 
	WHERE LoginNM IS NOT NULL 
	AND UserNM NOT LIKE 'dbo' 
	AND UserNM NOT LIKE '##%' 
	AND GroupNM NOT LIKE 'public'
	UNION
	SELECT +'USE '+@DBNAME+' IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'''+UserNM+''') 
	CREATE USER ['+UserNM+'] FOR LOGIN ['+LoginNM+']' AS UserInfo 
	FROM @TblUser 
	WHERE LoginNM IS NOT NULL 
	AND UserNM NOT LIKE 'dbo' 
	AND UserNM NOT LIKE '##%' 
	AND GroupNM LIKE 'public'

 
/**********************************************
--To get drop user script after restore
**********************************************/
	DECLARE @DBNAME VARCHAR(128)
	SET @DBNAME = DB_NAME()

	SET NOCOUNT ON
	DECLARE @TblUser TABLE (UserNM VARCHAR(128),
	GroupNM VARCHAR(128),
	LoginNM VARCHAR(128),
	DefDBNM VARCHAR(128),
	DefSchNM VARCHAR(128),
	UserID INT, 
	SID varbinary(128))

	INSERT INTO @TblUser EXEC sp_helpuser 
	SELECT DISTINCT +'IF EXISTS (SELECT * FROM sys.database_principals WHERE name = N'''+UserNM+''') 
	DROP USER ['+UserNM+']' AS OrphUsers 
	FROM @TblUser WHERE LoginNM IS NOT NULL 
	AND UserNM NOT LIKE 'dbo' 
	AND UserNM NOT LIKE '##%' 
	AND UserID NOT IN (SELECT schema_id FROM sys.objects)
	UNION 
	SELECT +'IF EXISTS (SELECT * FROM sys.schemas WHERE name = N'''+name+''') 
	DROP SCHEMA ['+name+']' AS OrphUsers FROM sys.schemas 
	WHERE schema_id NOT IN (SELECT schema_id FROM sys.objects) 
	AND schema_id NOT BETWEEN 16384 AND 16393 
	AND schema_id NOT BETWEEN 1 AND 4


/**********************************************
--Script to check restore progress
**********************************************/
	SELECT r.session_id,r.command,CONVERT(NUMERIC(6,2),r.percent_complete)
	AS [Percent Complete],CONVERT(VARCHAR(20),DATEADD(ms,r.estimated_completion_time,GetDate()),20) AS [ETA Completion Time],
	CONVERT(NUMERIC(10,2),r.total_elapsed_time/1000.0/60.0) AS [Elapsed Min],
	CONVERT(NUMERIC(10,2),r.estimated_completion_time/1000.0/60.0) AS [ETA Min],
	CONVERT(NUMERIC(10,2),r.estimated_completion_time/1000.0/60.0/60.0) AS [ETA Hours],
	CONVERT(VARCHAR(1000),(SELECT SUBSTRING(text,r.statement_start_offset/2,
	CASE WHEN r.statement_end_offset = -1 THEN 1000 ELSE (r.statement_end_offset-r.statement_start_offset)/2 END)
	FROM sys.dm_exec_sql_text(sql_handle)))
	FROM sys.dm_exec_requests r WHERE command IN ('RESTORE DATABASE','BACKUP DATABASE')


/**********************************************
--Script to check db size available space
**********************************************/
	USE tempdb 
	SELECT
		a.FILEID,
		CONVERT(decimal(12,2),ROUND(a.size/128.000,2)) as [FILESIZEINMB] ,
		CONVERT(decimal(12,2),ROUND(fileproperty(a.name,'SpaceUsed')/128.000,2)) as [SPACEUSEDINMB],
		CONVERT(decimal(12,2),ROUND((a.size-fileproperty(a.name,'SpaceUsed'))/128.000,2)) as [FREESPACEINMB],
		a.name as [DATABASENAME],
		a.FILENAME as [FILENAME]

	FROM
		dbo.sysfiles a

/**********************************************
-- Script tos cript out Server Logins, dataase users, object permissions etc
**********************************************/
	SELECT  @@servername AS ServerNM,name AS UserNM,
	CASE WHEN isntname=1 THEN CASE WHEN isntgroup=1 THEN 'ADGroup' WHEN isntuser=1 THEN 'ADUser' END ELSE 'MssqlUser' END AS logintype,
	CASE WHEN sysadmin=1 THEN 'Y' ELSE 'N' END AS sysadmin,
	CASE WHEN securityadmin=1 THEN 'Y' ELSE 'N' END AS securityadmin,
	CASE WHEN serveradmin=1 THEN 'Y' ELSE 'N' END AS  serveradmin,
	CASE WHEN setupadmin=1 THEN 'Y' ELSE 'N' END AS setupadmin,
	CASE WHEN processadmin=1 THEN 'Y' ELSE 'N' END AS processadmin,
	CASE WHEN diskadmin =1 THEN 'Y' ELSE 'N' END AS diskadmin,
	CASE WHEN dbcreator=1 THEN 'Y' ELSE 'N' END AS dbcreator,
	CASE WHEN bulkadmin=1 THEN 'Y' ELSE 'N' END AS bulkadmin
	FROM master..syslogins
	WHERE name NOT LIKE '##%'
	ORDER BY name

	--database users

	--SELECT @@ServerName AS Server_NM,DB_Name() AS Database_NM,A.name AS User_NM FROM sysusers A WHERE A.name NOT LIKE 'dbo' and hasdbaccess = '1'
	--SELECT @@ServerName AS Server_NM,DB_NAME() AS Database_NM,A.name AS User_NM,B.name AS Database_Role FROM sysusers A INNER JOIN sysmembers C ON A.uid = C.memberuid INNER JOIN sysusers B ON C.groupuid = B.uid WHERE A.name NOT LIKE 'dbo'
	--sp_helpuser
	set nocount on
	DECLARE @SQL VARCHAR(2000)
	DECLARE @DBName VARCHAR(100)
	CREATE TABLE [##Tbl_sysusers] ([ServerNM] [nvarchar] (25) NULL,[DatabaseNM] [nvarchar] (100) NULL,[UserNM] [nvarchar] (100) NULL,[GroupNM] [nvarchar] (50) NULL)
	DECLARE DBNameCR CURSOR FOR SELECT name FROM master..sysdatabases 
	WHERE DATABASEPROPERTYEX(name, 'Status') = 'ONLINE'
	 --AND name LIKE ('Database Name')
	OPEN DBNameCR
	FETCH NEXT FROM DBNameCR INTO @DBName
	WHILE @@FETCH_STATUS = 0
	BEGIN
	SET @SQL = --'EXEC '+@DBName+'..sp_helpuser'
	'SELECT @@ServerName AS ServerNM,'''+@DBName+''' AS DatabaseNM,A.name AS User_NM,B.name AS Database_Role FROM ['+@DBName+']..sysusers A INNER JOIN ['+@DBName+']..sysmembers C ON A.uid = C.memberuid INNER JOIN ['+@DBName+']..sysusers B ON C.groupuid = B.uid
	UNION
	SELECT @@ServerName AS ServerNM,'''+@DBName+''' AS DatabaseNM,A.name AS User_NM,B.name AS Database_Role FROM ['+@DBName+']..sysusers A INNER JOIN ['+@DBName+']..sysusers B ON A.altuid = B.uid WHERE A.isaliased = 1'
	--PRINT @SQL
	INSERT INTO [##Tbl_sysusers] Exec (@SQL)
	FETCH NEXT FROM DBNameCR INTO @DBName
	END
	CLOSE DBNameCR
	DEALLOCATE DBNameCR
	SELECT ServerNM,DatabaseNM,UserNM,GroupNM FROM [##Tbl_sysusers]
	DROP TABLE [##Tbl_sysusers]

--Object Permissions

	DECLARE @SQL VARCHAR(100)
	DECLARE @DBName VARCHAR(100)

	CREATE TABLE [##Tbl_helprotect] ([Owner] [nvarchar] (128) NULL,[Object] [nvarchar] (128) NULL,[Grantee] [nvarchar] (128) NULL,[Grantor] [nvarchar] (128) NULL,[ProtectType] [nvarchar] (128) NULL,[Action] [nvarchar] (128) NULL,[Column] [nvarchar] (128) NULL)
	CREATE TABLE [##Tbl_Objects_Perm] ([ServerNM] [nvarchar] (128) NULL,[DatabaseNM] [nvarchar] (128) NULL,[Owner] [nvarchar] (128) NULL,[Grantor] [nvarchar] (128) NULL,[Grantee] [nvarchar] (128) NULL,[ObjectNM] [nvarchar] (125) NULL,[Select] [varchar] (16) NULL,[Insert] [varchar] (16) NULL,[Delete] [varchar] (16) NULL,[Update] [varchar] (16) NULL,[Reference] [varchar] (16) NULL,[Execute] [varchar] (16) NULL)

	DECLARE DBNameCR CURSOR FOR SELECT name FROM master..sysdatabases 
	WHERE name NOT IN ('tempdb') AND DATABASEPROPERTYEX(name, 'Status') = 'ONLINE' 
	--AND name like 'RealNet'
	OPEN DBNameCR
	FETCH NEXT FROM DBNameCR INTO @DBName
	WHILE @@FETCH_STATUS = 0
	BEGIN
	SET @SQL = 'EXEC '+@DBName+'..sp_helprotect'
	--PRINT @SQL
	INSERT INTO [##Tbl_helprotect] Exec (@SQL)
	--SELECT * FROM [##Tbl_helprotect] WHERE Owner NOT IN ('sys','.') AND Grantee NOT IN ('public')
	--DROP TABLE [##Tbl_helprotect]
	INSERT INTO ##Tbl_Objects_Perm
	SELECT DISTINCT @@servername AS ServerNM, @DBName AS DatabaseNM,a.Owner,a.Grantor,a.Grantee,a.Object,--g.Action END  AS [Select], b.Action AS [Insert], c.Action AS [Delete], d.Action AS [Update], e.Action AS [References],f.Action AS [Eexecute]
	CASE ISNULL(g.Action,'Yes')WHEN 'Yes' THEN 'O' ELSE g.Action END  AS [Select],
	CASE ISNULL(b.Action,'Yes')WHEN 'Yes' THEN 'O' ELSE b.Action END  AS [Insert],
	CASE ISNULL(c.Action,'Yes')WHEN 'Yes' THEN 'O' ELSE c.Action END  AS [Delete],
	CASE ISNULL(d.Action,'Yes')WHEN 'Yes' THEN 'O' ELSE d.Action END  AS [Update],
	CASE ISNULL(e.Action,'Yes')WHEN 'Yes' THEN 'O' ELSE e.Action END  AS [References],
	CASE ISNULL(f.Action,'Yes')WHEN 'Yes' THEN 'O' ELSE f.Action END  AS [Eexecute]
	from [##Tbl_helprotect] a 
	LEFT OUTER JOIN [##Tbl_helprotect] b ON a.Object = b.Object and a.Grantee = b.Grantee and b.Action = 'Insert'
	LEFT OUTER JOIN [##Tbl_helprotect] c ON a.Object = c.Object and a.Grantee = c.Grantee and c.Action = 'Delete'
	LEFT OUTER JOIN [##Tbl_helprotect] d ON a.Object = d.Object and a.Grantee = d.Grantee and d.Action = 'Update'
	LEFT OUTER JOIN [##Tbl_helprotect] e ON a.Object = e.Object and a.Grantee = e.Grantee and e.Action = 'References'
	LEFT OUTER JOIN [##Tbl_helprotect] f ON a.Object = f.Object and a.Grantee = f.Grantee and f.Action = 'Execute'
	LEFT OUTER JOIN [##Tbl_helprotect] g ON a.Object = g.Object and a.Grantee = g.Grantee and g.Action = 'Select'
	WHERE a.Owner NOT IN ('sys','.') AND a.Grantee NOT IN ('public','guest') --a.Owner NOT IN ('.')
	DELETE FROM ##Tbl_helprotect
	FETCH NEXT FROM DBNameCR INTO @DBName
	END
	CLOSE DBNameCR
	DEALLOCATE DBNameCR
	SELECT * FROM [##Tbl_Objects_Perm]
	DROP TABLE [##Tbl_helprotect]
	DROP TABLE [##Tbl_Objects_Perm]

--Object Permissions 2

	-- note: this is sample script to get object level permissions for a particular db. check where condition
	DECLARE @SQL VARCHAR(100)
	DECLARE @DBName VARCHAR(100)

	CREATE TABLE [##Tbl_helprotect] ([Owner] [nvarchar] (128) NULL,[Object] [nvarchar] (128) NULL,[Grantee] [nvarchar] (128) NULL,[Grantor] [nvarchar] (128) NULL,[ProtectType] [nvarchar] (128) NULL,[Action] [nvarchar] (128) NULL,[Column] [nvarchar] (128) NULL)
	CREATE TABLE [##Tbl_Objects_Perm] ([ServerNM] [nvarchar] (128) NULL,[DatabaseNM] [nvarchar] (128) NULL,[Owner] [nvarchar] (128) NULL,[Grantor] [nvarchar] (128) NULL,[Grantee] [nvarchar] (128) NULL,[ObjectNM] [nvarchar] (125) NULL,[Select] [varchar] (16) NULL,[Insert] [varchar] (16) NULL,[Delete] [varchar] (16) NULL,[Update] [varchar] (16) NULL,[Reference] [varchar] (16) NULL,[Execute] [varchar] (16) NULL)

	DECLARE DBNameCR CURSOR FOR SELECT name FROM master..sysdatabases 
	WHERE name NOT IN ('tempdb') AND DATABASEPROPERTYEX(name, 'Status') = 'ONLINE' 
	--AND name like 'Database Name1' --AND name like 'Database Name 2'
	OPEN DBNameCR
	FETCH NEXT FROM DBNameCR INTO @DBName
	WHILE @@FETCH_STATUS = 0
	BEGIN
	SET @SQL = 'EXEC '+@DBName+'..sp_helprotect'
	--PRINT @SQL
	INSERT INTO [##Tbl_helprotect] Exec (@SQL)
	--SELECT * FROM [##Tbl_helprotect] WHERE Owner NOT IN ('sys','.') AND Grantee NOT IN ('public')
	--DROP TABLE [##Tbl_helprotect]
	INSERT INTO ##Tbl_Objects_Perm
	SELECT DISTINCT @@servername AS ServerNM, @DBName AS DatabaseNM,a.Owner,a.Grantor,a.Grantee,a.Object,--g.Action END  AS [Select], b.Action AS [Insert], c.Action AS [Delete], d.Action AS [Update], e.Action AS [References],f.Action AS [Eexecute]
	CASE ISNULL(g.Action,'Yes')WHEN 'Yes' THEN 'O' ELSE g.Action END  AS [Select],
	CASE ISNULL(b.Action,'Yes')WHEN 'Yes' THEN 'O' ELSE b.Action END  AS [Insert],
	CASE ISNULL(c.Action,'Yes')WHEN 'Yes' THEN 'O' ELSE c.Action END  AS [Delete],
	CASE ISNULL(d.Action,'Yes')WHEN 'Yes' THEN 'O' ELSE d.Action END  AS [Update],
	CASE ISNULL(e.Action,'Yes')WHEN 'Yes' THEN 'O' ELSE e.Action END  AS [References],
	CASE ISNULL(f.Action,'Yes')WHEN 'Yes' THEN 'O' ELSE f.Action END  AS [Eexecute]
	from [##Tbl_helprotect] a 
	LEFT OUTER JOIN [##Tbl_helprotect] b ON a.Object = b.Object and a.Grantee = b.Grantee and b.Action = 'Insert'
	LEFT OUTER JOIN [##Tbl_helprotect] c ON a.Object = c.Object and a.Grantee = c.Grantee and c.Action = 'Delete'
	LEFT OUTER JOIN [##Tbl_helprotect] d ON a.Object = d.Object and a.Grantee = d.Grantee and d.Action = 'Update'
	LEFT OUTER JOIN [##Tbl_helprotect] e ON a.Object = e.Object and a.Grantee = e.Grantee and e.Action = 'References'
	LEFT OUTER JOIN [##Tbl_helprotect] f ON a.Object = f.Object and a.Grantee = f.Grantee and f.Action = 'Execute'
	LEFT OUTER JOIN [##Tbl_helprotect] g ON a.Object = g.Object and a.Grantee = g.Grantee and g.Action = 'Select'
	WHERE a.Owner NOT IN ('sys','.') AND a.Grantee NOT IN ('public','guest') --a.Owner NOT IN ('.')
	and @DBName = 'NOA01PDB'
	DELETE FROM ##Tbl_helprotect
	FETCH NEXT FROM DBNameCR INTO @DBName
	END
	CLOSE DBNameCR
	DEALLOCATE DBNameCR
	SELECT * FROM [##Tbl_Objects_Perm]
	DROP TABLE [##Tbl_helprotect]
	DROP TABLE [##Tbl_Objects_Perm]

--User and Group Permissions

	set nocount on
	DECLARE @SQL VARCHAR(2000)
	DECLARE @DBName VARCHAR(100)
	CREATE TABLE [##Tbl_sysusers] ([ServerNM] [nvarchar] (25) NULL,
	[DatabaseNM] [nvarchar] (100) NULL,[UserNM] [nvarchar] (100) NULL,[GroupNM] [nvarchar] (50) NULL,
	[isSQLRole]  [nchar]    (1)   NULL)
	DECLARE DBNameCR CURSOR FOR SELECT name FROM master..sysdatabases
	OPEN DBNameCR
	FETCH NEXT FROM DBNameCR INTO @DBName
	WHILE @@FETCH_STATUS = 0
	BEGIN
	SET @SQL = --'EXEC '+@DBName+'..sp_helpuser'
	'SELECT @@ServerName AS ServerNM,'''+@DBName+''' AS DatabaseNM,A.name AS User_NM,B.name AS Database_Role, A.issqlrole as isSQLRole FROM ['+@DBName+']..sysusers A INNER JOIN ['+@DBName+']..sysmembers C ON A.uid = C.memberuid INNER JOIN ['+@DBName+']..sysusers B ON C.groupuid = B.uid
	UNION
	SELECT @@ServerName AS ServerNM,'''+@DBName+''' AS DatabaseNM,A.name AS User_NM,B.name AS Database_Role, A.issqlrole as isSQLRole FROM ['+@DBName+']..sysusers A INNER JOIN ['+@DBName+']..sysusers B ON A.altuid = B.uid WHERE A.isaliased = 1'
	--PRINT @SQL
	INSERT INTO [##Tbl_sysusers] Exec (@SQL)
	FETCH NEXT FROM DBNameCR INTO @DBName
	END
	CLOSE DBNameCR
	DEALLOCATE DBNameCR
	SELECT ServerNM,DatabaseNM,UserNM,GroupNM, isSQLRole FROM [##Tbl_sysusers]
	DROP TABLE [##Tbl_sysusers]