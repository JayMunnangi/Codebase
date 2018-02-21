--variables to hold each 'iteration'
declare @query varchar(100)
declare @dbname sysname
declare @vlfs int

--table variable used to 'loop' over databases
declare @databases table (dbname sysname)
insert into @databases
--only choose online databases
select name from sys.databases where state = 0

--table variable to hold results
declare @vlfcounts table
	(dbname sysname,
	vlfcount int)

--table varioable to capture DBCC loginfo output
declare @dbccloginfo table
(
	fileid tinyint,
	file_size bigint,
	start_offset bigint,
	fseqno int,
	[status] tinyint,
	parity tinyint,
	create_lsn numeric(25,0)
)

while exists(select top 1 dbname from @databases)
begin

	set @dbname = (select top 1 dbname from @databases)
	set @query = 'dbcc loginfo (' + '''' + @dbname + ''') '

	insert into @dbccloginfo
	exec (@query)

	set @vlfs = @@rowcount

	insert @vlfcounts
	values(@dbname, @vlfs)

	delete from @databases where dbname = @dbname

end

--output the full list
select dbname, vlfcount
from @vlfcounts
order by dbname