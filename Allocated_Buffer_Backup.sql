declare @MaxTransferSize float,
@BufferCount bigint,
@DBName varchar(255),
@BackupDevices bigint
--Default value is zero. Value to be provided in MB.
set @MaxTransferSize = 0
--Default value is zero
set @BufferCount = 0
--Provide the name of the database to be backed up
set @DBName = 'dbBackup'
--Number of disk devices that you are writing the backup to
set @BackupDevices = 1
declare @DatabaseDeviceCount int
select @DatabaseDeviceCount=count(distinct(substring(physical_name,1,charindex(physical_name,':')+1)))
from sys.master_files
where database_id = db_id(@DBName)
and type_desc <> 'LOG'
 
if @BufferCount = 0
                set @BufferCount =(@BackupDevices*(3+1) ) + @BackupDevices +(2 * @DatabaseDeviceCount)
 
if @MaxTransferSize = 0
                set @MaxTransferSize = 1
 

select 'Total buffer space (MB): ' + cast((@Buffercount * @MaxTransferSize) as varchar(10))