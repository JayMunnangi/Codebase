SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED 

	Select 
				ss.name as SchemaName
				, st.name as TableName
				,s.name as Indexname
				,STATS_DATE(s.id,s.indid) as 'Statistics Last updated'
				,s.rowcnt as 'Row Count'
				,s.rowmodctr as 'number of Changes'
				,CAST((CAST (s.rowmodctr as decimal(28,2))/CAST(s.rowcnt as decimal(28,2))* 100.0)
				as decimal (28,2)) as'% Row Changed'

				from sys.sysindexes s
				INNER JOIN sys.tables st on st.[object_id]=s.[id]
				INNER JOIN sys.schemas ss on ss.[schema_id]=st.[schema_id]
				where s.id>100
				and s.indid>0
				and s.rowcnt>= 500
				Order by schemaname,tablename,Indexname