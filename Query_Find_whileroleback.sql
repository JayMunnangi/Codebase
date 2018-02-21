select
    l.resource_type,
    l.request_mode,
    l.request_status,
    l.request_session_id,
    r.command,
    r.status,
    r.blocking_session_id,
    r.wait_type,
    r.wait_time,
    r.wait_resource,
    request_sql_text = st.text,
    s.program_name,
    most_recent_sql_text = stc.text
from sys.dm_tran_locks l
left join sys.dm_exec_requests r
on l.request_session_id = r.session_id
left join sys.dm_exec_sessions s
on l.request_session_id = s.session_id
left join sys.dm_exec_connections c
on s.session_id = c.session_id
outer apply sys.dm_exec_sql_text(r.sql_handle) st
outer apply sys.dm_exec_sql_text(c.most_recent_sql_handle) stc
where l.resource_database_id = db_id('JFK_Edison_External')
order by request_session_id;