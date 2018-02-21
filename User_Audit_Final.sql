DECLARE @DB_USers TABLE
(DBName sysname, UserName sysname, LoginType sysname, AssociatedRole varchar(max),create_date datetime,modify_date datetime,is_disabled varchar(max),is_expired varchar(max),is_locked varchar(max))

INSERT @DB_USers
EXEC sp_MSforeachdb
'
use [?]
SELECT ''?'' AS DB_Name,
case prin.name when ''dbo'' then prin.name + '' (''+ (select SUSER_SNAME(owner_sid) from master.sys.databases where name =''?'') + '')'' else prin.name end AS UserName,
prin.type_desc AS LoginType,
isnull(USER_NAME(mem.role_principal_id),'''') AS AssociatedRole ,prin.create_date,prin.modify_date
       ,sp.is_disabled
       ,CAST(LoginProperty(sp.name, ''IsExpired'') AS INT) is_expired
       ,CAST(LoginProperty(sp.name, ''IsLocked'') AS INT) is_locked
from sys.database_principals prin 
left outer join sys.database_role_members mem on mem.member_principal_id=prin.principal_id
left outer join sys.server_principals sp on prin.principal_id=sp.principal_id
WHERE prin.sid IS NOT NULL and prin.sid NOT IN (0x00) and 
prin.is_fixed_role <> 1 AND prin.name NOT LIKE ''##%'''

SELECT
dbname,username ,logintype ,create_date ,modify_date, is_disabled,is_expired,is_locked,
STUFF(
(
SELECT ',' + CONVERT(VARCHAR(500),associatedrole)
FROM @DB_USers user2
WHERE
user1.DBName=user2.DBName AND user1.UserName=user2.UserName
FOR XML PATH('')
)
,1,1,'') AS Permissions_user
FROM @DB_USers user1
GROUP BY
dbname,username ,logintype ,create_date ,modify_date, is_disabled,is_expired,is_locked
ORDER BY DBName,username
