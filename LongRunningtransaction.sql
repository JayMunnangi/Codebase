DECLARE @subject AS varchar(100) = 'Transaction longer than 60 seconds'
DECLARE @message AS varchar(130) = 'All open transactions'
DECLARE @receivers AS varchar(100) = 'Your mail id'
DECLARE @querytran AS varchar(MAX) = 'SELECT b.session_id AS [Session ID],
       CAST(Db_name(a.database_id) AS VARCHAR(20)) AS [Database Name]
       c.command,
       Substring(st.TEXT, ( c.statement_start_offset / 2 ) + 1,
       ( (
       CASE c.statement_end_offset
        WHEN -1 THEN Datalength(st.TEXT)
        ELSE c.statement_end_offset
       END 
       -
       c.statement_start_offset ) / 2 ) + 1)                                                             
       statement_text,
       Coalesce(Quotename(Db_name(st.dbid)) + N''.'' + Quotename(
       Object_schema_name(st.objectid,
                st.dbid)) +
                N''.'' + Quotename(Object_name(st.objectid, st.dbid)), '''')    
       command_text,
       c.wait_type,
       c.wait_time,
       a.database_transaction_log_bytes_used / 1024.0 / 1024.0 AS [MB used],
       a.database_transaction_log_bytes_used_system / 1024.0 / 1024.0 AS [MB used system],
       a.database_transaction_log_bytes_reserved / 1024.0 / 1024.0 AS [MB reserved],
       a.database_transaction_log_bytes_reserved_system / 1024.0 / 1024.0 AS [MB reserved system],
       a.database_transaction_log_record_count AS [Record count]
FROM   sys.dm_tran_database_transactions a
       JOIN sys.dm_tran_session_transactions b
         ON a.transaction_id = b.transaction_id
       JOIN sys.dm_exec_requests c
           CROSS APPLY sys.Dm_exec_sql_text(c.sql_handle) AS st
         ON b.session_id = c.session_id'
EXEC [msdb].[dbo].[sp_send_dbmail] @profile_name='MailProfile', @recipients=@receivers, @subject=@subject, @body=@message, @query=@querytran, @execute_query_database='master', @query_no_truncate=1