SELECT  creation_time 
        ,last_execution_time
        ,total_physical_reads
        ,total_logical_reads 
        ,total_logical_writes
        , execution_count
        , total_worker_time
        , total_elapsed_time
        , total_elapsed_time / execution_count avg_elapsed_time
        ,SUBSTRING(st.text, (qs.statement_start_offset/2) + 1,
         ((CASE statement_end_offset
          WHEN -1 THEN DATALENGTH(st.text)
          ELSE qs.statement_end_offset END
            - qs.statement_start_offset)/2) + 1) AS statement_text,
			qs.sql_handle
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
--where qs.sql_handle like '0x020000000D8E172FE1374762A007042EF11006775124B27E'
where statement_text like 'select [dbo].[fxTradingPartnerLastTransmission]('78E91EC2-4D63-E511-A5F5-0050569C1FF8', 45, 90) as result'
ORDER BY total_elapsed_time / execution_count DESC;


