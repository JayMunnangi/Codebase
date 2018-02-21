IF OBJECT_ID('sp_who2_ex','P') IS NOT NULL
		DROP PROC sp_who2_ex

GO
CREATE PROC sp_who2_ex
@loginame sysname = null
AS

	DECLARE @whotbl TABLE
	(
	  SPID		INT	NULL
	 ,Status	VARCHAR(50)	NULL
	 ,Login		SYSNAME	NULL
	 ,HostName	SYSNAME	NULL
	 ,BlkBy		VARCHAR(5)	NULL
	 ,DBName	SYSNAME	NULL
	 ,Command	VARCHAR(1000)	NULL
	 ,CPUTime	INT	NULL
	 ,DiskIO	INT	NULL
	 ,LastBatch VARCHAR(50)	NULL
	 ,ProgramName VARCHAR(200)	NULL
	 ,SPID2		INT	NULL
	 ,RequestID INT	NULL
	 )


	 INSERT INTO @whotbl
	 EXEC sp_who2  @loginame = @loginame

	SELECT W.* 
		  ,CommandText = sql.text
		  ,ExecutionPlan   = pln.query_plan
		  ,ObjectName  = so.name 
		  ,der.percent_complete
		  ,der.estimated_completion_time
		  --,CommandType =der.command
	  FROM @whotbl  W
 LEFT JOIN sys.dm_exec_requests der
	    ON der.session_id = w.SPID
	   OUTER APPLY SYS.dm_exec_sql_text (der.sql_handle) Sql
	   OUTER APPLY sys.dm_exec_query_plan (der.plan_handle) pln
 LEFT JOIN sys.objects so
	    ON so.object_id = sql.objectid
   

go