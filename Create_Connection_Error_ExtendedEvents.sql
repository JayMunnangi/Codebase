CREATE EVENT SESSION [Connection_Error] ON SERVER 
ADD EVENT sqlserver.existing_connection(
    ACTION(sqlserver.session_id)),
ADD EVENT sqlserver.oledb_call(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.context_info,sqlserver.session_id,sqlserver.sql_text,sqlserver.tsql_frame)),
ADD EVENT sqlserver.oledb_error(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.context_info,sqlserver.session_id,sqlserver.sql_text,sqlserver.tsql_frame)),
ADD EVENT sqlserver.oledb_provider_information(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.context_info,sqlserver.session_id,sqlserver.sql_text,sqlserver.tsql_frame)),
ADD EVENT ucs.ucs_connection_send_msg(
    ACTION(sqlserver.session_id)) 
ADD TARGET package0.event_file(SET filename=N'F:\PerfMon\Connection_Error.xel',max_file_size=(10240))
WITH (STARTUP_STATE=OFF)
GO


