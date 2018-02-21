SELECT S.Spid,D.Name,S.lastwaittype,s.blocked,S.status FROM SYSPROCESSES S
INNER JOIN SYS.sysdatabases D
ON S.dbid=D.dbid
ORDER BY lastwaittype

SELECT * FROM sys.dm_exec_query_resource_semaphores

SELECT * FROM sys.dm_exec_query_memory_grants

select top 10 * from sys.dm_exec_query_memory_grants

SELECT * FROM sys.dm_exec_sql_text(0x06002C00A3180D2640E004D92C00000001000000000000000000000000000000000000000000000000000000)