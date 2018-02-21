select 
   e.name as eventclass
 , t.textdata
 , t.starttime
 , t.error 
 , t.hostname
 , t.ntusername
 , t.ntdomainname
 , t.clientprocessid
 , t.applicationname
 , t.loginname
 , t.spid
 from fn_trace_gettable('C:\Program Files\Microsoft SQL Server\MSSQL10.MSSQLSERVER\MSSQL\Log\log_92.trc', default) t
  inner join sys.trace_events e 
     on t.eventclass = e.trace_event_id 
  where eventclass = xx

--http://www.sqlservercentral.com/blogs/steve_jones/2012/05/07/finding-the-default-trace-file/