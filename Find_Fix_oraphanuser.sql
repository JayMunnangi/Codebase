USE MASTER
GO
SET NoCount ON
DECLARE @VarDbId INT,
@SQL nvarchar(4000),
@VDBName nvarchar(260),
@OUCounter INT,
@Max_OUCounter INT
SELECT @VarDbId=4,
@SQL =''
CREATE TABLE #OrphaneUsers
(
ID INT IDENTITY (1,1) NOT NULL,
DBName VARCHAR(125) NULL ,
UserName sysname NULL ,
UserSID VARBINARY(85) NULL ,
LoginExists bit NULL
)
WHILE EXISTS
(SELECT database_id
FROM sys.databases
WHERE database_id>@VarDbId
AND state_desc ='ONLINE'
)
BEGIN
SELECT TOP 1
@SQL ='Create table #OrphaneUser

(UserName sysname null,

UserSID varbinary(85) null )

insert into #OrphaneUser exec ' + name+ '.dbo.sp_change_users_login ''report''

insert into #OrphaneUsers(DBName,UserName,UserSID,LoginExists) select '''+ name+''' as[dbname], UserName, UserSID,0 from #OrphaneUser

drop Table #OrphaneUser',
@VDBName=name
FROM sys.databases
WHERE database_id>@VarDbId
AND state_desc ='ONLINE'
ORDER BY database_id
EXEC SP_Executesql @SQL
SELECT TOP 1
@VarDbId=database_id
FROM sys.databases
WHERE database_id>@VarDbId
AND state_desc ='ONLINE'
END
UPDATE #OrphaneUsers
SET LoginExists=1
FROM #OrphaneUsers
JOIN syslogins
ON #OrphaneUsers.UserName=syslogins.NAME
SELECT @OUCounter =0,
@Max_OUCounter =COUNT(0)
FROM #OrphaneUsers
WHERE LoginExists=1
WHILE EXISTS
(SELECT TOP 1
id
FROM #OrphaneUsers
WHERE LoginExists=1
AND id >@OUCounter
)
BEGIN
SELECT TOP 1
@OUCounter=id
FROM #OrphaneUsers
WHERE LoginExists=1
AND id >@OUCounter
SELECT @SQL ='EXEC '+DBName+'.dbo.sp_change_users_login ''Auto_Fix'', '''+UserName+''', NULL, '''+UserName+''''
FROM #OrphaneUsers
WHERE LoginExists=1
AND id =@OUCounter
EXEC SP_Executesql @SQL
PRINT @SQL
END
SELECT *
FROM #OrphaneUsers
DROP TABLE #OrphaneUsers