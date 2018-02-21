USE MASTER
GO
DECLARE @LoginName VARCHAR(100)
SET @LoginName='ADVISORY\svc_dha' --> Provide the LoginName Windows or SQL Server
DECLARE @DBName VARCHAR(1000)
IF EXISTS (SELECT *
           FROM   syslogins
           WHERE  loginname = @LoginName)
  BEGIN
      PRINT @LoginName + ' login exists'

      DECLARE CUR CURSOR FOR
        --Get the list of databases
        SELECT name
        FROM   sys.databases
        WHERE  state = 0
        AND is_read_only=0
        

      --OPEN CURSOR
      OPEN CUR

      --Fetch First Row
      FETCH NEXT FROM CUR INTO @DBName

      --Loop
      WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @SQL NVARCHAR(MAX);
            DECLARE @BIGSQL NVARCHAR(MAX);
            DECLARE @DropUSerSQL NVARCHAR(500)
            DECLARE @DropLoginSQL NVARCHAR(500)
            DECLARE @USER NVARCHAR(100)

            IF OBJECT_ID('tempdb..##T') IS NOT NULL
              DROP TABLE ##T

            --> Get User Name for Login
            SET @SQL='
     (SELECT name into ##T FROM sys.database_principals where suser_sname(sid)='''''
                     + @LoginName + '''''' + ')'
            SET @BigSQL = 'USE [' + @dbName
                          + ']; EXEC sp_executesql N''' + @sql + '''';

            EXEC(@BIGSQL)

            SET @USER=(SELECT Name
                       FROM   ##T)

            --> If User is owner of Database, Change the owner to sa
            IF ( @USER = 'dbo' )
              BEGIN
                  PRINT 'Changed DATABASE owner FROM ' + @LoginName
                        + ' TO sa'

                  EXECUTE('USE [' + @dbName + '];EXEC sp_changedbowner ''sa''')
              END
            --If not owner of DB , proceed to Drop User
            ELSE
              BEGIN
                  PRINT 'Droping  USER ' + @USER + ' IN Database:'
                        + @DBName

                  SET @DropUSerSQL= 'DROP USER [' + @USER + ']'

                  EXECUTE('USE [' + @dbName + ']; EXEC sp_executesql N''' + @DropUSerSQL + '''')
              END

            --Fetch next DataBase name 
            FETCH NEXT FROM CUR INTO @DBName
        END

      --Close and Deallocate Cursor
      CLOSE CUR

      DEALLOCATE CUR

      PRINT 'Dropping Login ' + @LoginName

      SET @DropLoginSQL= 'DROP Login [' + @LoginName + ']'

      EXECUTE(@DropLoginSQL)
  END
ELSE
  BEGIN
      PRINT 'Login Does NOT EXISTS'
  END 
