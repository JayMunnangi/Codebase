USE master
GO

CREATE PROC isp_dropuser_ALL @user sysname
AS
SET NOCOUNT ON
DECLARE @MAX_name sysname, @name sysname, @sql nvarchar(4000), @check int

SELECT @sql = 'SELECT @Check=1 FROM master..syslogins WHERE [name] = '''+@user+'''', @check = NULL
 EXECUTE sp_executesql @sql, N'@Check int OUT', @Check OUT
 IF @Check IS NOT NULL
   BEGIN
  SELECT @MAX_name = MAX([name]), @name = MIN([name]) FROM master..sysdatabases
  
  WHILE @name <= @MAX_name
    BEGIN
   PRINT 'Interogatting Database ' + @name
   SELECT @sql = 'SELECT @Check=1 FROM ' + @name + '..sysusers WHERE [name] = '''+@user+'''', @check = NULL
   EXECUTE sp_executesql @sql, N'@Check int OUT', @Check OUT
   IF @Check IS NOT NULL
     BEGIN 
    SELECT @sql = 'EXEC '+@name+'..sp_dropuser ''' +@user+''''
    EXEC(@sql)
     END
   SELECT @name = MIN([name]) FROM master..sysdatabases WHERE [name] > @name
    END
  PRINT 'Removing Login ' + @user + ' From Server ' + @@SERVERNAME
  SELECT @sql = 'EXEC master..sp_droplogin ''' +@user+''''
  EXEC(@sql)
 END
   ELSE
  PRINT 'User ' + @User + ' does not have a Login to this Server'
SET NOCOUNT OFF
GO


-- EXEC isp_dropUser_ALL 'CRIMSONAD\svc_cmga_aoa_rpt'
--GO