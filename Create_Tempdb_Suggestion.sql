USE Master
GO
SET NOCOUNT ON
GO
PRINT '-- Instance name: '+ @@servername + ' ;
/* Version: ' + @@version + ' */'
 
-- Variables
 
DECLARE @BITS Bigint                      -- Affinty Mask
,@NUMPROCS Smallint                       -- Number of cores addressed by instance
,@tempdb_files_count Int                  -- Number of exisiting datafiles
,@tempdbdev_location Nvarchar(4000)       -- Location of TEMPDB primary datafile
,@X Int                                   -- Counter
,@SQL Nvarchar(max)
,@new_tempdbdev_size_MB Int               -- Size of the new files,in Megabytes
,@new_tempdbdev_Growth_MB Int             -- New files growth rate,in Megabytes
,@new_files_Location Nvarchar(4000)       -- New files path
 
-- Initialize variables
 
Select  @X = 1, @BITS = 1
SELECT
@new_tempdbdev_size_MB = 4096              -- Four Gbytes , it's easy to increase that after file creation but harder to shrink.
,@new_tempdbdev_Growth_MB = 512            -- 512 Mbytes  , can be easily shrunk
,@new_files_Location = NULL                -- NULL means create in same location as primary file.
 
IF OBJECT_ID('tempdb..#SVer') IS NOT NULL
BEGIN
DROP TABLE #SVer
END
CREATE TABLE #SVer(ID INT,  Name  sysname, Internal_Value INT, Value NVARCHAR(512))
INSERT #SVer EXEC master.dbo.xp_msver processorCount
 
-- Get total number of Cores detected by the Operating system
 
SELECT @NUMPROCS=  Internal_Value FROM #SVer
Print '-- TOTAL numbers of CPU cores on server :' + cast(@NUMPROCS as varchar(5))
SET @NUMPROCS  = 0
 
-- Get number of Cores addressed by instance.
 
WHILE @X <= (SELECT Internal_Value FROM #SVer ) AND @x <=32
BEGIN
    SELECT @NUMPROCS =
    CASE WHEN  CAST (VALUE AS INT) & @BITS > 0 THEN @NUMPROCS + 1 ELSE @NUMPROCS END
    FROM sys.configurations
    WHERE NAME = 'AFFINITY MASK'
    SET  @BITS = (@BITS * 2)
    SET @X = @X + 1
END
 
IF (SELECT Internal_Value FROM #SVer) > 32
    Begin
    WHILE @X <= (SELECT Internal_Value FROM #SVer )
    BEGIN
        SELECT @NUMPROCS =
        CASE WHEN  CAST (VALUE AS INT) & @BITS > 0 THEN @NUMPROCS + 1 ELSE @NUMPROCS END
        FROM sys.configurations
        WHERE NAME = 'AFFINITY64 MASK'
        SET  @BITS = (@BITS * 2)
        SET @X = @X + 1
    END
END
 
If @NUMPROCS = 0 SELECT @NUMPROCS=  Internal_Value FROM #SVer
 
Print '-- Number of CPU cores Configured for usage by instance :' + cast(@NUMPROCS as varchar(5))
 
-------------------------------------------------------------------------------------
-- Here you define how many files should exist per core ; Feel free to change
-------------------------------------------------------------------------------------
 
-- IF cores < 8 then no change , if between 8 & 32 inclusive then 1/2 of cores number
IF @NUMPROCS >8 and @NUMPROCS <=32
SELECT @NUMPROCS = @NUMPROCS /2
 
-- IF cores > 32 then files should be 1/4 of cores number
If @NUMPROCS >32
SELECT @NUMPROCS = @NUMPROCS /4
 
-- Get number of exisiting TEMPDB datafiles and the location of the primary datafile.
 
SELECT @tempdb_files_count=COUNT(*) ,@tempdbdev_location=(SELECT REVERSE(SUBSTRING(REVERSE(physical_name), CHARINDEX('\',REVERSE(physical_name)) , LEN(physical_name) )) FROM tempdb.sys.database_files  WHERE name = 'tempdev')
FROM tempdb.sys.database_files
WHERE type_desc= 'Rows' AND state_desc= 'Online'
 
Print '-- Current Number of Tempdb datafiles :' + cast(@tempdb_files_count as varchar(5))
 
-- Determine if we already have enough datafiles
If @tempdb_files_count >= @NUMPROCS
Begin
Print '--****Number of Recommedned datafiles is already there****'
Return
End
 
Set @new_files_Location= Isnull(@new_files_Location,@tempdbdev_location)
 
-- Determine if the new location exists or not
Declare @file_results table(file_exists int,file_is_a_directory int,parent_directory_exists int)
 
insert into @file_results(file_exists, file_is_a_directory, parent_directory_exists)
exec master.dbo.xp_fileexist @new_files_Location
 
if (select file_is_a_directory from @file_results ) = 0
Begin
print '-- New files Directory Does NOT exist , please specify a correct folder!'
Return
end
 
-- Determine if we have enough free space on the destination drive
 
Declare @FreeSpace Table (Drive char(1),MB_Free Bigint)
insert into @FreeSpace exec master..xp_fixeddrives
 
if (select MB_Free from @FreeSpace where drive = LEFT(@new_files_Location,1) ) < @NUMPROCS * @new_tempdbdev_size_MB
Begin
print '-- WARNING: Not enough free space on ' + Upper(LEFT(@new_files_Location,1)) + ':\ to accomodate the new files. Around '+ cast(@NUMPROCS * @new_tempdbdev_size_MB as varchar(10))+ ' Mbytes are needed; Please add more space or choose a new location!'
 
end
 
-- Determine if any of the exisiting datafiles have different size than proposed ones.
If exists
(
    SELECT (CONVERT (bigint, size) * 8)/1024 FROM tempdb.sys.database_files
    WHERE type_desc= 'Rows'
    and  (CONVERT (bigint, size) * 8)/1024  <> @new_tempdbdev_size_MB
)
 
PRINT
'
/*
WARNING: Some Existing datafile(s) do NOT have the same size as new ones.
It''s recommended if ALL datafiles have same size for optimal proportional-fill performance.Use ALTER DATABASE and DBCC SHRINKFILE to resize files
 
Optimizing tempdb Performance : http://msdn.microsoft.com/en-us/library/ms175527.aspx
'
 
Print '****Proposed New Tempdb Datafiles, PLEASE REVIEW CODE BEFORE RUNNIG  *****/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
'
-- Generate the statements
WHILE @tempdb_files_count < @NUMPROCS
 
BEGIN
 
    SELECT @SQL = 'ALTER DATABASE [tempdb] ADD FILE (NAME = N''tempdev_new_0'+CAST (@tempdb_files_count +1 AS VARCHAR (5))+''',FILENAME = N'''+ @new_files_Location + 'tempdev_new_0'+CAST (@tempdb_files_count +1 AS VARCHAR(5)) +'.ndf'',SIZE = '+CAST(@new_tempdbdev_size_MB AS VARCHAR(15)) +'MB,FILEGROWTH = '+CAST(@new_tempdbdev_Growth_MB AS VARCHAR(15)) +'MB )
GO'
    PRINT @SQL
    SET @tempdb_files_count = @tempdb_files_count + 1
END
