IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[usp_logins]') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[usp_logins]
GO

CREATE PROCEDURE [dbo].[usp_logins] @login_name sysname = NULL, @dbname sysname = NULL
--WITH ENCRYPTION
AS
--
--  Generates all logins and their respective server roles. Does not deal with CERTIFICATE_MAPPED_LOGIN and ASYMMETRIC_KEY_MAPPED_LOGIN types
-- 
--  2013-01-11 - Fixed issue with permission syntax depending on version.
--
--  2013-03-18 - Added options for access.
--
--  All users: EXEC usp_logins 
-- 
--  One user, All DBs: EXEC usp_logins '<User>'
--
--  One user, One DB: EXEC usp_logins '<User>', '<DBName>'
--
--  All users, One DB: EXEC usp_logins NULL, '<DBName>'
--
SET NOCOUNT ON;
DECLARE @sqlmajorver int
DECLARE @name sysname, @type CHAR (1), @hasaccess tinyint, @is_disabled int, @sysadmin int, @sqlcur VARCHAR(4000)
DECLARE @securityadmin int, @serveradmin int, @setupadmin int, @processadmin int, @diskadmin int
DECLARE @dbnamecreator int, @bulkadmin int, @PWD_varbinary  VARBINARY(256), @PWD_string  VARCHAR (514)
DECLARE @SID_varbinary VARBINARY(85), @SID_string VARCHAR(100), @tmpstr VARCHAR(1024), @tmpstr2 VARCHAR(8000)
DECLARE @is_policy_checked VARCHAR(3), @is_expiration_checked VARCHAR(3), @charvalue VARCHAR(256)
DECLARE @i int, @length int, @hexstring CHAR(16), @tempint int, @firstint int, @secondint int, @defaultdb sysname

SELECT @sqlmajorver = CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff);

--Orphaned users will not be scripted
IF @login_name IS NOT NULL AND @dbname IS NULL
	SET @sqlcur = 'DECLARE login_curs CURSOR FAST_FORWARD FOR SELECT p.sid, p.name, p.type, l.password_hash, p.is_disabled, p.default_database_name, CASE WHEN sp.type = ''COSQ'' AND [state] = ''G'' THEN 1 WHEN sp.type = ''COSQ'' AND [state] = ''D'' THEN 2 ELSE 0 END AS hasaccess, IS_SRVROLEMEMBER(''sysadmin'', p.name), IS_SRVROLEMEMBER(''securityadmin'', p.name), IS_SRVROLEMEMBER(''serveradmin'', p.name), IS_SRVROLEMEMBER(''setupadmin'', p.name), IS_SRVROLEMEMBER(''processadmin'', p.name), IS_SRVROLEMEMBER(''diskadmin'', p.name), IS_SRVROLEMEMBER(''dbcreator'', p.name), IS_SRVROLEMEMBER(''bulkadmin'', p.name)
FROM sys.server_principals p 
LEFT JOIN sys.server_permissions sp ON p.principal_id = sp.grantee_principal_id and sp.type = ''COSQ''
LEFT JOIN sys.sql_logins l ON (l.sid = p.sid) 
WHERE p.type IN (''S'', ''G'', ''U'') AND p.name = ''' + @login_name + '''
ORDER BY p.default_database_name'
ELSE IF @login_name IS NULL AND @dbname IS NOT NULL
	SET @sqlcur = 'DECLARE login_curs CURSOR FAST_FORWARD FOR SELECT p.sid, p.name, p.type, l.password_hash, p.is_disabled, p.default_database_name, CASE WHEN sp.type = ''COSQ'' AND [state] = ''G'' THEN 1 WHEN sp.type = ''COSQ'' AND [state] = ''D'' THEN 2 ELSE 0 END AS hasaccess, IS_SRVROLEMEMBER(''sysadmin'', p.name), IS_SRVROLEMEMBER(''securityadmin'', p.name), IS_SRVROLEMEMBER(''serveradmin'', p.name), IS_SRVROLEMEMBER(''setupadmin'', p.name), IS_SRVROLEMEMBER(''processadmin'', p.name), IS_SRVROLEMEMBER(''diskadmin'', p.name), IS_SRVROLEMEMBER(''dbcreator'', p.name), IS_SRVROLEMEMBER(''bulkadmin'', p.name)
FROM sys.server_principals p 
INNER JOIN ' + @dbname + '.sys.database_principals dp ON p.sid = dp.sid 
LEFT JOIN sys.server_permissions sp ON p.principal_id = sp.grantee_principal_id and sp.type = ''COSQ''
LEFT JOIN sys.sql_logins l ON (l.sid = p.sid) 
WHERE p.type IN (''S'', ''G'', ''U'') AND p.name <> ''sa''
ORDER BY p.name'
ELSE IF @login_name IS NOT NULL AND @dbname IS NOT NULL
	SET @sqlcur = 'DECLARE login_curs CURSOR FAST_FORWARD FOR SELECT p.sid, p.name, p.type, l.password_hash, p.is_disabled, p.default_database_name, CASE WHEN sp.type = ''COSQ'' AND [state] = ''G'' THEN 1 WHEN sp.type = ''COSQ'' AND [state] = ''D'' THEN 2 ELSE 0 END AS hasaccess, IS_SRVROLEMEMBER(''sysadmin'', p.name), IS_SRVROLEMEMBER(''securityadmin'', p.name), IS_SRVROLEMEMBER(''serveradmin'', p.name), IS_SRVROLEMEMBER(''setupadmin'', p.name), IS_SRVROLEMEMBER(''processadmin'', p.name), IS_SRVROLEMEMBER(''diskadmin'', p.name), IS_SRVROLEMEMBER(''dbcreator'', p.name), IS_SRVROLEMEMBER(''bulkadmin'', p.name)
FROM sys.server_principals p 
INNER JOIN ' + @dbname + '.sys.database_principals dp ON p.sid = dp.sid 
LEFT JOIN sys.server_permissions sp ON p.principal_id = sp.grantee_principal_id and sp.type = ''COSQ''
LEFT JOIN sys.sql_logins l ON (l.sid = p.sid) 
WHERE p.type IN (''S'', ''G'', ''U'') AND p.name = ''' + @login_name + ''''
ELSE
	SET @sqlcur = 'DECLARE login_curs CURSOR FAST_FORWARD FOR SELECT p.sid, p.name, p.type, l.password_hash, p.is_disabled, p.default_database_name, CASE WHEN sp.type = ''COSQ'' AND [state] = ''G'' THEN 1 WHEN sp.type = ''COSQ'' AND [state] = ''D'' THEN 2 ELSE 0 END AS hasaccess, IS_SRVROLEMEMBER(''sysadmin'', p.name), IS_SRVROLEMEMBER(''securityadmin'', p.name), IS_SRVROLEMEMBER(''serveradmin'', p.name), IS_SRVROLEMEMBER(''setupadmin'', p.name), IS_SRVROLEMEMBER(''processadmin'', p.name), IS_SRVROLEMEMBER(''diskadmin'', p.name), IS_SRVROLEMEMBER(''dbcreator'', p.name), IS_SRVROLEMEMBER(''bulkadmin'', p.name)
FROM sys.server_principals p 
LEFT JOIN sys.server_permissions sp ON p.principal_id = sp.grantee_principal_id and sp.type = ''COSQ''
LEFT JOIN sys.sql_logins l ON (l.sid = p.sid) 
WHERE p.type IN (''S'', ''G'', ''U'') AND p.name <> ''sa''
ORDER BY p.default_database_name, p.name'
EXEC (@sqlcur)
OPEN login_curs
FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @PWD_varbinary, @is_disabled, @defaultdb, @hasaccess, @sysadmin, @securityadmin, @serveradmin, @setupadmin, @processadmin, @diskadmin, @dbnamecreator, @bulkadmin
IF (@@FETCH_STATUS = -1)
BEGIN
  PRINT 'No login(s) found.'
  CLOSE login_curs
  DEALLOCATE login_curs
END
ELSE
BEGIN
	PRINT '/* usp_logins script '
	PRINT '** Generated ' + CONVERT (VARCHAR, GETDATE()) + ' on ' + @@SERVERNAME + ' */' + CHAR(10)
	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
		IF (@@FETCH_STATUS <> -2)
			BEGIN
			PRINT CHAR(10) + '-- Login: ' + @name + CHAR(10)

			IF (@type IN ('G', 'U'))
				BEGIN -- NT authenticated account/group
					SET @tmpstr = 'USE master;' + CHAR(10) + 'CREATE LOGIN ' + QUOTENAME(@name) + ' FROM WINDOWS WITH DEFAULT_DATABASE = [' + @defaultdb + '];'
				END
			ELSE IF (@type IN ('S'))
				BEGIN -- SQL Server authentication
					-- obtain password and sid
					SELECT @PWD_string = master.sys.fn_varbintohexstr(@PWD_varbinary)
					SELECT @SID_string = master.sys.fn_varbintohexstr(@SID_varbinary)
		 
					-- obtain password policy state
					SELECT @is_policy_checked = CASE is_policy_checked WHEN 1 THEN 'ON' WHEN 0 THEN 'OFF' ELSE NULL END FROM sys.sql_logins WHERE name = @name
					SELECT @is_expiration_checked = CASE is_expiration_checked WHEN 1 THEN 'ON' WHEN 0 THEN 'OFF' ELSE NULL END FROM sys.sql_logins WHERE name = @name
		 
					SET @tmpstr = 'USE master;' + CHAR(10) + 'CREATE LOGIN ' + QUOTENAME( @name ) + ' WITH PASSWORD = ' + @PWD_string + ' HASHED, SID = ' + @SID_string + ', DEFAULT_DATABASE = [' + @defaultdb + ']'

					IF (@is_policy_checked IS NOT NULL)
					BEGIN
					  SET @tmpstr = @tmpstr + ', CHECK_POLICY = ' + @is_policy_checked
					END
					IF (@is_expiration_checked IS NOT NULL)
					BEGIN
					  SET @tmpstr = @tmpstr + ', CHECK_EXPIRATION = ' + @is_expiration_checked
					END
				END
			IF (@hasaccess = 0)
			BEGIN -- login exists but does not have access
			  SET @tmpstr = @tmpstr + CHAR(10) + 'REVOKE CONNECT SQL TO ' + QUOTENAME(@name) + ';'
			END
			ELSE IF (@hasaccess = 2)
			BEGIN -- login is denied access
			  SET @tmpstr = @tmpstr + CHAR(10) + 'DENY CONNECT SQL TO ' + QUOTENAME(@name) + ';'
			END
			ELSE IF (@hasaccess = 1)
			BEGIN -- login has access
			  SET @tmpstr = @tmpstr + CHAR(10) + 'GRANT CONNECT SQL TO ' + QUOTENAME(@name) + ';'
			END
			IF (@is_disabled = 1)
			BEGIN -- login is disabled
			  SET @tmpstr = @tmpstr + CHAR(10) + 'ALTER LOGIN ' + QUOTENAME( @name ) + ' DISABLE;'
			END
			PRINT @tmpstr
			PRINT ''
			
			IF @sysadmin = 1 AND @sqlmajorver > 9
				BEGIN
					SET @tmpstr2 = CHAR(10) + 'ALTER SERVER ROLE sysadmin ADD MEMBER ' + QUOTENAME(@name) + ';'
				END					
			ELSE IF @sysadmin = 1 AND @sqlmajorver = 9
				BEGIN
					SET @tmpstr2 = CHAR(10) + 'EXEC sp_addsrvrolemember N' + CHAR(39) + @name + CHAR(39) + ', N''sysadmin'';'
				END	
			ELSE
				BEGIN
					IF @sqlmajorver > 9
					BEGIN
					SET @tmpstr2 = ''
						IF @securityadmin = 1 SET @tmpstr2 = CHAR(10) + 'ALTER SERVER ROLE securityadmin ADD MEMBER ' + QUOTENAME(@name) + ';'
						IF @serveradmin = 1 SET @tmpstr2 = @tmpstr2 + CHAR(10) + 'ALTER SERVER ROLE serveradmin ADD MEMBER ' + QUOTENAME(@name) + ';'
						IF @setupadmin = 1 SET @tmpstr2 = @tmpstr2 + CHAR(10) + 'ALTER SERVER ROLE setupadmin ADD MEMBER ' + QUOTENAME(@name) + ';'
						IF @processadmin = 1 SET @tmpstr2 = @tmpstr2 + CHAR(10) + 'ALTER SERVER ROLE processadmin ADD MEMBER ' + QUOTENAME(@name) + ';'
						IF @diskadmin = 1 SET @tmpstr2 = @tmpstr2 + CHAR(10) + 'ALTER SERVER ROLE diskadmin ADD MEMBER ' + QUOTENAME(@name) + ';'
						IF @dbnamecreator = 1 SET @tmpstr2 = @tmpstr2 + CHAR(10) + 'ALTER SERVER ROLE dbcreator ADD MEMBER ' + QUOTENAME(@name) + ';'
						IF @bulkadmin = 1 SET @tmpstr2 = @tmpstr2 + CHAR(10) + 'ALTER SERVER ROLE bulkadmin ADD MEMBER ' + QUOTENAME(@name) + ';'
					END
					ELSE IF @sqlmajorver = 9
					BEGIN
					SET @tmpstr2 = ''
						IF @securityadmin = 1 SET @tmpstr2 = CHAR(10) + 'EXEC sp_addsrvrolemember N' + CHAR(39) + @name + CHAR(39) + ', N''securityadmin'';'
						IF @serveradmin = 1 SET @tmpstr2 = @tmpstr2 + CHAR(10) + 'EXEC sp_addsrvrolemember N' + CHAR(39) + @name + CHAR(39) + ', N''serveradmin'';'
						IF @setupadmin = 1 SET @tmpstr2 = @tmpstr2 + CHAR(10) + 'EXEC sp_addsrvrolemember N' + CHAR(39) + @name + CHAR(39) + ', N''setupadmin'';'
						IF @processadmin = 1 SET @tmpstr2 = @tmpstr2 + CHAR(10) + 'EXEC sp_addsrvrolemember N' + CHAR(39) + @name + CHAR(39) + ', N''processadmin'';'
						IF @diskadmin = 1 SET @tmpstr2 = @tmpstr2 + CHAR(10) + 'EXEC sp_addsrvrolemember N' + CHAR(39) + @name + CHAR(39) + ', N''diskadmin'';'
						IF @dbnamecreator = 1 SET @tmpstr2 = @tmpstr2 + CHAR(10) + 'EXEC sp_addsrvrolemember N' + CHAR(39) + @name + CHAR(39) + ', N''dbcreator'';'
						IF @bulkadmin = 1 SET @tmpstr2 = @tmpstr2 + CHAR(10) + 'EXEC sp_addsrvrolemember N' + CHAR(39) + @name + CHAR(39) + ', N''bulkadmin'';'
					END
				END

			IF @tmpstr2 <> ''
			BEGIN
				PRINT '-- Login: ' + @name + ' - Server roles'
				PRINT @tmpstr2
			END
		END
		DECLARE @SC NVARCHAR(4000)
		IF @dbname IS NULL
		BEGIN
			SET @SC = 'USE [?]; 
SET NOCOUNT ON;
DECLARE @msgStatement VARCHAR(8000), @DatabaseUserID smallint, @dbnameUserName sysname, @ServerUserName sysname, @RoleName VARCHAR(8000), @is_fixed_role bit
SELECT @DatabaseUserID = dp.principal_id, @ServerUserName = QUOTENAME(sp.name), @dbnameUserName = dp.name
FROM sys.database_principals dp INNER JOIN sys.server_principals sp
ON dp.sid = sp.sid
WHERE QUOTENAME(sp.name) COLLATE database_default = ''' + QUOTENAME(@name) + '''

SELECT @msgStatement = CHAR(13) + ''USE [?];'' + CHAR(13) + 
	CASE WHEN @dbnameUserName <> ''dbo'' THEN ''CREATE USER '' + QUOTENAME(@dbnameUserName) + '' FOR LOGIN '' + @ServerUserName END + '';'' + CHAR(13)
DECLARE _sysusers CURSOR LOCAL FORWARD_ONLY READ_ONLY FOR
SELECT [name], [is_fixed_role] FROM sys.database_principals WHERE principal_id IN (SELECT role_principal_id FROM sys.database_role_members WHERE member_principal_id = @DatabaseUserID) AND [name] IS NOT NULL
OPEN _sysusers
FETCH NEXT FROM _sysusers INTO @RoleName, @is_fixed_role
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @msgStatement = @msgStatement + 
		CASE WHEN @dbnameUserName = ''dbo'' THEN ''ALTER AUTHORIZATION ON SCHEMA::dbo TO '' + QUOTENAME(@dbnameUserName)
			WHEN @dbnameUserName <> ''dbo'' AND @is_fixed_role = 1 THEN ''EXEC sp_addrolemember N'' + CHAR(39) + @RoleName + CHAR(39) + '', N'' + CHAR(39) + @dbnameUserName + CHAR(39) + ''''
			WHEN @dbnameUserName <> ''dbo'' AND @is_fixed_role = 0 AND CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff) = 9 THEN ''EXEC sp_addrolemember N'' + CHAR(39) + @RoleName + CHAR(39) + '', N'' + CHAR(39) + @dbnameUserName + CHAR(39) + ''''
		ELSE ''ALTER ROLE '' + @RoleName + '' ADD MEMBER '' + QUOTENAME(@dbnameUserName) END + '';'' + CHAR(10)
FETCH NEXT FROM _sysusers INTO @RoleName, @is_fixed_role
END
IF RTRIM(@msgStatement) <> '''' 
BEGIN PRINT CHAR(10) + ''-- Login: ' + @name + ' - Databases login and roles''
PRINT @msgStatement END'
		EXEC master.dbo.sp_MSforeachdb @command1= @SC
		END
		ELSE 
		BEGIN
			SET @SC = 'USE [' + @dbname + ']; 
SET NOCOUNT ON;
DECLARE @msgStatement VARCHAR(8000), @DatabaseUserID smallint, @dbnameUserName sysname, @ServerUserName sysname, @RoleName VARCHAR(8000), @is_fixed_role bit
SELECT @DatabaseUserID = dp.principal_id, @ServerUserName = QUOTENAME(sp.name), @dbnameUserName = dp.name
FROM sys.database_principals dp INNER JOIN sys.server_principals sp
ON dp.sid = sp.sid
WHERE QUOTENAME(sp.name) COLLATE database_default = ''' + QUOTENAME(@name) + '''

SELECT @msgStatement = CHAR(13) + ''USE [' + @dbname + '];'' + CHAR(13) + 
	CASE WHEN @dbnameUserName <> ''[dbo]'' THEN ''CREATE USER '' + QUOTENAME(@dbnameUserName) + '' FOR LOGIN '' + @ServerUserName END + '';'' + CHAR(13)
DECLARE _sysusers CURSOR LOCAL FORWARD_ONLY READ_ONLY FOR
SELECT [name], [is_fixed_role] FROM sys.database_principals WHERE principal_id IN (SELECT role_principal_id FROM sys.database_role_members WHERE member_principal_id = @DatabaseUserID) AND [name] IS NOT NULL
OPEN _sysusers
FETCH NEXT FROM _sysusers INTO @RoleName, @is_fixed_role
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @msgStatement = @msgStatement + 
		CASE WHEN @dbnameUserName = ''dbo'' THEN ''ALTER AUTHORIZATION ON SCHEMA::dbo TO '' + QUOTENAME(@dbnameUserName)
			WHEN @dbnameUserName <> ''dbo'' AND @is_fixed_role = 1 THEN ''EXEC sp_addrolemember N'' + CHAR(39) + @RoleName + CHAR(39) + '', N'' + CHAR(39) + @dbnameUserName + CHAR(39) + ''''
			WHEN @dbnameUserName <> ''dbo'' AND @is_fixed_role = 0 AND CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff) = 9 THEN ''EXEC sp_addrolemember N'' + CHAR(39) + @RoleName + CHAR(39) + '', N'' + CHAR(39) + @dbnameUserName + CHAR(39) + ''''
		ELSE ''ALTER ROLE '' + @RoleName + '' ADD MEMBER '' + QUOTENAME(@dbnameUserName) END + '';'' + CHAR(10)
FETCH NEXT FROM _sysusers INTO @RoleName, @is_fixed_role
END
IF RTRIM(@msgStatement) <> '''' 
BEGIN PRINT CHAR(10) + ''-- Login: ' + @name + ' - Databases login and roles''
PRINT @msgStatement END'
		EXEC sp_executesql @SC
		END
		FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @PWD_varbinary, @is_disabled, @defaultdb, @hasaccess, @sysadmin, @securityadmin, @serveradmin, @setupadmin, @processadmin, @diskadmin, @dbnamecreator, @bulkadmin
	END
	CLOSE login_curs
	DEALLOCATE login_curs
END
GO
