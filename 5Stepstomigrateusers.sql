---Server Level Security

SELECT  sp.state_desc,
    sp.permission_name,
    principal_name = QUOTENAME(spl.name),
spl.type_desc,
    sp.state_desc + N' ' + sp.permission_name + N' TO ' + cast(QUOTENAME(spl.name COLLATE DATABASE_DEFAULT) as nvarchar(256)) AS "T-SQL Script"
FROM sys.server_permissions sp
inner join sys.server_principals spl on (sp.grantee_principal_id = spl.principal_id)
where spl.name not like '##%' -- skip PBM accounts
and spl.name not in ('dbo', 'sa', 'public')
order by sp.permission_name, spl.name

---Server Level Roles

SELECT  DISTINCT
QUOTENAME(sp.name) AS "ServerRoleName",
sp.type_desc AS "RoleDescription",
QUOTENAME(m.name) AS "PrincipalName",
m.type_desc AS "LoginDescription",
'EXEC master..sp_addsrvrolemember @loginame = N''' + m.name + ''', @rolename = N''' + sp.name + '''' AS "T-SQL Script"
FROM sys.server_role_members AS srm
inner join sys.server_principals sp on (srm.role_principal_id = sp.principal_id)
inner join sys.server_principals m on (srm.member_principal_id = m.principal_id)
where sp.is_disabled = 0
and m.is_disabled = 0
and m.name not in ('dbo', 'sa', 'public')
and m.name <> 'NT AUTHORITY\SYSTEM'

---Database Level Security

SELECT  dp.state_desc,
dp.permission_name,
QUOTENAME(dpl.name)  AS 'principal_name',
 dpl.type_desc,
 dp.state_desc + N' ' + dp.permission_name + N' TO ' + cast(QUOTENAME(dpl.name COLLATE DATABASE_DEFAULT) as nvarchar(500))  AS "T-SQL Script"
FROM sys.database_permissions AS dp
INNER JOIN sys.database_principals AS dpl ON (dp.grantee_principal_id = dpl.principal_id)
WHERE dp.major_id = 0
and dpl.name not like '##%' -- excluds PBM accounts
and dpl.name not in ('dbo', 'sa', 'public')
ORDER BY dp.permission_name ASC, dp.state_desc ASC

---Database Level Roles

SELECT DISTINCT
QUOTENAME(drole.name) as "DatabaseRoleName",
drole.type_desc,
QUOTENAME(dp.name) as "PrincipalName",
dp.type_desc,
'EXEC sp_addrolemember @membername = N''' + dp.name COLLATE DATABASE_DEFAULT + ''', @rolename = N''' + drole.name + '''' AS "T-SQL Script"
FROM sys.database_role_members AS drm
inner join sys.database_principals drole on (drm.role_principal_id = drole.principal_id)
inner join sys.database_principals dp on (drm.member_principal_id = dp.principal_id)
where dp.name not in ('dbo', 'sa', 'public')


---Database Level Explicit Permissions

SELECT    dp.state_desc AS "StateDescription" ,
dp.permission_name AS "PermissionName" ,
SCHEMA_NAME(obj.schema_id) AS [Schema Name],
obj.NAME AS [Object Name],
QUOTENAME(SCHEMA_NAME(obj.schema_id)) + '.' + QUOTENAME(obj.name)    + CASE WHEN col.column_id IS NULL THEN SPACE(0)           ELSE '(' + QUOTENAME(col.name COLLATE DATABASE_DEFAULT) + ')'      END AS "ObjectName" ,
QUOTENAME(dpl.name COLLATE database_default) AS "UserName" ,
dpl.type_Desc AS "UserRoleType" ,
obj.type_desc AS "ObjectType" ,
dp.state_desc + N' ' + dp.permission_name + N' ON '    + QUOTENAME(SCHEMA_NAME(obj.schema_id)) + '.' + QUOTENAME(obj.name)    + N' TO ' + QUOTENAME(dpl.name COLLATE database_default) AS "T-SQL Script"
FROM    sys.database_permissions AS dp
INNER JOIN sys.objects AS obj ON ( dp.major_id = obj.[object_id] )
INNER JOIN sys.database_principals AS dpl ON ( dp.grantee_principal_id = dpl.principal_id )
LEFT JOIN sys.columns AS col ON ( col.column_id = dp.minor_id  AND col.[object_id] = dp.major_id)
WHERE    obj.name NOT LIKE 'dt%'
AND obj.is_ms_shipped = 0
AND dpl.name NOT IN ( 'dbo', 'sa', 'public' )
ORDER BY    dp.permission_name ASC ,    dp.state_desc ASC



create table #temp (sqlText varchar(500))
declare @db varchar(100), @sql nvarchar(max)

INSERT INTO #temp
SELECT 'USE master'

INSERT INTO #temp
SELECT sp.state_desc + N' ' + sp.permission_name + N' TO ' + cast(QUOTENAME(spl.name COLLATE DATABASE_DEFAULT) as nvarchar(256)) AS "T-SQL Script"
FROM sys.server_permissions sp
inner join sys.server_principals spl on (sp.grantee_principal_id = spl.principal_id)
where spl.name not like '##%' -- skip PBM accounts
and spl.name not in ('dbo', 'sa', 'public')
and spl.name not like ('%nt service%')
order by sp.permission_name, spl.name



Select * from #temp