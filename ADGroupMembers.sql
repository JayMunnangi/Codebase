--EXEC master.dbo.xp_logininfo 'CRIMSONAD\CRT_Business Analyst','members'


DECLARE @LoginName sysname 
DECLARE @sql NVARCHAR (2000) 

BEGIN 
   DECLARE cur_Loginfetch CURSOR FOR 
    
   SELECT [name] FROM master.dbo.syslogins WHERE isntgroup = 1 AND status = 10  
    
   OPEN cur_Loginfetch 
    
   FETCH NEXT FROM cur_Loginfetch INTO @LoginName 
   WHILE @@FETCH_STATUS = 0 
       BEGIN 
           EXEC xp_logininfo @LoginName , 'members' 
           FETCH NEXT FROM cur_Loginfetch INTO @LoginName 
       END 
   CLOSE cur_Loginfetch 
   DEALLOCATE cur_Loginfetch 
   RETURN 
END 

---- Below Code Gets all the windows groups on the SQL Instance

IF OBJECT_ID('[tempdb].[dbo].[#TMP]') IS NOT NULL 
DROP TABLE [dbo].[#TMP] 

CREATE TABLE [dbo].[#TMP] ( 
[ACCOUNT NAME]       NVARCHAR(256)                        NULL ,
[TYPE]               VARCHAR(8)                           NULL ,
[PRIVILEGE]          VARCHAR(8)                           NULL ,
[MAPPED LOGIN NAME]  NVARCHAR(256)                        NULL ,
[PERMISSION PATH]    NVARCHAR(256)                        NULL )

DECLARE @cmd VARCHAR(MAX);
   SELECT @cmd  = s.Colzs
        FROM(SELECT 
               Colzs = STUFF((SELECT ';' + 'INSERT INTO #TMP EXEC master..xp_logininfo @acctname = ''' + name +''',@option = ''members'' '
                              FROM master.sys.server_principals 
                              WHERE type_desc = 'WINDOWS_GROUP'
                                AND name NOT LIKE '%$%' --avoid errors like Could not obtain information about Windows NT group/user 'NT SERVICE\MSSQL$MSSQLSERVER1', error code 0x8ac.
                              FOR XML PATH('')
                              ),1,1,'')
            ) s 
SET @cmd = REPLACE(@cmd,';',';' + CHAR(13) + CHAR(10))
print @cmd
exec(@cmd)

SELECT * FROM #tmp