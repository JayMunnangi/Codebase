declare @tempdb_size1 decimal(15,2) = 0
declare @tempdb_size2 decimal(15,2) = 0
declare @tempdb_size3 decimal(15,2) = 0
declare @tempdb_size decimal(15,2) = 0
declare @database_size_info table (
    database_name sysname, database_size decimal(15,2)
)
insert into @database_size_info
select db_name(database_id) database_name, 
SUM (CONVERT (numeric (15,2) , (convert(numeric, size) * 8192)/1048576)) 
from sys.master_files
group by database_id
--10% of the total size of databases greater than 1TB
select @tempdb_size1 = isnull(sum(database_size),0)
from @database_size_info
where database_size >= 1000000
--15% of the total size of databases greater than 100GB and less than 1TB
select @tempdb_size2 = isnull(sum(database_size),0)
from @database_size_info
where database_size >= 100000 and database_size < 1000000
--25% of the total size of databases greater less than 100GB
select @tempdb_size3 = isnull(sum(database_size),0)
from @database_size_info
where database_size < 100000

set @tempdb_size = (@tempdb_size3*0.25)+(@tempdb_size2*0.15)+(@tempdb_size1*0.10)

select @tempdb_size tempdb_estimated_database_size, 
        (@tempdb_size*0.75 ) tempdb_estimated_data_initial_size, 
        (@tempdb_size*0.25 ) tempdb_estimated_log_initial_size




-- https://blogs.msdn.microsoft.com/batuhanyildiz/2013/05/29/what-size-is-suitable-as-an-initial-size-for-tempdb-system-database/

-- https://msdn.microsoft.com/en-us/library/ms345368(v=sql.105).aspx