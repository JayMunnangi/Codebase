USE MASTER
declare
	@isql varchar(2000),
	@dbname varchar(64),
	@logfile varchar(128)
	
	declare c1 cursor for 
	SELECT  d.name, mf.name as logfile--, physical_name AS current_file_location, size
	FROM sys.master_files mf
		inner join sys.databases d
		on mf.database_id = d.database_id
	where recovery_model_desc <> 'SIMPLE'
	and d.name not in ('master','model','msdb','tempdb','ReportServer') 
	and mf.type_desc = 'LOG'	
	open c1
	fetch next from c1 into @dbname, @logfile
	While @@fetch_status <> -1
		begin
		select @isql = 'ALTER DATABASE ' + @dbname + ' SET RECOVERY SIMPLE'
		print @isql
		--exec(@isql)
		--select @isql='USE ' + @dbname + ' checkpoint'
		--print @isql
		----exec(@isql)
		--select @isql='USE ' + @dbname + ' DBCC SHRINKFILE (' + @logfile + ', 1)'
		--print @isql
		----exec(@isql)
		
		fetch next from c1 into @dbname, @logfile
		end
	close c1
	deallocate c1