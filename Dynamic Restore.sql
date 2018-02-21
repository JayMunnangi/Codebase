SET NOCOUNT ON
DECLARE 
        @LinkedServer Varchar(255) = '' ,
		@DataFileLocation Varchar(255) = '' , -- Optional, Specifies the folder for database data files. If not specified, data files are restored to the default data file location
		@LogFileLocation Varchar(255) = '' , -- Optional, Specifies the folder for all database log files. If not specified, log files are restored to the default log file location
		@ExcludeDbs Varchar(255) =  '(''master'' , ''model'' , ''msdb'')' , -- Databases do not wish to restore
		@RestoreDbs Varchar(255) = ''     --  Optional, by default restores all databases other than those mentioned in ExcludeDbs list, can mention any particular database needs to be restored like '(''Database1'', ''Database2'')'
		
DECLARE @dbname Varchar(100) , 
		@physicalpath Varchar(500) , 
		@BackupDate Date , 
		@cmd nvarchar(max) ,
		@logicalname Varchar(255) , 
		@PhysicalFileName Varchar(max) , 
		@type Varchar(5) 
		
--Checks linked server exists, if not then linked server is added, requires ALTER ANY LINKED SERVER permission.		
IF NOT EXISTS (SELECT * FROM SYS.servers Where name = @LinkedServer)
		EXEC sp_addlinkedserver @LinkedServer				

-- If data file location is not specified then data files will be restored to default data file location.		
IF @DataFileLocation IS NULL
	SELECT @DataFileLocation = SUBSTRING(physical_name, 1,CHARINDEX(N'master.mdf',LOWER(physical_name)) - 2)  FROM master.sys.master_files WHERE database_id = 1 AND FILE_ID = 1
-- If log file location is not specified then log files will be restored to default log file location.		
IF @LogFileLocation IS NULL
	SELECT @LogFileLocation =  SUBSTRING(physical_name, 1,CHARINDEX(N'mastlog.ldf',LOWER(physical_name)) - 2)  FROM master.sys.master_files WHERE database_id = 1 AND FILE_ID = 2

CREATE TABLE #filelist (
   LogicalName VARCHAR(255),
   PhysicalName VARCHAR(500),
   [Type] VARCHAR(1),
   FileGroupName VARCHAR(64),
   Size DECIMAL(20, 0),
   MaxSize DECIMAL(25,0),
   FileID bigint,
   CreateLSN DECIMAL(25,0),
   DropLSN DECIMAL(25,0),
   UniqueID UNIQUEIDENTIFIER,
   ReadOnlyLSN DECIMAL(25,0),
   ReadWriteLSN DECIMAL(25,0),
   BackupSizeInBytes DECIMAL(25,0),
   SourceBlockSize INT,
   filegroupid INT,
   loggroupguid UNIQUEIDENTIFIER,
   differentialbaseLSN DECIMAL(25,0),
   differentialbaseGUID UNIQUEIDENTIFIER,
   isreadonly BIT,
   ispresent BIT , 
   TDEThumbprint Varchar(255))


--Queries backupset and backupmediafamily tables on remote msdb database to get latest full backup.
SET @cmd =   'DECLARE restore_db Cursor For SELECT a.database_name , BackupDate , physical_device_name FROM ['+ @LinkedServer+'].msdb.dbo.backupset A ' +
			 ' INNER JOIN (SELECT database_name , BackupDate = MAX(backup_finish_date) ' +   
			 ' FROM ['+@LinkedServer+'].msdb.dbo.backupset ' + 
			 ' WHERE type = ''D'' ' 
IF @RestoreDbs IS NULL
			SET @cmd = @cmd + ' AND database_name NOT IN '+ @ExcludeDbs  +' And backup_finish_date >= DATEADD(MONTH , -1 , GETDATE()) ' 
ELSE			
			SET @cmd = @cmd + ' AND database_name  IN '+ @RestoreDbs 
			SET @cmd = @cmd + ' GROUP BY database_name  ) as b ' +
			 ' ON A.database_name = b.database_name and a.backup_finish_date = BackupDate ' +
			 ' INNER JOIN ['+ @LinkedServer +'].msdb.dbo.backupmediafamily c ON c.media_set_id = a.media_set_id ORDER BY database_name '


exec sp_executesql @cmd

OPEN restore_db   
FETCH NEXT FROM restore_db INTO @dbname , @BackupDate ,  @physicalpath    
WHILE @@FETCH_STATUS = 0   
BEGIN   
    --Check database to be restored is already there in this server, if yes then just restore with replace.
	IF EXISTS (SELECT * FROM sys.databases WHERE name = @dbname)
		BEGIN
		    --Get rid of any existing connections, so that our restore process go smoothly.
			DECLARE @kill varchar(8000) = '';
			SELECT @kill=@kill+'kill '+convert(varchar(5),spid)+';'
			FROm master.dbo.sysprocesses 
			WHERE dbid=db_id(''+ @dbname + '');
			IF len(@kill) <> 0
			  exec sp_executesql @kill;
			
			SET @cmd = 	'RESTORE DATABASE [' + @dbname +'] FROM DISK = '''+ @physicalpath +''' WITH STATS = 1 , REPLACE '  
			Exec sp_executesql @cmd;
			
		END
	ELSE
		BEGIN
			-- If database is not already there then go through the filelist and move to appropriate locations.
			SET @cmd = 'RESTORE FILELISTONLY FROM  DISK= '''+ @physicalpath +''''
			INSERT INTO #filelist
			EXEC (@cmd)
			
			SET @cmd =  'RESTORE DATABASE ['+ @dbname +']  FROM DISK = '''+ @physicalpath +''' WITH STATS = 1 ,   '
			
			DECLARE file_list cursor for  
			SELECT LogicalName, PhysicalName, Type FROM #filelist ORDER BY type
			OPEN file_list
			FETCH NEXT FROM  file_list into @LogicalName, @PhysicalFileName, @type
			WHILE @@fetch_status = 0
				BEGIN
				    -- If it is data file move to data file location.
					IF @type = 'D'
						SET @cmd = @cmd + ' MOVE ''' + @LogicalName + '''' + ' TO ''' + @DataFileLocation  +'\'+   Substring(@PhysicalFileName , LEN(@PhysicalFileName)-CHARINDEX('\' , REVERSE(@PhysicalFileName))+2 , CHARINDEX('\' , REVERSE(@PhysicalFileName))) + ''','
					ELSE 
					-- Log files move to log file location.
						SET @cmd = @cmd + ' MOVE ''' + @LogicalName + '''' + ' TO ''' + @LogFileLocation  + '\'+  Substring(@PhysicalFileName , LEN(@PhysicalFileName)-CHARINDEX('\' , REVERSE(@PhysicalFileName))+2 , CHARINDEX('\' , REVERSE(@PhysicalFileName))) + ''''
			
			FETCH NEXT FROM  file_list into @LogicalName, @PhysicalFileName, @type		
			END
			CLOSE file_list   
			DEALLOCATE file_list
			truncate table #filelist
			Exec sp_executesql @cmd
		END	
	
FETCH NEXT FROM restore_db INTO @dbname , @BackupDate , @physicalpath    
END   
CLOSE restore_db   
DEALLOCATE restore_db

drop table #filelist

