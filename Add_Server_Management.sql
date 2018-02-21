use DBA_Central_Repository
go
INSERT Crimson_Inventory(Environment,ServerName,ProductVersion,ProductLevel,Edition,EngineEdition,NumberOfPhysicalCPUs ,NumberOfCoresInEachCPU ,TotalNumberOfCores,NumberOfLogicalCPUs ,Memory_Allocated_MB)
SELECT a.Environment,a.ServerName,a.ProductVersion,a.ProductLevel,a.Edition,a.EngineEdition,a.NumberOfPhysicalCPUs,a.NumberOfCoresInEachCPU,a.TotalNumberOfCores,a.NumberOfLogicalCPUs,a.Memory_Allocated_MB FROM OPENROWSET('SQLNCLI', 'Server=ATXPLTWMDB-S03;Trusted_Connection=yes;',
'SELECT CASE
when @@servername like ''%-P0%'' then ''Production''
when @@servername like ''%-S0%'' then ''Staging'' 
when @@servername like ''%-L0%'' then ''Staging''
END
as Environment,@@ServerName as ServerName,
convert(varchar,SERVERPROPERTY(''ProductVersion'')) AS ProductVersion,
convert(varchar,SERVERPROPERTY(''ProductLevel'')) AS ProductLevel,
convert(varchar,SERVERPROPERTY(''Edition'')) AS Edition,
convert(varchar,SERVERPROPERTY(''EngineEdition'')) AS EngineEdition,
( cpu_count / hyperthread_ratio )AS NumberOfPhysicalCPUs
, CASE WHEN hyperthread_ratio = cpu_count THEN cpu_count
ELSE ( ( cpu_count - hyperthread_ratio ) / ( cpu_count / hyperthread_ratio ) )
END AS NumberOfCoresInEachCPU
, CASE WHEN hyperthread_ratio = cpu_count THEN cpu_count
ELSE ( cpu_count / hyperthread_ratio ) * ( ( cpu_count - hyperthread_ratio ) / ( cpu_count / hyperthread_ratio ) )
END AS TotalNumberOfCores
, cpu_count AS NumberOfLogicalCPUs,
value as Memory_Allocated_MB
FROM sys.dm_os_sys_info,sys.syscurconfigs sc
where sc.comment in (''Maximum size of server memory (MB)'')') AS a;