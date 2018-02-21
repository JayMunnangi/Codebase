Declare
@Mem Decimal(18,2),
@Mem2 Decimal(18,2),
@Query Varchar(Max),
@ProductVersion Varchar(10),
@Edition Varchar(100)

Select @Query ='
			Select Case when (Select Convert(Decimal(18,2),value) from sys.configurations  where name=''max server memory (MB)'') >
			(Select XXXX from sys.dm_os_sys_info)  Then (Select XXXX from sys.dm_os_sys_info)   
			else (Select Convert(Decimal(18,2),value) from sys.configurations  where name=''max server memory (MB)'') End',
@ProductVersion =Convert(Varchar(10),SERVERPROPERTY('ProductVersion')), 
@Edition = Convert(Varchar(100),SERVERPROPERTY('Edition')) 


Declare @D Table (Mem Decimal(18,2))

IF Left(@ProductVersion,2)='10'
Begin
	
	Select	@Query=Replace(@Query,'XXXX','(Convert(Decimal(18,2),physical_memory_in_bytes)*1.00)/1024/1024')
			
End
Else
Begin
	Select	@Query=Replace(@Query,'XXXX','(Convert(Decimal(18,2),physical_memory_kb)*1.00)/1024')
				
End
Insert @D
exec (@Query)

Select @Mem=Mem from @D
Select @Mem=CONVERT(Decimal(18,2),@Mem)/1024

If @Edition like '%Standard%' and @Mem>64 
Begin
	
	Select	@Mem2=@Mem,
			@Mem=64
End
Else
Begin
	Select	@Mem2=@Mem,
			@Mem=@Mem
End

SELECT     Convert(Varchar(100),@@ServerName) Srvr,
			@Edition Edition,
			Convert(Varchar(10),@Mem2) 'Allocated Memory',
			Convert(Varchar(10),@Mem)  'Used Memory',
            Convert(Int,([cntr_value]*1.00)) Current_PLE,
            ((@Mem/4)*300 ) Best_PLE,
            ([cntr_value]*1.00)/(((@Mem/4)*300 ))*100 'PLE_%',
			GETDATE() 
/*Into	PLE*/
FROM	sys.dm_os_performance_counters
WHERE	[object_name] LIKE '%Manager%'
		AND [counter_name] = 'Page life expectancy'

