1) SELECT sqlserver_start_time FROM sys.dm_os_sys_info; 

 

2) SELECT login_time FROM sys.dm_exec_sessions WHERE session_id = 1; 

 

3) select start_time from sys.traces where is_default = 1 

 

4) SELECT crdate FROM sysdatabases WHERE name='tempdb' 

 

5) SELECT create_date FROM sys.databases WHERE name = 'tempdb'
