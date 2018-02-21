--database sizes, log sizes, used spaces, available spaces
USE master;
GO
if not exists (select name from sys.databases where name = 'SQLAdmin')
    create database SQLAdmin
go
declare @name sysname 
declare @cmd varchar(4000)
DECLARE databases_cursor CURSOR FOR
SELECT name FROM sys.databases where state in (0)
order by name

create table #database_file_space_info (
    database_name sysname, file_size decimal(15,2), file_space_used decimal(15,2), file_type tinyint
)

create table #database_space_info (
    database_name sysname, database_size decimal(15,2), 
    data_size decimal(15,2), data_available_size decimal(15,2), 
    log_size decimal(15,2), log_available_size decimal(15,2)
)

OPEN databases_cursor;

FETCH NEXT FROM databases_cursor into @name;

WHILE @@FETCH_STATUS = 0
BEGIN
set @cmd = 'use [' + @name + ']; 
insert into #database_file_space_info
SELECT ''' + @name + ''' as database_name, 
CONVERT (numeric (15,2) , (convert(numeric, size) * 8192)/1048576) file_size,
CONVERT (numeric (15,2) , (convert(numeric, FILEPROPERTY(name, ''SpaceUsed'')) * 8192)/1048576) file_space_used,
type file_type
from sys.database_files files
' 
exec (@cmd)
   FETCH NEXT FROM databases_cursor into @name;
END

--select * from #database_file_space_info order by database_name asc

--database_size
insert into #database_space_info(database_name, database_size)
select database_name, 
sum (file_size) database_size
 from #database_file_space_info
group by database_name 

--data available_space
update #database_space_info
set data_size = B.data_size ,
    data_available_size = B.data_available_size 
from #database_space_info A
join (    select database_name, 
            sum (file_size) data_size, 
            (sum (file_size) - sum(file_space_used)) data_available_size 
        from #database_file_space_info
        where file_type not in (1)
        group by database_name) B on A.database_name = B.database_name

--log available space
update #database_space_info
set log_size = B.log_size,
    log_available_size = B.log_available_size
from #database_space_info A
join (select database_name, 
            sum (file_size) log_size, 
            (sum (file_size) - sum(file_space_used)) log_available_size 
        from #database_file_space_info
        where file_type in (1)
        group by database_name) B on A.database_name = B.database_name 

select 
database_name,
database_size [database_size (MB)],
data_size [data_size (MB)],
data_available_size [data_available_size (MB)],
log_size [log_size (MB)],
log_available_size [log_available_size (MB)]
from #database_space_info order by database_name asc

drop table #database_file_space_info
drop table #database_space_info

CLOSE databases_cursor;
DEALLOCATE databases_cursor;
GO