-- Find the Optimal Query Plan handle

SELECT top 10 (total_logical_reads/execution_count),
  (total_logical_writes/execution_count),
  (total_physical_reads/execution_count),
  Execution_count, sql_handle, plan_handle
FROM sys.dm_exec_query_stats  
ORDER BY (total_logical_reads + total_logical_writes) Desc


---Get the Queyr using sql-handle

--Select text from sys.dm_exec_sql_texas (sql-handle)

--To Examine query plan

--Select * from sys.dm_exec_query_plan (plan_handle)