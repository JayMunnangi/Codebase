SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS')
SELECT * FROM sys.dm_os_cluster_nodes
SELECT SERVERPROPERTY('MachineName')
SELECT SERVERPROPERTY('InstanceName')
SELECT SERVERPROPERTY('ServerName')

SET NOCOUNT ON 
-- 1 - Declare variables
DECLARE @numerrorlogfile int 
-- 2 - Create temporary table
CREATE TABLE #errorLog 
([LogDate] datetime, 
 [ProcessInfo] nvarchar(20), 
 [Text] nvarchar(max)
 ) 
-- 3 - Initialize parameters
SET @numerrorlogfile = 0 
-- 4 - WHILE loop to process error logs
WHILE @numerrorlogfile < 5
    BEGIN TRY 
        INSERT #errorLog ([LogDate], [ProcessInfo], [Text]) 
        EXEC master.dbo.xp_readerrorlog @numerrorlogfile, 1, N'NETBIOS', NULL, NULL, NULL, N'desc'
               
        SET @numerrorlogfile = @numerrorlogfile + 1; 
    END TRY 
    BEGIN CATCH 
        SET @numerrorlogfile = @numerrorlogfile + 1; 
    END CATCH 
-- 5 - Final result set
SELECT LogDate,[Text] FROM #errorLog
-- 6 - Clean-up temp table
DROP TABLE #errorlog
GO