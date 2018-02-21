SELECT plan_handle,usecounts, cacheobjtype, objtype, size_in_bytes, text, 
    qp.query_plan, tqp.query_plan AS text_query_plan
FROM sys.dm_exec_cached_plans cp
 CROSS APPLY sys.dm_exec_sql_text(plan_handle) t
 CROSS APPLY sys.dm_exec_query_plan(plan_handle) qp
 CROSS APPLY sys.dm_exec_text_query_plan(plan_handle, NULL, NULL) tqp
WHERE  text LIKE '%MyStoredProcedure%'
 AND objtype = 'Proc'