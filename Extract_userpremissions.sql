DECLARE @DatabaseUserName [sysname] 
SET NOCOUNT ON
DECLARE
@errStatement [varchar](8000),
@msgStatement [varchar](8000),
@DatabaseUserID [smallint],
@ServerUserName [sysname],
@RoleName [varchar](8000),
@MEmberName [varchar](8000),
@ObjectID [int],
@ObjectName [varchar](8000),
@obectpermissions [varchar](8000),
@schemamembername [varchar](8000),
@schemaname [varchar](8000),
@db_permissions varchar(8000)
PRINT '-- CREATE USERS --'
DECLARE _users
CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR 
select [master].[sys].[server_principals].[name] ,
[sys].[database_principals].[name]
from [sys].[database_principals] INNER JOIN [master].[sys].[server_principals]
on [sys].[database_principals].[name]=[master].[sys].[server_principals].[name]
where [master].[sys].[server_principals].[type] in ('U', 'G', 'S')

OPEN _users FETCH NEXT FROM _users INTO @ServerUserNAme, @DatabaseUserName
WHILE @@FETCH_STATUS = 0
BEGIN
SET @msgStatement ='if not exists(SELECT 1 from sys.database_principals where type in (''U'', ''G'', ''S'') and name ='''
+@DatabaseUserName+''' ) '+ CHAR(13) +
'BEGIN '+ CHAR(13) +
'CREATE USER ['+ @DatabaseUserName + ']' + ' FOR LOGIN [' + @ServerUserName + ']'+ CHAR(13) +
'END'
--SET @msgStatement = 'CREATE USER [' --CREATE USER [mlapenna] FOR LOGIN [mlapenna]
-- + @DatabaseUserName + ']' + ' FOR LOGIN [' + @ServerUserName + ']' 
 PRINT @msgStatement
FETCH NEXT FROM _users INTO @ServerUserNAme, @DatabaseUserNAme
END
CLOSE _users
DEALLOCATE _users

PRINT '-- CREATE DB ROLES--'
DECLARE _roles
CURSOR LOCAL FORWARD_ONLY READ_ONLY 
 FOR
select [NAME] from [sys].[database_principals] where type='R' and is_fixed_role != 1 and name not like 'public'
OPEN _roles FETCH NEXT FROM _roles INTO @RoleName
WHILE @@FETCH_STATUS=0
BEGIN
SET @msgStatement ='if not exists(SELECT 1 from sys.database_principals where type=''R'' and name ='''
+@RoleName+''' ) '+ CHAR(13) +
'BEGIN '+ CHAR(13) +
'CREATE ROLE ['+ @RoleName + ']'+CHAR(13) +
'END'
PRINT @msgStatement
FETCH NEXT FROM _roles INTO @RoleName
END
CLOSE _roles
DEALLOCATE _roles
PRINT '-- CREATE APPLICATION ROLES--'
DECLARE _roles
CURSOR LOCAL FORWARD_ONLY READ_ONLY 
FOR
select [NAME],default_schema_name from [sys].[database_principals] where type='A' and is_fixed_role != 1 and name not like 'public'
OPEN _roles FETCH NEXT FROM _roles INTO @RoleName, @schemaname
WHILE @@FETCH_STATUS=0
BEGIN
SET @msgStatement ='if not exists(SELECT 1 from sys.database_principals where type=''A'' and name ='''
+@RoleName+''' ) '+ CHAR(13) +
'BEGIN '+ CHAR(13) +
'CREATE APPLICATION ROLE ['+ @RoleName + '] with DEFAULT_SCHEMA =['+@schemaname +'], PASSWORD = ''{Please provide the password here}'''+CHAR(13) +
'END'
PRINT @msgStatement
FETCH NEXT FROM _roles INTO @RoleName, @schemaname
END
CLOSE _roles
DEALLOCATE _roles
PRINT '-- ADD ROLE MEMBERS--'
DECLARE _role_members
CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR 
 SELECT a.name , b.name 
 from sys.database_role_members d INNER JOIN sys.database_principals a
 on d.role_principal_id=a.principal_id 
 INNER JOIN sys.database_principals b
 on d.member_principal_id=b.principal_id
 where b.name <> 'dbo'
 order by 1,2
OPEN _role_members FETCH NEXT FROM _role_members INTO @RoleName, @membername
WHILE @@FETCH_STATUS = 0
BEGIN
SET @msgStatement = 'EXEC [sp_addrolemember] ' + '@rolename = [' + @RoleName + '], ' + '@membername = [' + @membername + ']'
PRINT @msgStatement
FETCH NEXT FROM _role_members INTO @RoleName, @membername
END
close _role_members
deallocate _role_members
--SCRIPT GRANTS for Database Privileges
PRINT '-- SCRIPT GRANTS for Database Privileges--'
 DECLARE _db_permissions
 CURSOR LOCAL FORWARD_ONLY READ_ONLY
 FOR 
 SELECT a.state_desc + ' ' + a.permission_name + ' ' + 'TO [' + b.name + ']' COLLATE LATIN1_General_CI_AS
 FROM sys.database_permissions a inner join sys.database_principals b
 ON a.grantee_principal_id = b.principal_id 
 WHERE b.principal_id not in (0,1,2) and a.type not in ('CO') and a.class = 0
 OPEN _db_permissions FETCH NEXT FROM _db_permissions INTO @db_permissions
 WHILE @@FETCH_STATUS = 0
 BEGIN
 PRINT @db_permissions
 FETCH NEXT FROM _db_permissions INTO @db_permissions
 END
 close _db_permissions
 deallocate _db_permissions

-- SCRIPT GRANTS for Schema Privileges
PRINT '-- SCRIPT GRANTS for Schema Privileges--'
DECLARE _schema_members
 CURSOR LOCAL FORWARD_ONLY READ_ONLY
 FOR 
 SELECT a.state_desc + ' ' + a.permission_name + ' ' + 'ON SCHEMA::[' + b.name + ']' + ' TO ' + c.name COLLATE LATIN1_General_CI_AS
 FROM sys.database_permissions a INNER JOIN sys.schemas b
 ON a.major_id = b.schema_id INNER JOIN sys.database_principals c ON a.grantee_principal_id = c.principal_id
 OPEN _schema_members FETCH NEXT FROM _schema_members INTO @schemamembername
 WHILE @@FETCH_STATUS = 0
 BEGIN
 PRINT @schemamembername
 FETCH NEXT FROM _schema_members INTO @schemamembername
 END
 close _schema_members
 deallocate _schema_members

-- SCRIPT GRANTS for Objects Level Privilegs
PRINT '-- SCRIPT GRANTS for Object Privileges--'
DECLARE _object_permissions
CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR 
 SELECT
state_desc + ' ' + permission_name + ' on ['+ sys.schemas.name + '].[' + sys.objects.name + '] to [' + sys.database_principals.name + ']' COLLATE LATIN1_General_CI_AS
from sys.database_permissions
join sys.objects on sys.database_permissions.major_id = 
 sys.objects.object_id
join sys.schemas on sys.objects.schema_id = sys.schemas.schema_id
join sys.database_principals on sys.database_permissions.grantee_principal_id = 
 sys.database_principals.principal_id
where sys.database_principals.name not in ( 'public', 'guest')
--order by 1, 2, 3, 5
OPEN _object_permissions FETCH NEXT FROM _object_permissions INTO @obectpermissions
 WHILE @@FETCH_STATUS = 0
BEGIN
PRINT @obectpermissions
FETCH NEXT FROM _object_permissions INTO @obectpermissions
END
 close _object_permissions
 deallocate _object_permissions
PRINT 'GO'