/*You can run this tsql to generate a detach and attach database.

Once you have the output you can change the file location of the move statement in case if you are attaching to a different server or moving your file to a new location with in the same instance.

Run this in the context of the database that you want to detach and attach.

Also including the output. */

SET NOCOUNT ON 
 
-- Variables 
DECLARE @cmd VARCHAR(8000) 
 
CREATE TABLE #HelpFile 
    ( 
      [name] VARCHAR(100) 
    , [fileid] TINYINT 
    , [filename] VARCHAR(1000) 
    , [filegroup] VARCHAR(100) 
    , [size] VARCHAR(100) 
    , [maxsize] VARCHAR(20) 
    , [growth] VARCHAR(20) 
    , [USAGE] VARCHAR(20) 
    ) 
INSERT  INTO #HelpFile 
        EXEC sp_helpfile 
 
 
-- Print the sp_detach command 
PRINT '*************** Detach/Attach Database commands ***************' 
PRINT 'EXEC sp_detach_db ''' + DB_NAME() + ''', ''true''' 
PRINT 'GO' 
 
 
-- Generate the sp_attach_db command 
SET @cmd = NULL 
SELECT 
    @cmd = COALESCE(@cmd + CHAR(10) + CHAR(9) + '''' + RTRIM(filename) 
                    + ''', ', 
                    'EXEC sp_attach_db ''' + DB_NAME() + ''', ' + CHAR(10) 
                    + CHAR(9) + '''' + RTRIM(filename) + ''', ') 
FROM 
    #HelpFile (NOLOCK) 
ORDER BY 
    fileid 
 
-- remove the trailing space 
SELECT 
    @cmd = LEFT(@cmd, LEN(@cmd) - 1) 
 
-- print the command 
PRINT @cmd 
PRINT 'GO' 
 
--*************** Detach/Attach Database commands *************** 
EXEC sp_detach_db 'test', 'true' 
GO 
EXEC sp_attach_db 'test', 
    'L:\Log-01\BIAud_fg_files\test_Primary_FG.mdf', 
    'L:\Log-01\BIAud_fg_files\test_TransLog_FG.ldf', 
    'H:\Data-01\BIAud_fg_files\test_BIAud_FG_1.ndf', 
    'I:\Data-01\BIAud_fg_files\test_BIAud_FG_2.ndf', 
    'H:\Data-01\BIAud_fg_files\test_BIAud_FG_3.ndf', 
    'I:\Data-01\BIAud_fg_files\test_BIAud_FG_4.ndf' 
GO 