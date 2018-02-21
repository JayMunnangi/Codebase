use master
go
CREATE TABLE DBs_To_Relocate
(
dbname sysname NOT NULL,
is_moved bit not null default 0
)
go

USE [master]
GO

CREATE proc [dbo].[MoveDataFiles] 
@destination_location varchar(100) 
as

--enabling xp_cmdshell will be required to do the file move
exec sp_configure 'xp_cmdshell', 1;
reconfigure;


declare @DBName as varchar(128);
declare @LogicalName as varchar(128);
declare @FileLocation as varchar(128);
declare @FileName as varchar(128);
declare @CMD as nvarchar(256);
declare @SourceFolder as varchar(128);
declare @DestinationFolder as varchar(128);

SET @DestinationFolder = @destination_location; -- Change this to the correct destination folder

BEGIN TRY

declare Db_cursor Cursor forward_only for
   select dbname
   from master..DBs_To_Relocate
   where is_moved = 0;

OPEN Db_cursor;

FETCH NEXT FROM Db_cursor 
INTO @DBName;

WHILE @@FETCH_STATUS = 0
BEGIN

    set @CMD = 'ALTER DATABASE [' + @DBName + '] SET SINGLE_USER WITH ROLLBACK immediate';
    Exec sp_executesql @CMD
    RAISERROR ('Executed command: %s',0,1,@CMD) WITH NOWAIT ;

    set @CMD = 'ALTER DATABASE [' + @DBName + '] SET OFFLINE ';
    Exec sp_executesql @CMD
    RAISERROR ('Executed command: %s',0,1,@CMD) WITH NOWAIT;

    SELECT @LogicalName =name, @FileLocation=physical_name, @FileName = reverse(left(reverse(physical_name), charindex('\', reverse(physical_name)) -1))
    FROM sys.master_files
    WHERE type_desc = 'ROWS' and database_id = DB_ID(@DBName);

    --move the log file
    set @CMD = 'exec xp_cmdshell N''move "' + @FileLocation + '" "' + @DestinationFolder + '\' + @FileName + '"''';
    Exec sp_executesql @CMD
    RAISERROR ('Executed command: %s',0,1,@CMD) WITH NOWAIT;

    SET @SourceFolder = REPLACE(@FileLocation,@Filename,'');

    /* Update the system catalog */
    set @CMD = 'ALTER DATABASE [' + @DBName + '] MODIFY FILE ( NAME = [' + @LogicalName + '], FILENAME = ''' + @DestinationFolder + '\' + @FileName + ''')';
    Exec sp_executesql @CMD
    RAISERROR ('Executed command: %s',0,1,@CMD) WITH NOWAIT;

    set @CMD = 'ALTER DATABASE [' + @DBName + '] SET MULTI_USER';
    Exec sp_executesql @CMD
    RAISERROR ('Executed command: %s',0,1,@CMD) WITH NOWAIT;

    set @CMD = 'ALTER DATABASE [' + @DBName + '] SET ONLINE';
    Exec sp_executesql @CMD 
    RAISERROR ('Executed command: %s',0,1,@CMD) WITH NOWAIT;

	set @CMD = 'UPDATE  DBs_To_Relocate SET is_moved = 1 where dbname = ''' + @DBName + '''';
    Exec sp_executesql @CMD 
    RAISERROR ('Executed command: %s',0,1,@CMD) WITH NOWAIT;

    FETCH NEXT FROM Db_cursor 
    INTO @DBName;
END

CLOSE Db_cursor;
DEALLOCATE Db_cursor;
--GO
END TRY

BEGIN CATCH
   IF (SELECT CURSOR_STATUS('global','Db_cursor')) >=0 
   BEGIN
      DEALLOCATE Db_cursor;
      RAISERROR ('Db_cursor Deallocated in catch',0,1) WITH NOWAIT;
   END

   SELECT ERROR_LINE(),ERROR_MESSAGE();

END CATCH

exec sp_configure 'xp_cmdshell', 0;
reconfigure;
go


INSERT DBs_To_Relocate(dbname) values('test_neel')
go

select * from DBs_To_Relocate
go

Exec MoveDataFiles 'E:\Data'
go



