SELECT
	session_id,
	start_time,
	status,
	command,
	percent_complete,
	estimated_completion_time,
	estimated_completion_time /60/1000 as estimate_completion_minutes,
	--(select convert(varchar(5),getdate(),8)),
	DATEADD(n,(estimated_completion_time /60/1000),GETDATE()) as estimated_completion_time

FROM    sys.dm_exec_requests where command = 'BACKUP DATABASE' OR command = 'RESTORE DATABASE'