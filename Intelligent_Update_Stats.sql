SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED 
--STORE RELEVANT DETAILS

Select ss.name as SchemaName
, st.name as tablename
,si.name as indexname
,ssi.rowcnt
into #Indexusage
From sys.indexes si
INNER JOIN sys.sysindexes ssi on si.object_id=ssi.id
										and si.name=ssi.name
INNER JOIN sys.tables st on st.[object_id]=si.[object_id]
INNER JOIN sys.schemas ss on ss.[schema_id]=st.[schema_id]
where st.is_ms_shipped =0 
and si.index_id !=0
and ssi.rowcnt > 100
and ssi.rowmodctr>0

-- buildupdate statistics sql sevrer( concatenated)

Declare @UpdatestatisticsSQL nvarchar(max)
SET @UpdatestatisticsSQL=''
Select @UpdatestatisticsSQL=@UpdateStatisticsSQL
+Char(10)+ ' Update Statistics '
+QUOTENAME(SchemaName) + '.' +	Quotename(TableName)
+''+QuoteName(indexname) + 'With Sample ' 
+ CASE 
			When rowcnt < 500000 then '100 Percent'
			when rowcnt <1000000 then '50 Percent'
			when rowcnt <5000000 then '25 Percent'
			when rowcnt <10000000 then '10 Percent'
			when rowcnt <50000000 then '2 Percent'
			when rowcnt <100000000 then '1 Percent'
			Else '3000000 ROWS'
			END
			+ '--' +CAST (rowcnt as VARCHAR(22))+ ' rows' 
			from #Indexusage
			
			-- Debug
			DECLARE @Startoffset INT
			DECLARE @length INT
			
			SET @StartOffset=0
			SET @Length =4000

			While (@Startoffset < LEN(@UpdatestatisticsSQL))
			Begin 
					Print SUBSTRING(@UpdateStatisticsSQL,@Startoffset,@Length)
					SET @Startoffset=@Startoffset+@Length
					END

					Print Substring(@UpdateStatisticsSQL,@Startoffset,@length)

					-- Execute update statistics

					Execute sp_executesql @UpdateStatisticsSQL  
					,N'@UpdateStatisticsSQL nvarchar(max) output'
					,@UpdateStatisticsSQL output
					--,@Startoffset output
					--,@length output
					-- Cleanup

					Drop table #indexusage
								


-- for reference http://www.i-programmer.info/programming/database/3624-a-generic-sql-performance-test-harness.html		