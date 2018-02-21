USE [master]
GO

CREATE PROCEDURE sp_CloneRights (
    @oldUser sysname, --Old user from which to copy right
    @newUser sysname, --New user to which copy rights
    @printOnly bit = 1, --When 1 then only script is printed on screen, when 0 then also script is executed, when NULL, script is only executed and not printed
    @NewLoginName sysname = NULL --When a NewLogin name is provided also a creation of user is part of the final script
)
AS
BEGIN
    SET NOCOUNT ON
 
    CREATE TABLE #output (
        command nvarchar(4000)
    )
 
    DECLARE
        @command nvarchar(4000),
        @sql nvarchar(max),
        @dbName nvarchar(128),
        @msg nvarchar(max)
 
    SELECT
        @sql = N'',
        @dbName = QUOTENAME(DB_NAME())
 
    IF (NOT EXISTS(SELECT 1 FROM sys.database_principals where name = @oldUser))
    BEGIN
        SET @msg = 'Source user ' + QUOTENAME(@oldUser) + ' doesn''t exists in database ' + @dbName
        RAISERROR(@msg, 11,1)
        RETURN
    END   
 
    INSERT INTO #output(command)
    SELECT '--Database Context' AS command UNION ALL
    SELECT    'USE' + SPACE(1) + @dbName UNION ALL
    SELECT 'SET XACT_ABORT ON'
 
    IF (ISNULL(@NewLoginName, '') <> '')
    BEGIN
        SET @sql = N'USE ' + @dbName + N';
        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @newUser)
        BEGIN
            INSERT INTO #output(command)
            SELECT ''--Create user'' AS command
 
            INSERT INTO #output(command)
            SELECT
                ''CREATE USER '' + QUOTENAME(@NewUser) + '' FOR LOGIN '' + QUOTENAME(@NewLoginName) +
                    CASE WHEN ISNULL(default_schema_name, '''') <> '''' THEN '' WITH DEFAULT_SCHEMA = '' + QUOTENAME(dp.default_schema_name)
                        ELSE ''''
                    END AS Command
            FROM sys.database_principals dp
            INNER JOIN sys.server_principals sp ON dp.sid = sp.sid
            WHERE dp.name = @OldUser
        END'
 
        EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @NewLoginName sysname', @OldUser = @OldUser, @NewUser = @NewUser, @NewLoginName=@NewLoginName
    END
 
    INSERT INTO #output(command)
    SELECT    '--Cloning permissions from' + SPACE(1) + QUOTENAME(@OldUser) + SPACE(1) + 'to' + SPACE(1) + QUOTENAME(@NewUser)
 
    INSERT INTO #output(command)
    SELECT '--Role Memberships' AS command
 
    SET @sql = N'USE ' + @dbName + N';
    INSERT INTO #output(command)
    SELECT ''EXEC sp_addrolemember @rolename =''
        + SPACE(1) + QUOTENAME(USER_NAME(rm.role_principal_id), '''''''') + '', @membername ='' + SPACE(1) + QUOTENAME(@NewUser, '''''''') AS command
    FROM    sys.database_role_members AS rm
    WHERE    USER_NAME(rm.member_principal_id) = @OldUser
    ORDER BY rm.role_principal_id ASC'
 
    EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname', @OldUser = @OldUser, @NewUser = @NewUser
 
    INSERT INTO #output(command)
    SELECT '--Object Level Permissions'
 
    SET @sql = N'USE ' + @dbName + N';
    INSERT INTO #output(command)
    SELECT    CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
        + SPACE(1) + perm.permission_name + SPACE(1) + ''ON '' + QUOTENAME(SCHEMA_NAME(obj.schema_id)) + ''.'' + QUOTENAME(obj.name)
        + CASE WHEN cl.column_id IS NULL THEN SPACE(0) ELSE ''('' + QUOTENAME(cl.name) + '')'' END
        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
    FROM    sys.database_permissions AS perm
        INNER JOIN
        sys.objects AS obj
        ON perm.major_id = obj.[object_id]
        INNER JOIN
        sys.database_principals AS usr
        ON perm.grantee_principal_id = usr.principal_id
        LEFT JOIN
        sys.columns AS cl
        ON cl.column_id = perm.minor_id AND cl.[object_id] = perm.major_id
    WHERE    usr.name = @OldUser
    ORDER BY perm.permission_name ASC, perm.state_desc ASC'
 
    EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname', @OldUser = @OldUser, @NewUser = @NewUser
 
    INSERT INTO #output(command)
    SELECT N'--Database Level Permissions'
 
    SET @sql = N'USE ' + @dbName + N';
    INSERT INTO #output(command)
    SELECT    CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
        + SPACE(1) + perm.permission_name + SPACE(1)
        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
    FROM    sys.database_permissions AS perm
        INNER JOIN
        sys.database_principals AS usr
        ON perm.grantee_principal_id = usr.principal_id
    WHERE    usr.name = @OldUser
    AND    perm.major_id = 0
    ORDER BY perm.permission_name ASC, perm.state_desc ASC'
 
    EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname', @OldUser = @OldUser, @NewUser = @NewUser
 
    DECLARE cr CURSOR FOR
        SELECT command FROM #output
 
    OPEN cr
 
    FETCH NEXT FROM cr INTO @command
 
    SET @sql = ''
 
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF (@printOnly IS NOT NULL)
            PRINT @command
 
        SET @sql = @sql + @command + CHAR(13) + CHAR(10)
        FETCH NEXT FROM cr INTO @command
    END
 
    CLOSE cr
    DEALLOCATE cr
 
    IF (@printOnly IS NULL OR @printOnly = 0)
        EXEC (@sql)
 
    DROP TABLE #output
END
GO
EXECUTE sp_ms_marksystemobject 'dbo.sp_CloneRights'
GO




/* need to execute below
USE [msdb]
GO
EXEC sp_CloneRights 'db_ssisadmin', 'NewUser'
*/

--https://pawlowski.cz/2011/03/31/cloning-user-rights-database/