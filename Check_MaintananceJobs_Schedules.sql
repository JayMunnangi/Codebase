USE [msdb];
GO

CREATE FUNCTION [dbo].[ufn_AgentDateTime2DateTime] (@agentdate int, @agenttime int)
RETURNS DATETIME
AS
BEGIN
DECLARE @date DATETIME,
@year int,
@month int,
@day int,
@hour int,
@min int,
@sec int,
@datestr NVARCHAR(40)

IF @agentdate IS NULL OR @agentdate = 0 BEGIN SET @agentdate = 19000101 END
IF @agenttime IS NULL BEGIN SET @agenttime = 100000 END

 SELECT @year = (@agentdate / 10000)
 SELECT @month = (@agentdate - (@year * 10000)) / 100
 SELECT @day = (@agentdate - (@year * 10000) - (@month * 100))
 SELECT @hour = (@agenttime / 10000)
 SELECT @min = (@agenttime - (@hour * 10000)) / 100
 SELECT @sec = (@agenttime - (@hour * 10000) - (@min * 100))

SELECT @datestr = CONVERT(NVARCHAR(4), @year) + N'-' + CONVERT(NVARCHAR(2), @month) + N'-' + CONVERT(NVARCHAR(4), @day) + N' ' + REPLACE(CONVERT(NVARCHAR(2), @hour) + N':' + CONVERT(NVARCHAR(2), @min) + N':' + CONVERT(NVARCHAR(2), @sec), ' ', '0')

SELECT @date = CONVERT(DATETIME, @datestr)
RETURN @date
END
GO

SET ANSI_WARNINGS OFF;
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @JobSched TABLE (
	Job_Name VARCHAR(150),
	Category_Name VARCHAR(50),
	occurrences int,
	duration int,
	Schedule VARCHAR(50),
	Frequency VARCHAR(50),
	Next_Run DATETIME,
	Predicted_End DATETIME)

DECLARE @JobSchedComp TABLE (
	Job_Name VARCHAR(150),
	Category_Name VARCHAR(50),
	occurrences int,
	duration int,
	Schedule VARCHAR(50),
	Frequency VARCHAR(50),
	Next_Run DATETIME,
	Predicted_End DATETIME)

CREATE TABLE #TblJobSchedFinal (
	Job_Name VARCHAR(150),
	Category_Name VARCHAR(50),
	Schedule VARCHAR(50),
	Frequency VARCHAR(50),
	Next_Run DATETIME,
	Predicted_End DATETIME,
	Times_Job_executed_lst_30d int,
	Avg_Time_lst_30d VARCHAR(8),
	Stats_from DATETIME);

CREATE TABLE #TblJobSchedWin (
	Event VARCHAR(50),
	Starting DATETIME,
	Ending DATETIME,
	Window_Time VARCHAR(50));

--Only jobs that executed in the last 30 days
DECLARE @numdays int, @startdate DATETIME, @enddate DATETIME
SELECT @startdate = DATEADD(dd, DATEDIFF(dd, 0, GETDATE()), 0) - 30, @enddate = DATEADD(dd, DATEDIFF(dd, 0, GETDATE()), 0), @numdays = DATEDIFF(DAY,@startdate,@enddate);

--Only jobs with a valid schedule
INSERT INTO @JobSched
SELECT T2.name AS 'Job_Name', 
	T3.name AS 'Category_Name', 
	CAST(COUNT(*) AS DEC) AS occurrences, 
	CAST(SUM(T1.run_duration) AS DEC) AS duration,
	CASE T4.freq_type -- Daily, Weekly, Monthly
	WHEN 1 THEN 'Once'
	WHEN 4 THEN 'Daily'
	WHEN 8 THEN 'Weekly: ' -- For weekly, add in the days of the week
	+ CASE T4.freq_interval & 2 WHEN 2 THEN 'Mon ' ELSE '' END -- Monday
	+ CASE T4.freq_interval & 4 WHEN 4 THEN 'Tue ' ELSE '' END -- Tuesday
	+ CASE T4.freq_interval & 8 WHEN 8 THEN 'Wed ' ELSE '' END -- etc
	+ CASE T4.freq_interval & 16 WHEN 16 THEN 'Thu ' ELSE '' END
	+ CASE T4.freq_interval & 32 WHEN 32 THEN 'Fri ' ELSE '' END
	+ CASE T4.freq_interval & 64 WHEN 64 THEN 'Sat ' ELSE '' END
	+ CASE T4.freq_interval & 1 WHEN 1 THEN 'Sun ' ELSE '' END
	WHEN 16 THEN 'Monthly on day ' + CONVERT(VARCHAR(2), T4.freq_interval) -- Monthly on a particular day
	WHEN 32 THEN 'Monthly: ' -- "every third Friday of the month" for example
	+ CASE T4.freq_relative_interval 
	WHEN 1 THEN 'Every First '
	WHEN 2 THEN 'Every Second '
	WHEN 4 THEN 'Every Third '
	WHEN 8 THEN 'Every Fourth '
	WHEN 16 THEN 'Every Last '
	END
	+ CASE T4.freq_interval 
	WHEN 1 THEN 'Sunday' 
	WHEN 2 THEN 'Monday'
	WHEN 3 THEN 'Tuesday' 
	WHEN 4 THEN 'Wednesday' 
	WHEN 5 THEN 'Thursday' 
	WHEN 6 THEN 'Friday' 
	WHEN 7 THEN 'Saturday' 
	WHEN 8 THEN 'Day' 
	WHEN 9 THEN 'Week day'
	WHEN 10 THEN 'Weekend day'
	END 
	WHEN 64 THEN 'Startup' -- Whenever SQL Server starts
	WHEN 128 THEN 'Idle' -- Whenever SQL Server gets bored
	END AS 'Schedule',
	CASE T4.freq_subday_type -- For when a job runs every few seconds, minutes or hours
	WHEN 1 THEN ''
	WHEN 2 THEN 'Every ' + CONVERT(VARCHAR(3), freq_subday_interval) + 's'
	WHEN 4 THEN 'Every ' + CONVERT(VARCHAR(3), freq_subday_interval) + 'm'
	WHEN 8 THEN 'Every ' + CONVERT(VARCHAR(3), freq_subday_interval) + 'h'
	END AS 'Frequency',
	dbo.ufn_AgentDateTime2DateTime(T5.next_run_date,T5.next_run_time) AS 'Next_Run',
	DATEADD(ss, SUM(T1.run_duration), dbo.ufn_AgentDateTime2DateTime(T5.next_run_date,T5.next_run_time))  AS 'Predicted_End'
FROM msdb.dbo.sysjobhistory T1 
INNER JOIN msdb.dbo.sysjobs T2 ON T1.job_id = T2.job_id
INNER JOIN msdb.dbo.syscategories T3 ON T2.category_id = T3.category_id
INNER JOIN msdb.dbo.sysjobschedules T5 ON T1.job_id = T5.job_id
INNER JOIN msdb.dbo.sysschedules T4 ON T5.schedule_id = T4.schedule_id
	AND step_id = 0 AND T2.enabled = 1 AND T4.enabled = 1 
	AND CAST(RTRIM(T1.run_date) AS DATETIME) BETWEEN @startdate AND @enddate 
	AND dbo.ufn_AgentDateTime2DateTime(T5.next_run_date,T5.next_run_time) < DATEADD(ms, -3, DATEADD(dd, DATEDIFF(dd, 0, GETDATE() + 1) + 1, 0)) -- Get all executing before midnight tomorrow
	AND dbo.ufn_AgentDateTime2DateTime(T5.next_run_date,T5.next_run_time) <> '1900-01-01 00:00:00.000'
GROUP BY T2.name, T3.name, T4.freq_type, T5.next_run_time, T5.next_run_date, T4.freq_interval, T4.freq_relative_interval, T4.freq_subday_type, T4.freq_subday_interval, T4.active_start_time
 
INSERT INTO @JobSchedComp
SELECT Job_Name,Category_Name,occurrences,duration,Schedule,Frequency,Next_Run,Predicted_End
FROM @JobSched
WHERE Frequency = '' OR Frequency IS NULL

INSERT INTO @JobSchedComp
SELECT T1.Job_Name, T1.Category_Name, T2.occurrences, T2.run_duration, T1.Schedule, T1.Frequency, T1.Next_Run, 
	DATEADD(ss, T2.run_duration, T1.Next_Run) AS 'Predicted_End'
FROM (SELECT 'Backup DB ' + b.database_name AS 'Job_Name',
	'BACKUP DB' AS Category_Name,
	'Daily' AS Schedule,
	'' AS Frequency,
	b.backup_start_date + DATEDIFF(dd, b.backup_start_date, GETDATE()) AS Next_Run
	FROM msdb..backupset b
	WHERE b.type = 'D'
	AND b.backup_start_date > @startdate
	AND b.database_name NOT IN ('tempdb','pubs','model')
	AND b.backup_finish_date IN (SELECT max(backup_finish_date) FROM msdb..backupset b2 WHERE b2.database_name = b.database_name AND b2.type = 'D' GROUP BY b2.database_name)
	GROUP BY b.type, b.database_name, b.backup_start_date, b.backup_finish_date) T1
INNER JOIN (SELECT 'Backup DB ' + b.database_name AS Job_Name,
	CAST(COUNT(*) AS dec) AS 'occurrences',
	(SUM(DATEDIFF(ss, b.backup_start_date, b.backup_finish_date))/COUNT(*)) AS run_duration
	FROM msdb..backupset b
	WHERE b.type = 'D'
	AND b.backup_start_date > @startdate
	--AND (b.[user_name] = 'user_TDP' OR b.[user_name] = 'NT AUTHORITY\SYSTEM')
	AND b.database_name NOT IN ('tempdb','pubs','model')
	GROUP BY b.type, b.database_name) T2
ON T1.Job_Name = T2.Job_Name

DECLARE @Job_Name VARCHAR(150), @Category_Name VARCHAR(50), @occurrences int, @duration int, @Schedule VARCHAR(50), @Frequency VARCHAR(50), @Next_Run DATETIME, @Predicted_End DATETIME
DECLARE cur_Schedule CURSOR FAST_FORWARD FOR SELECT Job_Name,Category_Name,occurrences,duration,Schedule,Frequency,Next_Run,Predicted_End FROM @JobSched 
	WHERE Frequency LIKE 'Every%' AND (Frequency <> 'Every 1m' AND Frequency <> 'Every 2m' AND Frequency <> 'Every 3m' AND Frequency <> 'Every 4m' AND Frequency <> 'Every 5m')
OPEN cur_Schedule 
FETCH NEXT FROM cur_Schedule INTO @Job_Name, @Category_Name, @occurrences, @duration, @Schedule, @Frequency, @Next_Run, @Predicted_End
WHILE @@FETCH_STATUS = 0 
BEGIN 
	DECLARE @FrequencyInt int, @FrequencyTime CHAR(1)
	SET @FrequencyInt = LEFT(RIGHT(@Frequency,(LEN(@Frequency) - 6)), (LEN(@Frequency) - 7))
	SET @FrequencyTime = RIGHT (@Frequency,1)
	INSERT INTO @JobSchedComp 
	SELECT @Job_Name, @Category_Name, @occurrences, @duration, @Schedule, @Frequency, @Next_Run, @Predicted_End 
	WHILE REPLACE(CONVERT(VARCHAR, @Next_Run,101),'/','') + REPLACE(CONVERT(VARCHAR, @Next_Run,108),':','') < REPLACE(CONVERT(VARCHAR, GETDATE(),101),'/','') + '235959'
	BEGIN
	SET @Next_Run = CASE WHEN @FrequencyTime = 's' THEN DATEADD(ss,@FrequencyInt,@Next_Run)
	WHEN @FrequencyTime = 'm' THEN DATEADD(mi,@FrequencyInt,@Next_Run)
	WHEN @FrequencyTime = 'h' THEN DATEADD(hh,@FrequencyInt,@Next_Run) END
	SET @Predicted_End = CASE WHEN @FrequencyTime = 's' THEN DATEADD(ss,@FrequencyInt,@Predicted_End)
	WHEN @FrequencyTime = 'm' THEN DATEADD(mi,@FrequencyInt,@Predicted_End)
	WHEN @FrequencyTime = 'h' THEN DATEADD(hh,@FrequencyInt,@Predicted_End) END
	INSERT INTO @JobSchedComp 
	SELECT @Job_Name, @Category_Name, @occurrences, @duration, @Schedule, @Frequency, @Next_Run, @Predicted_End 
	END
	FETCH NEXT FROM cur_Schedule INTO @Job_Name, @Category_Name, @occurrences, @duration, @Schedule, @Frequency, @Next_Run, @Predicted_End 
END 
CLOSE cur_Schedule
DEALLOCATE cur_Schedule

INSERT INTO #TblJobSchedFinal
SELECT Job_Name, Category_Name, Schedule, Frequency, Next_Run, Predicted_End,
	CONVERT(INT,LTRIM(RTRIM(STR(CEILING(occurrences),10,0)))) AS 'Times_Job_executed_lst_30d',
	CASE WHEN CAST(duration AS int)/3600<10 THEN '0' ELSE '' END + RTRIM(CAST(duration AS int)/3600) + ':' + RIGHT('0'+RTRIM((CAST(duration AS int) % 3600) / 60),2) + ':' + RIGHT('0'+RTRIM((CAST(duration AS int) % 3600) % 60),2) AS 'Avg_Time_lst_30d', @startdate AS 'Stats_from'
FROM @JobSchedComp
WHERE Next_Run < DATEADD(ms, -3, DATEADD(dd, DATEDIFF(dd, 0, GETDATE() + 1) + 1, 0)) -- Executing before midnight tomorrow
ORDER BY 5,6

DECLARE @tblJobsDelDup TABLE (Starting DATETIME, Ending DATETIME)

DECLARE @Starting DATETIME, @Ending DATETIME, @StartingTemp DATETIME, @EndingTemp DATETIME
DECLARE curJobsRunTime CURSOR FAST_FORWARD FOR SELECT (SELECT MIN(d.Next_Run)
	FROM #TblJobSchedFinal d  
		WHERE d.Next_Run < x.Predicted_End
		AND NOT EXISTS (SELECT Job_Name, Next_Run, Predicted_End
			FROM (SELECT DISTINCT Predicted_End
				FROM #TblJobSchedFinal a 
				WHERE NOT EXISTS (SELECT Job_Name, Next_Run, Predicted_End
					FROM #TblJobSchedFinal b 
					WHERE a.Predicted_End BETWEEN b.Next_Run AND b.Predicted_End
					AND b.Next_Run BETWEEN a.Next_Run AND a.Predicted_End
					AND a.Job_Name <> b.Job_Name)) y
			WHERE y.Predicted_End < x.Predicted_End AND d.Next_Run < y.Predicted_End)) AS 'Starting',
		x.Predicted_End AS 'Ending'
	FROM (SELECT DISTINCT Predicted_End
		FROM #TblJobSchedFinal a 
		WHERE NOT EXISTS (SELECT Job_Name, Next_Run, Predicted_End
			FROM #TblJobSchedFinal b  
			WHERE a.Predicted_End BETWEEN b.Next_Run AND b.Predicted_End
			AND b.Next_Run BETWEEN a.Next_Run AND a.Predicted_End
			AND a.Job_Name <> b.Job_Name)) x
OPEN curJobsRunTime 
FETCH NEXT FROM curJobsRunTime INTO @Starting, @Ending
WHILE @@FETCH_STATUS = 0 
BEGIN 
	IF @Starting IS NOT NULL AND @Ending IS NOT NULL
	BEGIN
		SET @StartingTemp = @Starting
		SET @EndingTemp = @Ending
	END
	IF @Starting IS NULL AND @Ending IS NOT NULL
	BEGIN
		SET @Starting = @StartingTemp
	END
	INSERT INTO @tblJobsDelDup
	SELECT @Starting, @Ending
	FETCH NEXT FROM curJobsRunTime INTO @Starting, @Ending
END 
CLOSE curJobsRunTime
DEALLOCATE curJobsRunTime

DECLARE @StartingInt DATETIME, @EndingInt DATETIME, @EndingTempInt DATETIME, @Window int
DECLARE curJobsInterval CURSOR FAST_FORWARD FOR SELECT Starting AS Starting, MAX(Ending) AS Ending FROM @tblJobsDelDup GROUP BY Starting ORDER BY Starting
OPEN curJobsInterval 
FETCH NEXT FROM curJobsInterval INTO @StartingInt, @EndingInt
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @Window = DATEDIFF(ss, @EndingTempInt, @StartingInt)
	INSERT INTO #TblJobSchedWin
	SELECT 'Jobs are running between:' AS 'Event', @StartingInt AS Starting, @EndingInt AS Ending, CASE WHEN @Window/3600<10 THEN '0' ELSE '' END + RTRIM(@Window/3600) + ':' + RIGHT('0'+RTRIM((@Window % 3600) / 60),2) + ':' + RIGHT('0'+RTRIM((@Window % 3600) % 60),2) AS Window_Time
	SET @EndingTempInt = @EndingInt
	FETCH NEXT FROM curJobsInterval INTO @StartingInt, @EndingInt
END
CLOSE curJobsInterval
DEALLOCATE curJobsInterval;

SELECT Event, Starting, Ending, Window_Time 
FROM #TblJobSchedWin;

SELECT Job_Name, Category_Name, Schedule, Frequency, Next_Run, Predicted_End, 
Times_Job_executed_lst_30d, Avg_Time_lst_30d, Stats_from 
FROM #TblJobSchedFinal 
ORDER BY Next_Run ASC;

DROP TABLE #TblJobSchedFinal
DROP TABLE #TblJobSchedWin
GO
DROP FUNCTION [dbo].[ufn_AgentDateTime2DateTime]
GO
SET QUOTED_IDENTIFIER OFF 
SET ANSI_NULLS ON 
GO
