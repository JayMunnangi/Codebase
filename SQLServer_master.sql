USE master;
GO

IF OBJECT_ID('dbo.sp_BlitzCache') IS NULL 
  EXEC ('CREATE PROCEDURE dbo.sp_BlitzCache AS RETURN 0;')
GO

ALTER PROCEDURE dbo.sp_BlitzCache
    @get_help BIT = 0,
    @top INT = 50, 
    @sort_order VARCHAR(10) = 'CPU',
    @use_triggers_anyway BIT = NULL,
    @export_to_excel BIT = 0,
    @results VARCHAR(10) = 'simple',
    @output_database_name NVARCHAR(128) = NULL ,
    @output_schema_name NVARCHAR(256) = NULL ,
    @output_table_name NVARCHAR(256) = NULL ,
    @duration_filter DECIMAL(38,4) = NULL,
    @hide_summary BIT = 0,
    @whole_cache BIT = 0 /* This will forcibly set @top to 2,147,483,647 */
WITH RECOMPILE
/******************************************
sp_BlitzCache (TM) 2014, Brent Ozar Unlimited.
(C) 2014, Brent Ozar Unlimited. 
See http://BrentOzar.com/go/eula for the End User Licensing Agreement.



Description: Displays a server level view of the SQL Server plan cache.

Output: One result set is presented that contains data from the statement, 
procedure, and trigger stats DMVs.

To learn more, visit http://brentozar.com/responder/get-top-resource-consuming-queries/ 
where you can download new versions for free, watch training videos on
how it works, get more info on the findings, and more. To contribute 
code and see your name in the change log, email your improvements & 
ideas to help@brentozar.com.


KNOWN ISSUES:
- This query will not run on SQL Server 2005.
- SQL Server 2008 and 2008R2 have a bug in trigger stats (see below).

v2.1 - 2014-04-30
 - Added @duration_filter. Queries are now filtered during collection based on duration.
 - Added results summary table and hide_summary parameter.
 - Added check for > 1000 executions per minute.
 - Added check for queries with missing indexes.
 - Added check for queries with warnings in the execution plan.
 - Added check for queries using cursors.
 - Query cost will be displayed next to the execution plan for a query.
 - Added a check for plan guides and forced plans.
 - An asterisk will be displayed next to the name of queries that have gone parallel.
 - Added a check for parallel plans.
 - Added @results parameter - options are 'narrow', 'simple', and 'expert'
 - Added a check for plans using a downlevel cardinality estimator
 - Added checks for plans with implicit conversions or plan affecting convert warnings
 - Added check for queries with spill warnings
 - Consolidated warning detection into a smaller number of T-SQL statements
 - Added a Warnings column
 - Added "busy loops" check
 - Fixed bug where long-running query threshold was 300 microseconds, not seconds

v2.0 - 2014-03-23
 - Created a stored procedure
 - Added write information
 - Added option to export to a single table
 - Corrected accidental exclusion of trigger information

v1.4 - 2014-02-17
 - MOAR BUG FIXES
 - Corrected multiple sorting bugs that cause confusing displays of query
   results that weren't necessarily the top anything.
 - Updated all modification timestamps to use ISO 8601 formatting because it's
   correct, sorry Britain.
 - Added a check for SQL Server 2008R2 build greater than SP1.
   Thanks to Kevan Riley for spotting this.
 - Added the stored procedure or trigger name to the Query Type column.
   Initial suggestion from Kevan Riley.
 - Corrected erronous math that could allow for % CPU/Duration/Executions/Reads
   being higher than 100% for batches/procedures with multiple poorly
   performing statements in them.

v1.3 - 2014-02-06
 - As they say on the app store, "Bug fixes"
 - Reorganized this to put the standard, gotta-run stuff at the top.
 - Switched to YYYY/MM/DD because Brits.

v1.2 - 2014-02-04
- Removed debug code
- Fixed output where SQL Server 2008 and early don't support min_rows, 
  max_rows, and total_rows.
  SQL Server 2008 and earlier will now return NULL for those columns.

v1.1 - 2014-02-02
- Incorporated sys.dm_exec_plan_attributes as recommended by Andrey 
  and Michael J. Swart.
- Added additional detail columns for plan cache analysis including
  min/max rows, total rows.
- Streamlined collection of data.



*******************************************/
AS
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF @get_help = 1
BEGIN
    SELECT N'@get_help' AS [Parameter Name] ,
           N'BIT' AS [Data Type] ,
           N'Displays this help message.' AS [Parameter Description]
           
    UNION ALL
    SELECT N'@top',
           N'INT',
           N'The number of records to retrieve and analyze from the plan cache. The following DMVs are used as the plan cache: dm_exec_query_stats, dm_exec_procedure_stats, dm_exec_trigger_stats.'
           
    UNION ALL           
    SELECT N'@sort_order',
           N'VARCHAR(10)',
           N'Data processing and display order. @sort_order will still be used, even when preparing output for a table or for excel. Possible values are: "CPU", "Reads", "Writes", "Duration", "Executions".'
           
    UNION ALL
    SELECT N'@use_triggers_anyway',
           N'BIT',
           N'On SQL Server 2008R2 and earlier, trigger execution count is wildly incorrect. If you still want to see relative execution count of triggers, then you can force sp_BlitzCache to include this information.'
           
    UNION ALL
    SELECT N'@export_to_excel',
           N'BIT',
           N'Prepare output for exporting to Excel. Newlines and additional whitespace are removed from query text and the execution plan is not displayed.'

    UNION ALL
    SELECT N'@results',
           N'VARCHAR(10)',
           N'Results mode. Options are "Narrow", "Simple", or "Expert". This determines the columns that will be displayed in the detailed analysis of the plan cache.'
    
    UNION ALL
    SELECT N'@output_database_name',
           N'NVARCHAR(128)',
           N'The output database. If this does not exist SQL Server will divide by zero and everything will fall apart.'

    UNION ALL
    SELECT N'@output_schema_name',
           N'NVARCHAR(256)',
           N'Output schema. If this does not exist SQL Server will divide by zero and everything will fall apart.'

    UNION ALL
    SELECT N'@output_table_name',
           N'NVARCHAR(256)',
           N'Output table. If this does not exist, it will be created for you.'

    UNION ALL
    SELECT N'@duration_filter',
           N'DECIMAL(38,4)',
           N'Filters queries with an average duration (seconds) less than @duration_filter.'

    UNION ALL
    SELECT N'@hide_summary',
           N'BIT',
           N'Hides the findings summary result set.'

    UNION ALL
    SELECT N'@whole_cache',
           N'BIT',
           N'This forces sp_BlitzCache to examine the entire plan cache. Be careful running this on servers with a lot of memory or a large execution plan cache.' ;


           
    /* Column definitions */
    SELECT N'# Executions' AS [Column Name],
           N'BIGINT' AS [Data Type],
           N'The number of executions of this particular query. This is computed across statements, procedures, and triggers and aggregated by the SQL handle.' AS [Column Description]

    UNION ALL
    SELECT N'Executions / Minute',
           N'MONEY',
           N'Number of executions per minute for this SQL handle. This is calculated for the life of the current plan. Plan life is the last execution time minus the plan creation time.'

    UNION ALL
    SELECT N'Execution Weight',
           N'MONEY',
           N'An arbitrary metric of total "execution-ness". A weight of 2 is "one more" than a weight of 1.'

    UNION ALL
    SELECT N'Database',
           N'sysname',
           N'The name of the database where the plan was encountered. If the database name cannot be determined for some reason, a value of NA will be substituted. A value of 32767 indicates the plan comes from ResourceDB.'

    UNION ALL
    SELECT N'Total CPU',
           N'BIGINT',
           N'Total CPU time, reported in microseconds, that was consumed by all executions of this query since the last compilation.'

    UNION ALL
    SELECT N'Avg CPU',
           N'BIGINT',
           N'Average CPU time, reported in microseconds, consumed by each execution of this query since the last compilation.'

    UNION ALL
    SELECT N'CPU Weight',
           N'MONEY',
           N'An arbitrary metric of total "CPU-ness". A weight of 2 is "one more" than a weight of 1.'


    UNION ALL
    SELECT N'Total Duration',
           N'BIGINT',
           N'Total elapsed time, reported in microseconds, consumed by all executions of this query since last compilation.'

    UNION ALL
    SELECT N'Avg Duration',
           N'BIGINT',
           N'Average elapsed time, reported in microseconds, consumed by each execution of this query since the last compilation.'

    UNION ALL
    SELECT N'Duration Weight',
           N'MONEY',
           N'An arbitrary metric of total "Duration-ness". A weight of 2 is "one more" than a weight of 1.'

    UNION ALL
    SELECT N'Total Reads',
           N'BIGINT',
           N'Total logical reads performed by this query since last compilation.'

    UNION ALL
    SELECT N'Average Reads',
           N'BIGINT',
           N'Average logical reads performed by each execution of this query since the last compilation.'

    UNION ALL
    SELECT N'Read Weight',
           N'MONEY',
           N'An arbitrary metric of "Read-ness". A weight of 2 is "one more" than a weight of 1.'

    UNION ALL
    SELECT N'Total Writes',
           N'BIGINT',
           N'Total logical writes performed by this query since last compilation.'

    UNION ALL
    SELECT N'Average Writes',
           N'BIGINT',
           N'Average logical writes performed by each exuection this query since last compilation.'

    UNION ALL
    SELECT N'Write Weight',
           N'MONEY',
           N'An arbitrary metric of "Write-ness". A weight of 2 is "one more" than a weight of 1.'

    UNION ALL
    SELECT N'Query Type',
           N'NVARCHAR(256)',
           N'The type of query being examined. This can be "Procedure", "Statement", or "Trigger".' + NCHAR(13) + NCHAR(10)
             + N'If the first character of the Query Type column is an asterisk, this query has a parallel plan.'

    UNION ALL
    SELECT N'Query Text',
           N'NVARCHAR(4000)',
           N'The text of the query. This may be truncated by either SQL Server or by sp_BlitzCache for display purposes.'

    UNION ALL
    SELECT N'% Executions (Type)',
           N'MONEY',
           N'Percent of executions relative to the type of query - e.g. 17.2% of all stored procedure executions.'

    UNION ALL
    SELECT N'% CPU (Type)',
           N'MONEY',
           N'Percent of CPU time consumed by this query for a given type of query - e.g. 22% of CPU of all stored procedures executed.'

    UNION ALL
    SELECT N'% Duration (Type)',
           N'MONEY',
           N'Percent of elapsed time consumed by this query for a given type of query - e.g. 12% of all statements executed.'

    UNION ALL
    SELECT N'% Reads (Type)',
           N'MONEY',
           N'Percent of reads consumed by this query for a given type of query - e.g. 34.2% of all stored procedures executed.'

    UNION ALL
    SELECT N'% Writes (Type)',
           N'MONEY',
           N'Percent of writes performed by this query for a given type of query - e.g. 43.2% of all statements executed.'

    UNION ALL
    SELECT N'Total Rows',
           N'BIGINT',
           N'Total number of rows returned for all executions of this query. This only applies to query level stats, not stored procedures or triggers.'

    UNION ALL
    SELECT N'Average Rows',
           N'MONEY',
           N'Average number of rows returned by each execution of the query.'

    UNION ALL
    SELECT N'Min Rows',
           N'BIGINT',
           N'The minimum number of rows returned by any execution of this query.'

    UNION ALL
    SELECT N'Max Rows',
           N'BIGINT',
           N'The maximum number of rows returned by any execution of this query.'

    UNION ALL
    SELECT N'# Plans',
           N'INT',
           N'The total number of execution plans found that match a given query.'

    UNION ALL
    SELECT N'# Distinct Plans',
           N'INT',
           N'The number of distinct execution plans that match a given query. '
            + NCHAR(13) + NCHAR(10)
            + N'This may be caused by running the same query across multiple databases or because of a lack of proper parameterization in the database.'

    UNION ALL
    SELECT N'Created At',
           N'DATETIME',
           N'Time that the execution plan was last compiled.'

    UNION ALL
    SELECT N'Last Execution',
           N'DATETIME',
           N'The last time that this query was executed.'

    UNION ALL
    SELECT N'Query Plan',
           N'XML',
           N'The query plan. Click to display a graphical plan or, if you need to patch SSMS, a pile of XML.'

    UNION ALL
    SELECT N'Plan Handle',
           N'VARBINARY(64)',
           N'An arbitrary identifier referring to the compiled plan this query is a part of.'

    UNION ALL
    SELECT N'SQL Handle',
           N'VARBINARY(64)',
           N'An arbitrary identifier referring to a batch or stored procedure that this query is a part of.'

    UNION ALL
    SELECT N'Query Hash',
           N'BINARY(8)',
           N'A hash of the query. Queries with the same query hash have similar logic but only differ by literal values or database.'
           
    UNION ALL
    SELECT N'Warnings',
           N'VARCHAR(MAX)',
           N'A list of individual warnings generated by this query.'                    
    RETURN
END

DECLARE @duration_filter_i INT,
        @msg NVARCHAR(4000) ;

RAISERROR (N'Setting up temporary tables for sp_BlitzCache',0,1) WITH NOWAIT;

/* Change duration from seconds to microseconds */
IF @duration_filter IS NOT NULL
  SET @duration_filter_i = CAST((@duration_filter * 1000.0 * 1000.0) AS INT)

SET @sort_order = LOWER(@sort_order);

IF @sort_order NOT IN ('cpu', 'reads', 'writes', 'duration', 'executions')
  SET @sort_order = 'cpu';

SELECT @output_database_name = QUOTENAME(@output_database_name),
       @output_schema_name   = QUOTENAME(@output_schema_name),
       @output_table_name    = QUOTENAME(@output_table_name)

IF OBJECT_ID('tempdb..#results') IS NOT NULL
    DROP TABLE #results;

IF OBJECT_ID('tempdb..#p') IS NOT NULL
    DROP TABLE #p;

IF OBJECT_ID('tempdb..#procs') IS NOT NULL
    DROP TABLE #procs;

IF OBJECT_ID ('tempdb..#checkversion') IS NOT NULL
    DROP TABLE #checkversion;

CREATE TABLE #results (
    ID INT IDENTITY(1,1),
    CheckID INT,
    Priority TINYINT,
    FindingsGroup VARCHAR(50),
    Finding VARCHAR(200),
    URL VARCHAR(200),
    Details VARCHAR(4000)
);

CREATE TABLE #p (
    SqlHandle varbinary(64),
    TotalCPU bigint,
    TotalDuration bigint,
    TotalReads bigint,
    TotalWrites bigint,
    ExecutionCount bigint
);

CREATE TABLE #checkversion (
    version nvarchar(128),
    maj_version AS SUBSTRING(version, 1,CHARINDEX('.', version) + 1 ),
    build AS PARSENAME(CONVERT(varchar(32), version), 2)
);

-- TODO: Add columns from main query to #procs
CREATE TABLE #procs (
    QueryType nvarchar(256),
    DatabaseName sysname,
    AverageCPU bigint,
    AverageCPUPerMinute money,
    TotalCPU bigint,
    PercentCPUByType money,
    PercentCPU money,
    AverageDuration bigint,
    TotalDuration bigint,
    PercentDuration money,
    PercentDurationByType money,
    AverageReads bigint,
    TotalReads bigint,
    PercentReads money,
    PercentReadsByType money,
    ExecutionCount bigint,
    PercentExecutions money,
    PercentExecutionsByType money,
    ExecutionsPerMinute money,
    TotalWrites bigint,
    AverageWrites money,
    PercentWrites money,
    PercentWritesByType money,
    WritesPerMinute money,
    PlanCreationTime datetime,
    LastExecutionTime datetime,
    PlanHandle varbinary(64),
    SqlHandle varbinary(64),
    QueryHash binary(8),
    QueryPlanHash binary(8),
    StatementStartOffset int,
    StatementEndOffset int,
    MinReturnedRows bigint,
    MaxReturnedRows bigint,
    AverageReturnedRows money,
    TotalReturnedRows bigint,
    LastReturnedRows bigint,
    QueryText nvarchar(max),
    QueryPlan xml,
    /* these next four columns are the total for the type of query.
       don't actually use them for anything apart from math by type.
     */
    TotalWorkerTimeForType bigint,
    TotalElapsedTimeForType bigint,
    TotalReadsForType bigint,
    TotalExecutionCountForType bigint,
    TotalWritesForType bigint,
    NumberOfPlans int,
    NumberOfDistinctPlans int,
    min_worker_time bigint,
    max_worker_time bigint,
    is_forced_plan bit,
    is_forced_parameterized bit,
    is_cursor bit,
    is_parallel bit,
    frequent_execution bit,
    parameter_sniffing bit,
    near_parallel bit,
    plan_warnings bit,
    plan_multiple_plans bit,
    long_running bit,
    downlevel_estimator bit,
    implicit_conversions bit,
    tempdb_spill bit,
    busy_loops bit,
    tvf_join bit,
    tvf_estimate bit,
    compile_timeout bit,
    compile_memory_limit_exceeded bit,
    warning_no_join_predicate bit,
    QueryPlanCost float,
    missing_index_count int,
    min_elapsed_time bigint,
    max_elapsed_time bigint,
    Warnings VARCHAR(MAX)
);

DECLARE @sql nvarchar(MAX) = N'',
        @insert_list nvarchar(MAX) = N'',
        @plans_triggers_select_list nvarchar(MAX) = N'',
        @body nvarchar(MAX) = N'',
        @nl nvarchar(2) = NCHAR(13) + NCHAR(10),
        @q nvarchar(1) = N'''',
        @pv varchar(20),
        @pos tinyint,
        @v decimal(6,2),
        @build int;


RAISERROR (N'Determining SQL Server version.',0,1) WITH NOWAIT;

INSERT INTO #checkversion (version) 
SELECT CAST(SERVERPROPERTY('ProductVersion') as nvarchar(128))
OPTION (RECOMPILE);
 

SELECT @v = maj_version ,
       @build = build 
FROM   #checkversion 
OPTION (RECOMPILE);

RAISERROR (N'Creating dynamic SQL based on SQL Server version.',0,1) WITH NOWAIT;

SET @insert_list += N'
INSERT INTO #procs (QueryType, DatabaseName, AverageCPU, TotalCPU, AverageCPUPerMinute, PercentCPUByType, PercentDurationByType, 
                    PercentReadsByType, PercentExecutionsByType, AverageDuration, TotalDuration, AverageReads, TotalReads, ExecutionCount,
                    ExecutionsPerMinute, TotalWrites, AverageWrites, PercentWritesByType, WritesPerMinute, PlanCreationTime, 
                    LastExecutionTime, StatementStartOffset, StatementEndOffset, MinReturnedRows, MaxReturnedRows, AverageReturnedRows, TotalReturnedRows, 
                    LastReturnedRows, QueryText, QueryPlan, TotalWorkerTimeForType, TotalElapsedTimeForType, TotalReadsForType, 
                    TotalExecutionCountForType, TotalWritesForType, SqlHandle, PlanHandle, QueryHash, QueryPlanHash,
                    min_worker_time, max_worker_time, is_parallel, min_elapsed_time, max_elapsed_time) ' ;

SET @body += N'
FROM   (SELECT *,
               CAST((CASE WHEN DATEDIFF(second, cached_time, GETDATE()) > 0 And execution_count > 1
                          THEN DATEDIFF(second, cached_time, GETDATE()) / 60.0
                          ELSE NULL END) as MONEY) as age_minutes, 
               CAST((CASE WHEN DATEDIFF(second, cached_time, last_execution_time) > 0 And execution_count > 1
                          THEN DATEDIFF(second, cached_time, last_execution_time) / 60.0
                          ELSE Null END) as MONEY) as age_minutes_lifetime
        FROM   sys.#view#) AS qs
       CROSS JOIN(SELECT SUM(execution_count) AS t_TotalExecs,
                         SUM(total_elapsed_time) AS t_TotalElapsed, 
                         SUM(total_worker_time) AS t_TotalWorker,
                         SUM(total_logical_reads) AS t_TotalReads,
                         SUM(total_logical_writes) AS t_TotalWrites
                  FROM   sys.#view#) AS t
       CROSS APPLY sys.dm_exec_plan_attributes(qs.plan_handle) AS pa
       CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
       CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
WHERE  pa.attribute = ' + QUOTENAME('dbid', @q) + @nl

IF @duration_filter IS NOT NULL
  SET @body += N'       AND total_elapsed_time / execution_count > @min_duration ' + @nl

SET @body += N'ORDER BY #sortable# DESC
OPTION(RECOMPILE);'

SET @plans_triggers_select_list += N'
SELECT TOP (@top)
       ''Procedure: '' + COALESCE(OBJECT_NAME(qs.object_id, qs.database_id),'''') AS QueryType,
       COALESCE(DB_NAME(database_id), CAST(pa.value AS sysname), ''-- N/A --'') AS DatabaseName,
       total_worker_time / execution_count AS AvgCPU ,
       total_worker_time AS TotalCPU ,
       CASE WHEN total_worker_time = 0 THEN 0
            WHEN COALESCE(age_minutes, DATEDIFF(mi, qs.cached_time, qs.last_execution_time), 0) = 0 THEN 0
            ELSE CAST(total_worker_time / COALESCE(age_minutes, DATEDIFF(mi, qs.cached_time, qs.last_execution_time)) AS MONEY) 
            END AS AverageCPUPerMinute ,
       CASE WHEN t.t_TotalWorker = 0 THEN 0
            ELSE CAST(ROUND(100.00 * total_worker_time / t.t_TotalWorker, 2) AS MONEY)
            END AS PercentCPUByType,
       CASE WHEN t.t_TotalElapsed = 0 THEN 0
            ELSE CAST(ROUND(100.00 * total_elapsed_time / t.t_TotalElapsed, 2) AS MONEY)
            END AS PercentDurationByType,
       CASE WHEN t.t_TotalReads = 0 THEN 0
            ELSE CAST(ROUND(100.00 * total_logical_reads / t.t_TotalReads, 2) AS MONEY)
            END AS PercentReadsByType,
       CASE WHEN t.t_TotalExecs = 0 THEN 0
            ELSE CAST(ROUND(100.00 * execution_count / t.t_TotalExecs, 2) AS MONEY)
            END AS PercentExecutionsByType,
       total_elapsed_time / execution_count AS AvgDuration , 
       total_elapsed_time AS TotalDuration ,
       total_logical_reads / execution_count AS AvgReads ,
       total_logical_reads AS TotalReads ,
       execution_count AS ExecutionCount ,
       CASE WHEN execution_count = 0 THEN 0
            WHEN COALESCE(age_minutes, DATEDIFF(mi, qs.cached_time, qs.last_execution_time), 0) = 0 THEN 0
            ELSE CAST((1.00 * execution_count / COALESCE(age_minutes, DATEDIFF(mi, qs.cached_time, qs.last_execution_time))) AS money)
            END AS ExecutionsPerMinute ,
       total_logical_writes AS TotalWrites ,
       total_logical_writes / execution_count AS AverageWrites ,
       CASE WHEN t.t_TotalWrites = 0 THEN 0
            ELSE CAST(ROUND(100.00 * total_logical_writes / t.t_TotalWrites, 2) AS MONEY)
            END AS PercentWritesByType,
       CASE WHEN total_logical_writes = 0 THEN 0
            WHEN COALESCE(age_minutes, DATEDIFF(mi, qs.cached_time, qs.last_execution_time), 0) = 0 THEN 0
            ELSE CAST((1.00 * total_logical_writes / COALESCE(age_minutes, DATEDIFF(mi, qs.cached_time, qs.last_execution_time), 0)) AS money)
            END AS WritesPerMinute,
       qs.cached_time AS PlanCreationTime,
       qs.last_execution_time AS LastExecutionTime,
       NULL AS StatementStartOffset,
       NULL AS StatementEndOffset,
       NULL AS MinReturnedRows,
       NULL AS MaxReturnedRows,
       NULL AS AvgReturnedRows,
       NULL AS TotalReturnedRows,
       NULL AS LastReturnedRows,
       st.text AS QueryText , 
       query_plan AS QueryPlan, 
       t.t_TotalWorker,
       t.t_TotalElapsed,
       t.t_TotalReads,
       t.t_TotalExecs,
       t.t_TotalWrites,
       qs.sql_handle AS SqlHandle,
       qs.plan_handle AS PlanHandle,
       NULL AS QueryHash,
       NULL AS QueryPlanHash,
       qs.min_worker_time,
       qs.max_worker_time,
       CASE WHEN qp.query_plan.value(''declare namespace p="http://schemas.microsoft.com/sqlserver/2004/07/showplan";max(//p:RelOp/@Parallel)'', ''float'')  > 0 THEN 1 ELSE 0 END,
       qs.min_elapsed_time,
       qs.max_elapsed_time '


SET @sql += @insert_list;

SET @sql += N'
SELECT TOP (@top)
       ''Statement'' AS QueryType,
       COALESCE(DB_NAME(CAST(pa.value AS INT)), ''-- N/A --'') AS DatabaseName,
       total_worker_time / execution_count AS AvgCPU ,
       total_worker_time AS TotalCPU ,
       CASE WHEN total_worker_time = 0 THEN 0
            WHEN COALESCE(age_minutes, DATEDIFF(mi, qs.creation_time, qs.last_execution_time), 0) = 0 THEN 0
            ELSE CAST(total_worker_time / COALESCE(age_minutes, DATEDIFF(mi, qs.creation_time, qs.last_execution_time)) AS MONEY) 
            END AS AverageCPUPerMinute ,
       CAST(ROUND(100.00 * total_worker_time / t.t_TotalWorker, 2) AS MONEY) AS PercentCPUByType,
       CAST(ROUND(100.00 * total_elapsed_time / t.t_TotalElapsed, 2) AS MONEY) AS PercentDurationByType, 
       CAST(ROUND(100.00 * total_logical_reads / t.t_TotalReads, 2) AS MONEY) AS PercentReadsByType,
       CAST(ROUND(100.00 * execution_count / t.t_TotalExecs, 2) AS MONEY) AS PercentExecutionsByType,
       total_elapsed_time / execution_count AS AvgDuration , 
       total_elapsed_time AS TotalDuration ,
       total_logical_reads / execution_count AS AvgReads ,
       total_logical_reads AS TotalReads ,
       execution_count AS ExecutionCount ,
       CASE WHEN execution_count = 0 THEN 0
            WHEN COALESCE(age_minutes, DATEDIFF(mi, qs.creation_time, qs.last_execution_time), 0) = 0 THEN 0
            ELSE CAST((1.00 * execution_count / COALESCE(age_minutes, DATEDIFF(mi, qs.creation_time, qs.last_execution_time))) AS money)
            END AS ExecutionsPerMinute ,
       total_logical_writes AS TotalWrites ,
       total_logical_writes / execution_count AS AverageWrites ,
       CASE WHEN t.t_TotalWrites = 0 THEN 0
            ELSE CAST(ROUND(100.00 * total_logical_writes / t.t_TotalWrites, 2) AS MONEY)
            END AS PercentWritesByType,
       CASE WHEN total_logical_writes = 0 THEN 0
            WHEN COALESCE(age_minutes, DATEDIFF(mi, qs.creation_time, qs.last_execution_time), 0) = 0 THEN 0
            ELSE CAST((1.00 * total_logical_writes / COALESCE(age_minutes, DATEDIFF(mi, qs.creation_time, qs.last_execution_time), 0)) AS money)
            END AS WritesPerMinute,       
       qs.creation_time AS PlanCreationTime,
       qs.last_execution_time AS LastExecutionTime,
       qs.statement_start_offset AS StatementStartOffset,
       qs.statement_end_offset AS StatementEndOffset, '

IF (@v >= 11) OR (@v >= 10.5 AND @build >= 2500)
BEGIN
    SET @sql += N'
       qs.min_rows AS MinReturnedRows,
       qs.max_rows AS MaxReturnedRows,
       CAST(qs.total_rows as MONEY) / execution_count AS AvgReturnedRows,
       qs.total_rows AS TotalReturnedRows,
       qs.last_rows AS LastReturnedRows, ' ;
END
ELSE
BEGIN
    SET @sql += N'
       NULL AS MinReturnedRows,
       NULL AS MaxReturnedRows,
       NULL AS AvgReturnedRows,
       NULL AS TotalReturnedRows,
       NULL AS LastReturnedRows, ' ;
END

SET @sql += N'
       SUBSTRING(st.text, ( qs.statement_start_offset / 2 ) + 1, ( ( CASE qs.statement_end_offset
                                                                        WHEN -1 THEN DATALENGTH(st.text)
                                                                        ELSE qs.statement_end_offset
                                                                      END - qs.statement_start_offset ) / 2 ) + 1) AS QueryText , 
       query_plan AS QueryPlan, 
       t.t_TotalWorker,
       t.t_TotalElapsed,
       t.t_TotalReads,
       t.t_TotalExecs,
       t.t_TotalWrites,
       qs.sql_handle AS SqlHandle,
       NULL AS PlanHandle,
       qs.query_hash AS QueryHash,
       qs.query_plan_hash AS QueryPlanHash,
       qs.min_worker_time,
       qs.max_worker_time,
       CASE WHEN qp.query_plan.value(''declare namespace p="http://schemas.microsoft.com/sqlserver/2004/07/showplan";max(//p:RelOp/@Parallel)'', ''float'')  > 0 THEN 1 ELSE 0 END,
       qs.min_elapsed_time,
       qs.max_worker_time '

SET @sql += REPLACE(REPLACE(@body, '#view#', 'dm_exec_query_stats'), 'cached_time', 'creation_time') ;
SET @sql += @nl + @nl;



SET @sql += @insert_list;
SET @sql += REPLACE(@plans_triggers_select_list, '#query_type#', 'Stored Procedure') ;

SET @sql += REPLACE(@body, '#view#', 'dm_exec_procedure_stats') ;
SET @sql += @nl + @nl;



/*******************************************************************************
 *
 * Because the trigger execution count in SQL Server 2008R2 and earlier is not 
 * correct, we ignore triggers for these versions of SQL Server. If you'd like
 * to include trigger numbers, just know that the ExecutionCount, 
 * PercentExecutions, and ExecutionsPerMinute are wildly inaccurate for 
 * triggers on these versions of SQL Server. 
 * 
 * This is why we can't have nice things.
 *
 ******************************************************************************/
IF @use_triggers_anyway = 1 OR @v >= 11
BEGIN
   RAISERROR (N'Adding SQL to collect trigger stats.',0,1) WITH NOWAIT;
   
   /* Trigger level information from the plan cache */
   SET @sql += @insert_list ;

   SET @sql += REPLACE(@plans_triggers_select_list, '#query_type#', 'Trigger') ;

   SET @sql += REPLACE(@body, '#view#', 'dm_exec_trigger_stats') ;
END




DECLARE @sort NVARCHAR(30);

SELECT @sort = CASE @sort_order WHEN 'cpu' THEN 'total_worker_time'
                                WHEN 'reads' THEN 'total_logical_reads'
                                WHEN 'writes' THEN 'total_logical_writes'
                                WHEN 'duration' THEN 'total_elapsed_time'
                                WHEN 'executions' THEN 'execution_count'
               END ;

SELECT @sql = REPLACE(@sql, '#sortable#', @sort);

SET @sql += N'
INSERT INTO #p (SqlHandle, TotalCPU, TotalReads, TotalDuration, TotalWrites, ExecutionCount)
SELECT  SqlHandle, 
        TotalCPU,
        TotalReads,
        TotalDuration,
        TotalWrites,
        ExecutionCount
FROM    (SELECT  SqlHandle, 
                 TotalCPU,
                 TotalReads,
                 TotalDuration,
                 TotalWrites,
                 ExecutionCount,
                 ROW_NUMBER() OVER (PARTITION BY SqlHandle ORDER BY #sortable# DESC) AS rn
         FROM    #procs) AS x
WHERE x.rn = 1
OPTION (RECOMPILE);
';

SELECT @sort = CASE @sort_order WHEN 'cpu' THEN 'TotalCPU'
                                WHEN 'reads' THEN 'TotalReads'
                                WHEN 'writes' THEN 'TotalWrites'
                                WHEN 'duration' THEN 'TotalDuration'
                                WHEN 'executions' THEN 'ExecutionCount'
               END ;

SELECT @sql = REPLACE(@sql, '#sortable#', @sort);



RAISERROR('Collecting execution plan information.', 0, 1) WITH NOWAIT;
EXEC sp_executesql @sql, N'@top INT, @min_duration INT', @top, @duration_filter_i;



/* Compute the total CPU, etc across our active set of the plan cache.
 * Yes, there's a flaw - this doesn't include anything outside of our @top 
 * metric.
 */
RAISERROR('Computing CPU, duration, read, and write metrics', 0, 1) WITH NOWAIT;
DECLARE @total_duration BIGINT,
        @total_cpu BIGINT,
        @total_reads BIGINT,
        @total_writes BIGINT,
        @total_execution_count BIGINT;

SELECT  @total_cpu = SUM(TotalCPU),
        @total_duration = SUM(TotalDuration),
        @total_reads = SUM(TotalReads),
        @total_writes = SUM(TotalWrites),
        @total_execution_count = SUM(ExecutionCount)
FROM    #p
OPTION (RECOMPILE) ;

DECLARE @cr NVARCHAR(1) = NCHAR(13);
DECLARE @lf NVARCHAR(1) = NCHAR(10);
DECLARE @tab NVARCHAR(1) = NCHAR(9);

/* Update CPU percentage for stored procedures */
UPDATE #procs
SET     PercentCPU = y.PercentCPU,
        PercentDuration = y.PercentDuration,
        PercentReads = y.PercentReads,
        PercentWrites = y.PercentWrites,
        PercentExecutions = y.PercentExecutions,
        ExecutionsPerMinute = y.ExecutionsPerMinute,
        /* Strip newlines and tabs. Tabs are replaced with multiple spaces
           so that the later whitespace trim will completely eliminate them
         */
        QueryText = REPLACE(REPLACE(REPLACE(QueryText, @cr, ' '), @lf, ' '), @tab, '  ')
FROM (
    SELECT  PlanHandle,
            CASE @total_cpu WHEN 0 THEN 0
                 ELSE CAST((100. * TotalCPU) / @total_cpu AS MONEY) END AS PercentCPU,
            CASE @total_duration WHEN 0 THEN 0
                 ELSE CAST((100. * TotalDuration) / @total_duration AS MONEY) END AS PercentDuration,
            CASE @total_reads WHEN 0 THEN 0
                 ELSE CAST((100. * TotalReads) / @total_reads AS MONEY) END AS PercentReads,
            CASE @total_writes WHEN 0 THEN 0
                 ELSE CAST((100. * TotalWrites) / @total_writes AS MONEY) END AS PercentWrites,   
            CASE @total_execution_count WHEN 0 THEN 0
                 ELSE CAST((100. * ExecutionCount) / @total_execution_count AS MONEY) END AS PercentExecutions,
            CASE DATEDIFF(mi, PlanCreationTime, LastExecutionTime)
                WHEN 0 THEN 0
                ELSE CAST((1.00 * ExecutionCount / DATEDIFF(mi, PlanCreationTime, LastExecutionTime)) AS money) 
            END AS ExecutionsPerMinute
    FROM (
        SELECT  PlanHandle,
                TotalCPU,
                TotalDuration,
                TotalReads,
                TotalWrites,
                ExecutionCount,
                PlanCreationTime,
                LastExecutionTime
        FROM    #procs
        WHERE   PlanHandle IS NOT NULL
        GROUP BY PlanHandle,
                TotalCPU,
                TotalDuration,
                TotalReads,
                TotalWrites,
                ExecutionCount,
                PlanCreationTime,
                LastExecutionTime
    ) AS x
) AS y
WHERE #procs.PlanHandle = y.PlanHandle
      AND #procs.PlanHandle IS NOT NULL
OPTION (RECOMPILE) ;



UPDATE #procs
SET     PercentCPU = y.PercentCPU,
        PercentDuration = y.PercentDuration,
        PercentReads = y.PercentReads,
        PercentWrites = y.PercentWrites,
        PercentExecutions = y.PercentExecutions,
        ExecutionsPerMinute = y.ExecutionsPerMinute,
        /* Strip newlines and tabs. Tabs are replaced with multiple spaces
           so that the later whitespace trim will completely eliminate them
         */
        QueryText = REPLACE(REPLACE(REPLACE(QueryText, @cr, ' '), @lf, ' '), @tab, '  ')
FROM (
    SELECT  DatabaseName,
            SqlHandle,
            QueryHash,
            CASE @total_cpu WHEN 0 THEN 0
                 ELSE CAST((100. * TotalCPU) / @total_cpu AS MONEY) END AS PercentCPU,
            CASE @total_duration WHEN 0 THEN 0
                 ELSE CAST((100. * TotalDuration) / @total_duration AS MONEY) END AS PercentDuration,
            CASE @total_reads WHEN 0 THEN 0
                 ELSE CAST((100. * TotalReads) / @total_reads AS MONEY) END AS PercentReads,
            CASE @total_writes WHEN 0 THEN 0
                 ELSE CAST((100. * TotalWrites) / @total_writes AS MONEY) END AS PercentWrites,            
            CASE @total_execution_count WHEN 0 THEN 0
                 ELSE CAST((100. * ExecutionCount) / @total_execution_count AS MONEY) END AS PercentExecutions,
            CASE  DATEDIFF(mi, PlanCreationTime, LastExecutionTime)
                WHEN 0 THEN 0
                ELSE CAST((1.00 * ExecutionCount / DATEDIFF(mi, PlanCreationTime, LastExecutionTime)) AS money) 
            END AS ExecutionsPerMinute
    FROM (
        SELECT  DatabaseName,
                SqlHandle,
                QueryHash,
                TotalCPU,
                TotalDuration,
                TotalReads,
                TotalWrites,
                ExecutionCount,
                PlanCreationTime,
                LastExecutionTime
        FROM    #procs
        GROUP BY DatabaseName,
                SqlHandle,
                QueryHash,
                TotalCPU,
                TotalDuration,
                TotalReads,
                TotalWrites,
                ExecutionCount,
                PlanCreationTime,
                LastExecutionTime
    ) AS x
) AS y
WHERE   #procs.SqlHandle = y.SqlHandle
        AND #procs.QueryHash = y.QueryHash
        AND #procs.DatabaseName = y.DatabaseName
        AND #procs.PlanHandle IS NULL
OPTION (RECOMPILE) ;



UPDATE #procs
SET NumberOfDistinctPlans = distinct_plan_count,
    NumberOfPlans = number_of_plans,
    QueryPlanCost = CASE WHEN QueryType LIKE '%Stored Procedure%' THEN 
        QueryPlan.value('declare namespace p="http://schemas.microsoft.com/sqlserver/2004/07/showplan";
                         sum(//p:StmtSimple/@StatementSubTreeCost)', 'float')
        ELSE  
        QueryPlan.value('declare namespace p="http://schemas.microsoft.com/sqlserver/2004/07/showplan";
                         sum(//p:StmtSimple[xs:hexBinary(substring(@QueryPlanHash, 3)) = xs:hexBinary(sql:column("QueryPlanHash"))]/@StatementSubTreeCost)', 'float') 
        END,
    missing_index_count = QueryPlan.value('declare namespace p="http://schemas.microsoft.com/sqlserver/2004/07/showplan";
    count(//p:MissingIndexGroup)', 'int') ,
    plan_multiple_plans = CASE WHEN distinct_plan_count < number_of_plans THEN 1 END
FROM (
SELECT COUNT(DISTINCT QueryHash) AS distinct_plan_count,
       COUNT(QueryHash) AS number_of_plans,
       QueryHash
FROM   #procs
GROUP BY QueryHash
) AS x 
WHERE #procs.QueryHash = x.QueryHash
OPTION (RECOMPILE) ;



/* TODO: Create a control table for these parameters */
DECLARE @execution_threshold INT = 1000 ,
        @parameter_sniffing_warning_pct TINYINT = 30,
        /* This is in average reads */
        @parameter_sniffing_io_threshold BIGINT = 100000 ,
        @ctp_threshold_pct TINYINT = 10,
        @long_running_query_warning_seconds INT = 300,
		@long_running_query_warning_seconds_i INT

IF @long_running_query_warning_seconds IS NOT NULL
  SET @long_running_query_warning_seconds_i = CAST((@long_running_query_warning_seconds * 1000.0 * 1000.0) AS INT);

DECLARE @ctp INT ;

SELECT  @ctp = CAST(value AS INT)
FROM    sys.configurations 
WHERE   name = 'cost threshold for parallelism' 
OPTION (RECOMPILE);



/* Update to populate checks columns */
RAISERROR('Checking for query level SQL Server issues.', 0, 1) WITH NOWAIT;

WITH XMLNAMESPACES('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS p)
UPDATE #procs
SET    frequent_execution = CASE WHEN ExecutionsPerMinute > @execution_threshold THEN 1 END ,
       parameter_sniffing = CASE WHEN AverageReads > @parameter_sniffing_io_threshold
                                      AND min_worker_time < ((1.0 - (@parameter_sniffing_warning_pct / 100.0)) * AverageCPU) THEN 1
                                 WHEN AverageReads > @parameter_sniffing_io_threshold
                                      AND max_worker_time > ((1.0 + (@parameter_sniffing_warning_pct / 100.0)) * AverageCPU) THEN 1
                                 WHEN AverageReads > @parameter_sniffing_io_threshold
                                      AND MinReturnedRows < ((1.0 - (@parameter_sniffing_warning_pct / 100.0)) * AverageReturnedRows) THEN 1
                                 WHEN AverageReads > @parameter_sniffing_io_threshold
                                      AND MaxReturnedRows > ((1.0 + (@parameter_sniffing_warning_pct / 100.0)) * AverageReturnedRows) THEN 1 END ,
       near_parallel = CASE WHEN QueryPlanCost BETWEEN @ctp * (1 - (@ctp_threshold_pct / 100.0)) AND @ctp THEN 1 END,
       plan_warnings = CASE WHEN QueryPlan.value('count(//p:Warnings)', 'int') > 0 THEN 1 END,
       long_running = CASE WHEN AverageDuration > @long_running_query_warning_seconds_i THEN 1
                           WHEN max_worker_time > @long_running_query_warning_seconds_i THEN 1
                           WHEN max_elapsed_time > @long_running_query_warning_seconds_i THEN 1 END ,
       implicit_conversions = CASE WHEN QueryPlan.exist('
                                        //p:RelOp//ScalarOperator/@ScalarString
                                        [contains(., "CONVERT_IMPLICIT")]') = 1 THEN 1
                                   WHEN QueryPlan.exist('
                                        //p:PlanAffectingConvert/@Expression
                                        [contains(., "CONVERT_IMPLICIT")]') = 1 THEN 1
                                   END ,
       tempdb_spill = CASE WHEN QueryPlan.value('max(//p:SpillToTempDb/@SpillLevel)', 'int') > 0 THEN 1 END ;       



/* Checks that require examining individual plan nodes, as opposed to
   the entire plan
 */
RAISERROR('Scanning individual plan nodes for query issues.', 0, 1) WITH NOWAIT;

WITH XMLNAMESPACES('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS p)
UPDATE p
SET    busy_loops = CASE WHEN (x.estimated_executions / 100.0) > x.estimated_rows THEN 1 END ,
       tvf_join = CASE WHEN x.tvf_join = 1 THEN 1 END ,
       warning_no_join_predicate = CASE WHEN x.no_join_warning = 1 THEN 1 END
FROM   #procs p
       JOIN (
            SELECT qs.SqlHandle,
                   n.value('@EstimateRows', 'float') AS estimated_rows ,
                   n.value('@EstimateRewinds', 'float') + n.value('@EstimateRebinds', 'float') + 1.0 AS estimated_executions ,
                   n.query('.').exist('/p:RelOp[contains(@LogicalOp, "Join")]/*/p:RelOp[(@LogicalOp[.="Table-valued function"])]') AS tvf_join,
                   n.query('.').exist('//p:RelOp/p:Warnings[(@NoJoinPredicate[.="1"])]') AS no_join_warning
            FROM   #procs qs
                   OUTER APPLY qs.QueryPlan.nodes('//p:RelOp') AS q(n)
       ) AS x ON p.SqlHandle = x.SqlHandle ;



/* Check for timeout plan termination */
RAISERROR('Checking for plan compilation timeouts.', 0, 1) WITH NOWAIT;

WITH XMLNAMESPACES('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS p)
UPDATE p
SET    compile_timeout = CASE WHEN n.query('.').exist('/p:StmtSimple/@StatementOptmEarlyAbortReason[.="TimeOut"]') = 1 THEN 1 END ,
       compile_memory_limit_exceeded = CASE WHEN n.query('.').exist('/p:StmtSimple/@StatementOptmEarlyAbortReason[.="MemoryLimitExceeded"]') = 1 THEN 1 END
FROM   #procs p
       CROSS APPLY p.QueryPlan.nodes('//p:StmtSimple') AS q(n) ;
             


RAISERROR('Checking for forced parameterization and cursors.', 0, 1) WITH NOWAIT;

/* Set options checks */                            
UPDATE p
SET    is_forced_parameterized = CASE WHEN (CAST(pa.value AS INT) & 131072 = 131072) THEN 1
                                      END ,
       is_forced_plan = CASE WHEN (CAST(pa.value AS INT) & 131072 = 131072) THEN 1
                             WHEN (CAST(pa.value AS INT) & 4 = 4) THEN 1
                             END
FROM   #procs p
       CROSS APPLY sys.dm_exec_plan_attributes(p.PlanHandle) pa
WHERE  pa.attribute = 'set_options' ;



/* Cursor checks */
UPDATE p
SET    is_cursor = CASE WHEN CAST(pa.value AS INT) <> 0 THEN 1 END
FROM   #procs p
       CROSS APPLY sys.dm_exec_plan_attributes(p.PlanHandle) pa
WHERE  pa.attribute LIKE '%cursor%' ;



/* Downlevel cardinality estimator */
IF @v >= 12
BEGIN
    RAISERROR('Checking for downlevel cardinality estimators being used on SQL Server 2014.', 0, 1) WITH NOWAIT;
    
    WITH XMLNAMESPACES('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS p)
    UPDATE #procs
    SET    downlevel_estimator = CASE WHEN QueryPlan.value('min(//p:StmtSimple/@CardinalityEstimationModelVersion)', 'int') < (@v * 10) THEN 1 END ;
END



RAISERROR('Populating Warnings column', 0, 1) WITH NOWAIT;

/* Populate warnings */
UPDATE #procs
SET    Warnings = SUBSTRING(
                  CASE WHEN warning_no_join_predicate = 1 THEN ', No Join Predicate' ELSE '' END +
                  CASE WHEN compile_timeout = 1 THEN ', Compilation Timeout' ELSE '' END +
                  CASE WHEN compile_memory_limit_exceeded = 1 THEN ', Compile Memory Limit Exceeded' ELSE '' END +
                  CASE WHEN busy_loops = 1 THEN ', Busy Loops' ELSE '' END +
                  CASE WHEN is_forced_plan = 1 THEN ', Forced Plan' ELSE '' END +
                  CASE WHEN is_forced_parameterized = 1 THEN ', Forced Parameterization' ELSE '' END +
                  CASE WHEN missing_index_count > 0 THEN ', Missing Indexes' ELSE '' END +
                  CASE WHEN is_cursor = 1 THEN ', Cursor' ELSE '' END +
                  CASE WHEN is_parallel = 1 THEN ', Parallel' ELSE '' END +
                  CASE WHEN near_parallel = 1 THEN ', Nearly Parallel' ELSE '' END +
                  CASE WHEN frequent_execution = 1 THEN ', Frequent Execution' ELSE '' END +
                  CASE WHEN plan_warnings = 1 THEN ', Plan Warnings' ELSE '' END +
                  CASE WHEN parameter_sniffing = 1 THEN ', Parameter Sniffing' ELSE '' END +
                  CASE WHEN long_running = 1 THEN ', Long Running Query' ELSE '' END +
                  CASE WHEN downlevel_estimator = 1 THEN ', Downlevel CE' ELSE '' END +
                  CASE WHEN implicit_conversions = 1 THEN ', Implicit Conversions' ELSE '' END +
                  CASE WHEN tempdb_spill = 1 THEN ', TempDB Spills' ELSE '' END +
                  CASE WHEN tvf_join = 1 THEN ', Function Join' ELSE '' END +
                  CASE WHEN plan_multiple_plans = 1 THEN ', Multiple Plans' ELSE '' END
                  , 2, 200000) ;
                  










IF @output_database_name IS NOT NULL
   AND @output_schema_name IS NOT NULL
   AND @output_schema_name IS NOT NULL
BEGIN
    RAISERROR('Writing results to table.', 0, 1) WITH NOWAIT;
    
    /* send results to a table */
    DECLARE @insert_sql NVARCHAR(MAX) = N'' ;
    
    SET @insert_sql = 'USE '
        + @output_database_name
        + '; IF EXISTS(SELECT * FROM '
        + @output_database_name
        + '.INFORMATION_SCHEMA.SCHEMATA WHERE QUOTENAME(SCHEMA_NAME) = '''
        + @output_schema_name
        + ''') AND NOT EXISTS (SELECT * FROM '
        + @output_database_name
        + '.INFORMATION_SCHEMA.TABLES WHERE QUOTENAME(TABLE_SCHEMA) = '''
        + @output_schema_name + ''' AND QUOTENAME(TABLE_NAME) = '''
        + @output_table_name + ''') CREATE TABLE '
        + @output_schema_name + '.'
        + @output_table_name 
        + N'(ID bigint NOT NULL IDENTITY(1,1),
          ServerName nvarchar(256),
          Version nvarchar(256),
          QueryType nvarchar(256),
          Warnings varchar(max),
          DatabaseName sysname,
          AverageCPU bigint,
          TotalCPU bigint,
          PercentCPUByType money,
          CPUWeight money,
          AverageDuration bigint,
          TotalDuration bigint,
          DurationWeight money,
          PercentDurationByType money,
          AverageReads bigint,
          TotalReads bigint,
          ReadWeight money,
          PercentReadsByType money,
          AverageWrites bigint,
          TotalWrites bigint,
          WriteWeight money,
          PercentWritesByType money,
          ExecutionCount bigint,
          ExecutionWeight money,
          PercentExecutionsByType money,' + N'
          ExecutionsPerMinute money,
          PlanCreationTime datetime,
          LastExecutionTime datetime,
          PlanHandle varbinary(64),
          SqlHandle varbinary(64),
          QueryHash binary(8),
          StatementStartOffset int,
          StatementEndOffset int,
          MinReturnedRows bigint,
          MaxReturnedRows bigint,
          AverageReturnedRows money,
          TotalReturnedRows bigint,
          QueryText nvarchar(max),
          QueryPlan xml,
          NumberOfPlans int,
          NumberOfDistinctPlans int,
          SampleTime DATETIME DEFAULT(GETDATE())
          CONSTRAINT [PK_' +CAST(NEWID() AS NCHAR(36)) + '] PRIMARY KEY CLUSTERED(ID))';

    EXEC sp_executesql @insert_sql ;

    SET @insert_sql =N' IF EXISTS(SELECT * FROM '
          + @output_database_name
          + N'.INFORMATION_SCHEMA.SCHEMATA WHERE QUOTENAME(SCHEMA_NAME) = '''
          + @output_schema_name + N''') '
          + 'INSERT '
          + @output_database_name + '.'
          + @output_schema_name + '.'
          + @output_table_name
          + N' (ServerName, Version, QueryType, DatabaseName, AverageCPU, TotalCPU, PercentCPUByType, CPUWeight, AverageDuration, TotalDuration, DurationWeight, PercentDurationByType, AverageReads, TotalReads, ReadWeight, PercentReadsByType, '
          + N' AverageWrites, TotalWrites, WriteWeight, PercentWritesByType, ExecutionCount, ExecutionWeight, PercentExecutionsByType, '
          + N' ExecutionsPerMinute, PlanCreationTime, LastExecutionTime, PlanHandle, SqlHandle, QueryHash, StatementStartOffset, StatementEndOffset, MinReturnedRows, MaxReturnedRows, AverageReturnedRows, TotalReturnedRows, QueryText, QueryPlan, NumberOfPlans, NumberOfDistinctPlans, Warnings) '
          + N'SELECT '
          + QUOTENAME(CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(128)), N'''') + N', '
          + QUOTENAME(CAST(SERVERPROPERTY('ProductVersion') as nvarchar(128)), N'''') + ', '
          + N' QueryType, DatabaseName, AverageCPU, TotalCPU, PercentCPUByType, PercentCPU, AverageDuration, TotalDuration, PercentDuration, PercentDurationByType, AverageReads, TotalReads, PercentReads, PercentReadsByType, '
          + N' AverageWrites, TotalWrites, PercentWrites, PercentWritesByType, ExecutionCount, PercentExecutions, PercentExecutionsByType, '
          + N' ExecutionsPerMinute, PlanCreationTime, LastExecutionTime, PlanHandle, SqlHandle, QueryHash, StatementStartOffset, StatementEndOffset, MinReturnedRows, MaxReturnedRows, AverageReturnedRows, TotalReturnedRows, QueryText, QueryPlan, NumberOfPlans, NumberOfDistinctPlans, Warnings '
          + N' FROM #procs OPTION (RECOMPILE) '
    EXEC sp_executesql @insert_sql;

    RETURN
END
ELSE IF @export_to_excel = 1
BEGIN
    RAISERROR('Displaying results with Excel formatting (no plans).', 0, 1) WITH NOWAIT;
    
    /* excel output */
    UPDATE #procs
    SET QueryText = SUBSTRING(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(QueryText)),' ','<>'),'><',''),'<>',' '), 1, 32000);

    SET @sql = N'
    SELECT  TOP (@top)
            ExecutionCount,
            ExecutionsPerMinute AS [Executions / Minute],
            PercentExecutions AS [Execution Weight],
            PercentExecutionsByType AS [% Executions (Type)],
            QueryType AS [Query Type],
            DatabaseName AS [Database Name],
            QueryText,
            Warnings,
            TotalCPU AS [Total CPU],
            AverageCPU AS [Avg CPU],
            PercentCPU AS [CPU Weight],
            PercentCPUByType AS [% CPU (Type)],
            TotalDuration AS [Total Duration],
            AverageDuration AS [Avg Duration],
            PercentDuration AS [Duration Weight],
            PercentDurationByType AS [% Duration (Type)],
            TotalReads AS [Total Reads],
            AverageReads AS [Average Reads],
            PercentReads AS [Read Weight],
            PercentReadsByType AS [% Reads (Type)],
            TotalWrites AS [Total Writes],
            AverageWrites AS [Average Writes],
            PercentWrites AS [Write Weight],
            PercentWritesByType AS [% Writes (Type)],
            TotalReturnedRows,
            AverageReturnedRows,
            MinReturnedRows,
            MaxReturnedRows,
            NumberOfPlans,
            NumberOfDistinctPlans,
            PlanCreationTime AS [Created At],
            LastExecutionTime AS [Last Execution],
            StatementStartOffset,
            StatementEndOffset
    FROM    #procs 
    WHERE   1 = 1 ' + @nl

    SELECT @sql += N' ORDER BY ' + CASE @sort_order WHEN 'cpu' THEN ' TotalCPU '
                              WHEN 'reads' THEN ' TotalReads '
                              WHEN 'writes' THEN ' TotalWrites '
                              WHEN 'duration' THEN ' TotalDuration '
                              WHEN 'executions' THEN ' ExecutionCount '
                              END + N' DESC '
    
    SET @sql += N' OPTION (RECOMPILE) ; '

    EXEC sp_executesql @sql, N'@top INT', @top ;
    RETURN
END

IF @hide_summary = 0
BEGIN
    RAISERROR('Building query plan summary data.', 0, 1) WITH NOWAIT;

    /* Build summary data */
    IF EXISTS (SELECT 1/0
               FROM   #procs
               WHERE frequent_execution =1)
        INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (1,
                100,
                'Execution Pattern',
                'Frequently Executed Queries',
                'http://brentozar.com/blitzcache/frequently-executed-queries/',
                'Queries are being executed more than '
                + CAST (@execution_threshold AS VARCHAR(5))
                + ' times per minute. This can put additional load on the server, even when queries are lightweight.') ;

    IF EXISTS (SELECT 1/0
               FROM   #procs
               WHERE  parameter_sniffing = 1
              )
        INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (2,
                50,
                'Parameterization',
                'Parameter Sniffing',
                'http://brentozar.com/blitzcache/parameter-sniffing/',
                'There are signs of parameter sniffing (wide variance in rows return or time to execute). Investigate query patterns and tune code appropriately.') ;

    /* Forced execution plans */
    IF EXISTS (SELECT 1/0 
               FROM   #procs
               WHERE  is_forced_parameterized = 1
              )
        INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (3,
                5,
                'Parameterization',
                'Forced Parameterization',
                'http://brentozar.com/blitzcache/forced-parameterization/',
                'Execution plans have been compiled with forced plans, either through FORCEPLAN, plan guides, or forced parameterization. This will make general tuning efforts less effective.');

    /* Cursors */
    IF EXISTS (SELECT 1/0 
               FROM   #procs 
               WHERE  is_cursor = 1
              )
        INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (4, 
                200,
                'Cursors',
                'Cursors',
                'http://brentozar.com/blitzcache/cursors-found-slow-queries/',
                'There are cursors in the plan cache. This is neither good nor bad, but it is a thing. Cursors are weird in SQL Server.');

    IF EXISTS (SELECT 1/0 
               FROM   #procs 
               WHERE  is_forced_parameterized = 1
              )
        INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (5,
                50,
                'Parameterization',
                'Forced Parameterization',
                'http://brentozar.com/blitzcache/forced-parameterization/',
                'Execution plans have been compiled with forced parameterization.') ;

    IF EXISTS (SELECT 1/0
               FROM   #procs p
               WHERE  p.is_parallel = 1
              )
        INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (6,
                200,
                'Execution Plans',
                'Parallelism',
                'http://brentozar.com/blitzcache/parallel-plans-detected/',
                'Parallel plans detected. These warrant investigation, but are neither good nor bad.') ;

    IF EXISTS (SELECT 1/0
               FROM   #procs p
               WHERE  near_parallel = 1
              )
        INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (7,
                200,
                'Execution Plans',
                'Nearly Parallel',
                'http://brentozar.com/blitzcache/queyr-cost-near-cost-threshold-parallelism/',
                'Queries near the cost threshold for parallelism. These may go parallel when you least expect it.') ;

    IF EXISTS (SELECT 1/0
               FROM   #procs p
               WHERE  plan_warnings = 1
              )
        INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (8,
                50,
                'Execution Plans',
                'Query Plan Warnings',
                'http://brentozar.com/blitzcache/query-plan-warnings/',
                'Warnings detected in execution plans. SQL Server is telling you that something bad is going on that requires your attention.') ;

    IF EXISTS (SELECT 1/0
               FROM   #procs p
               WHERE  long_running = 1
              )
        INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (9,
                50,
                'Performance',
                'Long Running Queries',
                'http://brentozar.com/blitzcache/long-running-queries/',
                'Long running queries have beend found. These are queries with an average duration longer than '
                + CAST(@long_running_query_warning_seconds AS VARCHAR(3))
                + ' second(s). These queries should be investigated for additional tuning options') ;

    IF EXISTS (SELECT 1/0
               FROM   #procs p
               WHERE  p.missing_index_count > 0)
        INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (10,
                50,
                'Performance',
                'Missing Index Request',
                'http://brentozar.com/blitzcache/missing-index-request/',
                'Queries found with missing indexes.');

    IF EXISTS (SELECT 1/0
               FROM   #procs p
               WHERE  p.downlevel_estimator = 1
              )
        INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (13,
                200,
                'Cardinality',
                'Legacy Cardinality Estimator in Use',
                'http://brentozar.com/blitzcache/legacy-cardinality-estimator/',
                'A legacy cardinality estimator is being used by one or more queries. Investigate whether you need to be using this cardinality estimator. This may be caused by compatibility levels, global trace flags, or query level trace flags.');

    IF EXISTS (SELECT 1/0
               FROM #procs p
               WHERE implicit_conversions = 1
              )
        INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (14,
                50,
                'Performance',
                'Implicit Conversions',
                'http://brentozar.com/go/implicit',
                'One or more queries are comparing two fields that are not of the same data type.') ;

    IF EXISTS (SELECT 1/0
               FROM   #procs
               WHERE  tempdb_spill = 1
              )
    INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
    VALUES (15,
            10,
            'Performance',
            'TempDB Spills',
            'http://brentozar.com/blitzcache/tempdb-spills/',
            'TempDB spills detected. Queries are unable to allocate enough memory to proceed normally.');

    IF EXISTS (SELECT 1/0
               FROM   #procs
               WHERE  busy_loops = 1)
    INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
    VALUES (16,
            10,
            'Performance',
            'Frequently executed operators',
            'http://brentozar.com/blitzcache/busy-loops/',
            'Operations have been found that are executed 100 times more often than the number of rows returned by each iteration. This is an indicator that something is off in query execution.');

    IF EXISTS (SELECT 1/0
               FROM   #procs
               WHERE  tvf_join = 1)
    INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
    VALUES (17,
            50,
            'Performance',
            'Joining to table valued functions',
            'http://brentozar.com/blitzcache/tvf-join/',
            'Execution plans have been found that join to table valued functions (TVFs). TVFs produce inaccurate estimates of the number of rows returned and can lead to any number of query plan problems.');

    IF EXISTS (SELECT 1/0
               FROM   #procs
               WHERE  compile_timeout = 1)
    INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
    VALUES (18,
            50,
            'Execution Plans',
            'Compilation timeout',
            'http://brentozar.com/blitzcache/compile-timeout/',
            'Query compilation timed out for one or more queries. SQL Server did not find a plan that meets acceptable performance criteria in the time allotted so the best guess was returned. There is a very good chance that this plan isn''t even below average - it''s probably terrible.');

    IF EXISTS (SELECT 1/0
               FROM   #procs
               WHERE  compile_memory_limit_exceeded = 1)
    INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
    VALUES (19,
            50,
            'Execution Plans',
            'Copmilation memory limit exceeded',
            'http://brentozar.com/blitzcache/compile-memory-limit-exceeded/',
            'The optimizer has a limited amount of memory available. One or more queries are complex enough that SQL Server was unable to allocate enough memory to fully optimize the query. A best fit plan was found, and it''s probably terrible.');            

    IF EXISTS (SELECT 1/0
               FROM   #procs
               WHERE  warning_no_join_predicate = 1)
    INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
    VALUES (20,
            10,
            'Execution Plans',
            'No join predicate',
            'http://brentozar.com/blitzcache/no-join-predicate/',
            'Operators in a query have no join predicate. This means that all rows from one table will be matched with all rows from anther table producing a Cartesian product. That''s a whole lot of rows. This may be your goal, but it''s important to investigate why this is happening.');

    IF EXISTS (SELECT 1/0
               FROM   #procs
               WHERE  plan_multiple_plans = 1)
    INSERT INTO #results (CheckID, Priority, FindingsGroup, Finding, URL, Details)
    VALUES (21,
            200,
            'Execution Plans',
            'Multiple execution plans',
            'http://brentozar.com/blitzcache/multiple-plans/',
            'Queries exist with multiple execution plans (as determined by query_plan_hash). Investigate possible ways to parameterize these queries or otherwise reduce the plan count/');


    SELECT  Priority,
            FindingsGroup,
            Finding,
            URL,
            Details
    FROM    #results
    ORDER BY Priority ASC
    OPTION (RECOMPILE);
END



RAISERROR('Displaying analysis of plan cache.', 0, 1) WITH NOWAIT;

DECLARE @columns NVARCHAR(MAX) = N'' ;

IF LOWER(@results) = 'narrow'
BEGIN
    SET @columns = N' DatabaseName AS [Database],
    QueryPlanCost AS [Cost],
    QueryText AS [Query Text],
    QueryType AS [Query Type],
    Warnings AS [Warnings],
    ExecutionCount AS [# Executions],
    AverageCPU AS [Average CPU],
    AverageDuration AS [Average Duration],
    AverageReads AS [Average Reads],
    AverageWrites AS [Average Writes],
    AverageReturnedRows AS [Average Rows Returned],
    PlanCreationTime AS [Created At],
    LastExecutionTime AS [Last Execution],
    QueryPlan AS [Query] ';
END
ELSE IF LOWER(@results) = 'simple'
BEGIN
    SET @columns = N' DatabaseName AS [Database],
    QueryPlanCost AS [Cost],
    QueryText AS [Query Text],
    QueryType AS [Query Type],
    Warnings AS [Warnings],
    ExecutionCount AS [# Executions],
    ExecutionsPerMinute AS [Executions / Minute],
    PercentExecutions AS [Execution Weight],
    TotalCPU AS [Total CPU],
    AverageCPU AS [Avg CPU],
    PercentCPU AS [CPU Weight],
    TotalDuration AS [Total Duration],
    AverageDuration AS [Avg Duration],
    PercentDuration AS [Duration Weight],
    TotalReads AS [Total Reads],
    AverageReads AS [Avg Reads],
    PercentReads AS [Read Weight],
    TotalWrites AS [Total Writes],
    AverageWrites AS [Avg Writes],
    PercentWrites AS [Write Weight],
    AverageReturnedRows AS [Average Rows],
    PlanCreationTime AS [Created At],
    LastExecutionTime AS [Last Execution],
    QueryPlan AS [Query Plan] ';
END
ELSE
BEGIN
   SET @columns = N' DatabaseName AS [Database],
        QueryText AS [Query Text],
        QueryType AS [Query Type],
        Warnings AS [Warnings],
        ExecutionCount AS [# Executions],
        ExecutionsPerMinute AS [Executions / Minute],
        PercentExecutions AS [Execution Weight],
        TotalCPU AS [Total CPU],
        AverageCPU AS [Avg CPU],
        PercentCPU AS [CPU Weight],
        TotalDuration AS [Total Duration],
        AverageDuration AS [Avg Duration],
        PercentDuration AS [Duration Weight],
        TotalReads AS [Total Reads],
        AverageReads AS [Average Reads],
        PercentReads AS [Read Weight],
        TotalWrites AS [Total Writes],
        AverageWrites AS [Average Writes],
        PercentWrites AS [Write Weight],
        PercentExecutionsByType AS [% Executions (Type)],
        PercentCPUByType AS [% CPU (Type)],
        PercentDurationByType AS [% Duration (Type)],
        PercentReadsByType AS [% Reads (Type)],        
        PercentWritesByType AS [% Writes (Type)],
        TotalReturnedRows AS [Total Rows],
        AverageReturnedRows AS [Avg Rows],
        MinReturnedRows AS [Min Rows],
        MaxReturnedRows AS [Max Rows],
        NumberOfPlans AS [# Plans],
        NumberOfDistinctPlans AS [# Distinct Plans],
        PlanCreationTime AS [Created At],
        LastExecutionTime AS [Last Execution],
        QueryPlanCost AS [Query Plan Cost], 
        QueryPlan AS [Query Plan],
        PlanHandle AS [Plan Handle],
        SqlHandle AS [SQL Handle],
        QueryHash AS [Query Hash],
        StatementStartOffset,
        StatementEndOffset ';
END



SET @sql = N'
SELECT  TOP (@top) ' + @columns + @nl + N'
FROM    #procs
WHERE   1 = 1 ' + @nl

SELECT @sql += N' ORDER BY ' + CASE @sort_order WHEN 'cpu' THEN ' TotalCPU '
                            WHEN 'reads' THEN ' TotalReads '
                            WHEN 'writes' THEN ' TotalWrites '
                            WHEN 'duration' THEN ' TotalDuration '
                            WHEN 'executions' THEN ' ExecutionCount '
                            END + N' DESC '
SET @sql += N' OPTION (RECOMPILE) ; '

EXEC sp_executesql @sql, N'@top INT', @top ;


GO



SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

USE master;
GO

IF OBJECT_ID('dbo.sp_BlitzIndex') IS NULL 
	EXEC ('CREATE PROCEDURE dbo.sp_BlitzIndex AS RETURN 0;')
GO
EXEC sys.sp_MS_marksystemobject 'dbo.sp_BlitzIndex';
GO

ALTER PROCEDURE dbo.sp_BlitzIndex
	@database_name NVARCHAR(256) = null,
	@mode tinyint=0, /*0=diagnose, 1=Summarize, 2=Index Usage Detail, 3=Missing Index Detail*/
	@schema_name NVARCHAR(256) = NULL, /*Requires table_name as well.*/
	@table_name NVARCHAR(256) = NULL,  /*Requires schema_name as well.*/
		/*Note:@mode doesn't matter if you're specifying schema_name and @table_name.*/
	@filter tinyint = 0 /* 0=no filter (default). 1=No low-usage warnings for objects with 0 reads. 2=Only warn for objects >= 500MB */
		/*Note:@filter doesn't do anything unless @mode=0*/
/*
sp_BlitzIndex (TM) v2.0 - April 8, 2013

(C) 2013, Brent Ozar Unlimited. 
See http://BrentOzar.com/go/eula for the End User Licensing Agreement.

For help and how-to info, visit http://www.BrentOzar.com/BlitzIndex

Usage examples:
	Diagnose:
		EXEC dbo.sp_BlitzIndex @database_name='AdventureWorks';
	Return detail for a specific table:
		EXEC dbo.sp_BlitzIndex @database_name='AdventureWorks', @schema_name='Person', @table_name='Person';

Known limitations of this version:
 - Does not include FULLTEXT indexes. (A possibility in the future, let us know if you're interested.)
 - Index create statements are just to give you a rough idea of the syntax.
 --		Example: they do not include all the options the index may have been created with (padding, etc.)
 - Doesn't advise you about data modeling for clustered indexes and primary keys (primarily looks for signs of insanity.)
 - Found something? Let us know at help@brentozar.com.

CHANGE LOG (last five versions):
	May 14, 2013 (v2.0) - Added data types and max length to all columns (keys, includes, secret columns)
		Set sp_blitz to default to current DB if database_name is not specified when called
		Added @filter:  
			0=no filter (default)
			1=Don't throw low-usage warnings for objects with 0 reads (helpful for dev/non-production environments)
			2=Only report on objects >= 250MB (helps focus on larger indexes). Still runs a few database-wide checks as well.
		Added list of all columns and types in table for runs using: @database_name, @schema_name, @table_name
		Added count of total number of indexes a column is part of.
		Added check_id 25: Addicted to nullable columns. (All or all but one column is nullable.)
		Added check_id 66 and 67 to flag tables/indexes created within 1 week or modified within 48 hours.
		Added check_id 26: Wide tables (35+ cols or > 2000 non-LOB bytes).
		Added check_id 27: Addicted to strings. Looks for tables with 4 or more columns, of which all or all but one are string or LOB types.
		Added check_id 68: Identity columns within 30% of the end of range (tinyint, smallint, int) AND
			Negative identity seeds or identity increments <> 1
		Added check_id 69: Column collation does not match database collation
		Added check_id 70: Replicated columns. This identifies which columns are in at least one replication publication.
		Added check_id 71: Cascading updates or cascading deletes.
		Split check_id 40 into two checks: fillfactor on nonclustered indexes < 80%, fillfactor on clustered indexes < 90%
		Added check_id 33: Potential filtered indexes based on column names.
		Fixed bug where you couldn't see detailed view for indexed views. 
			(Ex: EXEC dbo.sp_BlitzIndex @database_name='AdventureWorks', @schema_name='Production', @table_name='vProductAndDescription';)
		Added four index usage columns to table detail output: last_user_seek, last_user_scan, last_user_lookup, last_user_update
		Modified check_id 24. This now looks for wide clustered indexes (> 3 columns OR > 16 bytes).
			Previously just simplistically looked for multiple column CX.
		Removed extra spacing (non-breaking) in more_info column.
		Fixed bug where create t-sql didn't include filter (for filtered indexes)
		Fixed formatting bug where "magic number" in table detail view didn't have commas
		Neatened up column names in result sets.
	April 8, 2013 (v1.5) - Fixed breaking bug for partitioned tables with > 10(ish) partitions
		Added schema_name to suggested create statement for PKs
		Handled "magic_benefit_number" values for missing indexes >= 922,337,203,685,477
		Added count of NC indexes to Index Hoarder: Multi-column clustered index finding
		Added link to EULA
		Simplified aggressive index checks (blocking). Multiple checks confused people more than it helped.
			Left only "Total lock wait time > 5 minutes (row + page)".
		Added CheckId 25 for non-unique clustered indexes. 
		The "Create TSQL" column now shows a commented out drop command for disabled non-clustered indexes
		Updated query which joins to sys.dm_operational_stats DMV when running against 2012 for performance reasons
	December 20, 2012 (v1.4) - Fixed bugs for instances using a case-sensitive collation
		Added support to identify compressed indexes
		Added basic support for columnstore, XML, and spatial indexes
		Added "Abnormal Psychology" diagnosis to alert you to special index types in a database
		Removed hypothetical indexes and disabled indexes from "multiple personality disorders"
		Fixed bug where hypothetical indexes weren't showing up in "self-loathing indexes"
		Fixed bug where the partitioning key column was displayed in the key of aligned nonclustered indexes on partitioned tables
		Added set options to the script so procedure is created with required settings for its use of computed columns
	November 20, 2012 - @mode=2 now only returns index definition and usage. Added @mode=3 to return
		missing index data detail only.
	November 13, 2012 - Added secret_columns. This column shows key and included columns in 
		non-clustered indexes that are based on whether the NC index is unique AND whether the base table is 
		a heap, a unique clustered index, or a non-unique clustered index.
		Changed parameter order so @database_name is first. Some people were confused.
*/
AS 

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


DECLARE	@database_id INT;
DECLARE @object_id INT;
DECLARE	@dsql NVARCHAR(MAX);
DECLARE @params NVARCHAR(MAX);
DECLARE	@msg NVARCHAR(4000);
DECLARE	@ErrorSeverity INT;
DECLARE	@ErrorState INT;
DECLARE	@Rowcount BIGINT;
DECLARE @SQLServerProductVersion NVARCHAR(128);
DECLARE @SQLServerEdition INT;
DECLARE @filterMB INT;
DECLARE @collation NVARCHAR(256);

SELECT @SQLServerProductVersion = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128));
SELECT @SQLServerEdition =CAST(SERVERPROPERTY('EngineEdition') AS INT); /* We default to online index creates where EngineEdition=3*/
SET @filterMB=250;

IF @database_name is null 
	SET @database_name=DB_NAME();

SELECT	@database_id = database_id
FROM	sys.databases
WHERE	[name] = @database_name
	AND user_access_desc='MULTI_USER'
	AND state_desc = 'ONLINE';

----------------------------------------
--STEP 1: OBSERVE THE PATIENT
--This step puts index information into temp tables.
----------------------------------------
BEGIN TRY
	BEGIN

		--Validate SQL Server Verson

		IF (SELECT LEFT(@SQLServerProductVersion,
			  CHARINDEX('.',@SQLServerProductVersion,0)-1
			  )) <= 8
		BEGIN
			SET @msg=N'sp_BlitzIndex is only supported on SQL Server 2005 and higher. The version of this instance is: ' + @SQLServerProductVersion;
			RAISERROR(@msg,16,1);
		END

		--Short circuit here if database name does not exist.
		IF @database_name IS NULL OR @database_id IS NULL
		BEGIN
			SET @msg='Database does not exist or is not online/multi-user: cannot proceed.'
			RAISERROR(@msg,16,1);
		END    

		--Validate parameters.
		IF (@mode NOT IN (0,1,2,3))
		BEGIN
			SET @msg=N'Invalid @mode parameter. 0=diagnose, 1=summarize, 2=index detail, 3=missing index detail';
			RAISERROR(@msg,16,1);
		END

		IF (@mode <> 0 AND @table_name IS NOT NULL)
		BEGIN
			SET @msg=N'Setting the @mode doesn''t change behavior if you supply @table_name. Use default @mode=0 to see table detail.';
			RAISERROR(@msg,16,1);
		END

		IF ((@mode <> 0 OR @table_name IS NOT NULL) and @filter <> 0)
		BEGIN
			SET @msg=N'@filter only appies when @mode=0 and @table_name is not specified. Please try again.';
			RAISERROR(@msg,16,1);
		END

		IF (@schema_name IS NOT NULL AND @table_name IS NULL) OR (@table_name IS NOT NULL AND @schema_name IS NULL)
		BEGIN
			SET @msg='You must specify both @schema_name and @table_name, or leave both NULL for summary info.'
			RAISERROR(@msg,16,1);
		END

		--If a table is specified, grab the object id.
		--Short circuit if it doesn't exist.
		IF @table_name IS NOT NULL
		BEGIN
			SET @dsql = N'
					SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
					SELECT	@object_id= OBJECT_ID
					FROM	' + QUOTENAME(@database_name) + N'.sys.objects AS so
					JOIN	' + QUOTENAME(@database_name) + N'.sys.schemas AS sc on 
						so.schema_id=sc.schema_id
					where so.type in (''U'', ''V'')
					and so.name=' + QUOTENAME(@table_name,'''')+ N'
					and sc.name=' + QUOTENAME(@schema_name,'''')+ N'
					/*Has a row in sys.indexes. This lets us get indexed views.*/
					and exists (
						SELECT si.name
						FROM ' + QUOTENAME(@database_name) + '.sys.indexes AS si 
						WHERE so.object_id=si.object_id)
					OPTION (RECOMPILE);';

			SET @params='@object_id INT OUTPUT'				

			IF @dsql IS NULL 
				RAISERROR('@dsql is null',16,1);

			EXEC sp_executesql @dsql, @params, @object_id=@object_id OUTPUT;
			
			IF @object_id IS NULL
					BEGIN
						SET @msg='Table or indexed view does not exist in specified database, please check parameters.'
						RAISERROR(@msg,16,1);
					END
		END

		RAISERROR(N'Starting run. sp_BlitzIndex version 2.0 (May 15, 2013)', 0,1) WITH NOWAIT;

		IF OBJECT_ID('tempdb..#index_sanity') IS NOT NULL 
			DROP TABLE #index_sanity;

		IF OBJECT_ID('tempdb..#index_partition_sanity') IS NOT NULL 
			DROP TABLE #index_partition_sanity;

		IF OBJECT_ID('tempdb..#index_sanity_size') IS NOT NULL 
			DROP TABLE #index_sanity_size;

		IF OBJECT_ID('tempdb..#index_columns') IS NOT NULL 
			DROP TABLE #index_columns;

		IF OBJECT_ID('tempdb..#missing_indexes') IS NOT NULL 
			DROP TABLE #missing_indexes;

		IF OBJECT_ID('tempdb..#foreign_keys') IS NOT NULL 
			DROP TABLE #foreign_keys;

		IF OBJECT_ID('tempdb..#blitz_index_results') IS NOT NULL 
			DROP TABLE #blitz_index_results;
		
		IF OBJECT_ID('tempdb..#index_create_tsql') IS NOT NULL	
			DROP TABLE #index_create_tsql;

		RAISERROR (N'Create temp tables.',0,1) WITH NOWAIT;
		CREATE TABLE #blitz_index_results
			(
			  blitz_result_id INT IDENTITY PRIMARY KEY,
			  check_id INT NOT NULL,
			  index_sanity_id INT NULL,
			  findings_group VARCHAR(50) NOT NULL,
			  finding VARCHAR(200) NOT NULL,
			  URL VARCHAR(200) NOT NULL,
			  details NVARCHAR(4000) NOT NULL,
			  index_definition NVARCHAR(MAX) NOT NULL,
			  secret_columns NVARCHAR(MAX) NULL,
			  index_usage_summary NVARCHAR(MAX) NULL,
			  index_size_summary NVARCHAR(MAX) NULL,
			  create_tsql NVARCHAR(MAX) NULL,
			  more_info NVARCHAR(MAX)NULL
			);

		CREATE TABLE #index_sanity
			(
			  [index_sanity_id] INT IDENTITY PRIMARY KEY,
			  [database_id] SMALLINT NOT NULL ,
			  [object_id] INT NOT NULL ,
			  [index_id] INT NOT NULL ,
			  [index_type] TINYINT NOT NULL,
			  [database_name] NVARCHAR(256) NOT NULL ,
			  [schema_name] NVARCHAR(256) NOT NULL ,
			  [object_name] NVARCHAR(256) NOT NULL ,
			  index_name NVARCHAR(256) NULL ,
			  key_column_names NVARCHAR(MAX) NULL ,
			  key_column_names_with_sort_order NVARCHAR(MAX) NULL ,
			  key_column_names_with_sort_order_no_types NVARCHAR(MAX) NULL ,
			  count_key_columns INT NULL ,
			  include_column_names NVARCHAR(MAX) NULL ,
			  include_column_names_no_types NVARCHAR(MAX) NULL ,
			  count_included_columns INT NULL ,
			  partition_key_column_name NVARCHAR(MAX) NULL,
			  filter_definition NVARCHAR(MAX) NOT NULL ,
			  is_indexed_view BIT NOT NULL ,
			  is_unique BIT NOT NULL ,
			  is_primary_key BIT NOT NULL ,
			  is_XML BIT NOT NULL,
			  is_spatial BIT NOT NULL,
			  is_NC_columnstore BIT NOT NULL,
			  is_disabled BIT NOT NULL ,
			  is_hypothetical BIT NOT NULL ,
			  is_padded BIT NOT NULL ,
			  fill_factor SMALLINT NOT NULL ,
			  user_seeks BIGINT NOT NULL ,
			  user_scans BIGINT NOT NULL ,
			  user_lookups BIGINT NOT  NULL ,
			  user_updates BIGINT NULL ,
			  last_user_seek DATETIME NULL ,
			  last_user_scan DATETIME NULL ,
			  last_user_lookup DATETIME NULL ,
			  last_user_update DATETIME NULL ,
			  is_referenced_by_foreign_key BIT DEFAULT(0),
			  secret_columns NVARCHAR(MAX) NULL,
			  count_secret_columns INT NULL,
			  create_date DATETIME NOT NULL,
			  modify_date DATETIME NOT NULL
			);	

		CREATE TABLE #index_partition_sanity
			(
			  [index_partition_sanity_id] INT IDENTITY PRIMARY KEY ,
			  [index_sanity_id] INT NULL ,
			  [object_id] INT NOT NULL ,
			  [index_id] INT NOT NULL ,
			  [partition_number] INT NOT NULL ,
			  row_count BIGINT NOT NULL ,
			  reserved_MB NUMERIC(29,2) NOT NULL ,
			  reserved_LOB_MB NUMERIC(29,2) NOT NULL ,
			  reserved_row_overflow_MB NUMERIC(29,2) NOT NULL ,
			  leaf_insert_count BIGINT NULL ,
			  leaf_delete_count BIGINT NULL ,
			  leaf_update_count BIGINT NULL ,
			  forwarded_fetch_count BIGINT NULL ,
			  lob_fetch_in_pages BIGINT NULL ,
			  lob_fetch_in_bytes BIGINT NULL ,
			  row_overflow_fetch_in_pages BIGINT NULL ,
			  row_overflow_fetch_in_bytes BIGINT NULL ,
			  row_lock_count BIGINT NULL ,
			  row_lock_wait_count BIGINT NULL ,
			  row_lock_wait_in_ms BIGINT NULL ,
			  page_lock_count BIGINT NULL ,
			  page_lock_wait_count BIGINT NULL ,
			  page_lock_wait_in_ms BIGINT NULL ,
			  index_lock_promotion_attempt_count BIGINT NULL ,
			  index_lock_promotion_count BIGINT NULL,
  			  data_compression_desc VARCHAR(60) NULL
			);

		CREATE TABLE #index_sanity_size
			(
			  [index_sanity_size_id] INT IDENTITY NOT NULL ,
			  [index_sanity_id] INT NOT NULL ,
			  partition_count INT NOT NULL ,
			  total_rows BIGINT NOT NULL ,
			  total_reserved_MB NUMERIC(29,2) NOT NULL ,
			  total_reserved_LOB_MB NUMERIC(29,2) NOT NULL ,
			  total_reserved_row_overflow_MB NUMERIC(29,2) NOT NULL ,
			  total_row_lock_count BIGINT NULL ,
			  total_row_lock_wait_count BIGINT NULL ,
			  total_row_lock_wait_in_ms BIGINT NULL ,
			  avg_row_lock_wait_in_ms BIGINT NULL ,
			  total_page_lock_count BIGINT NULL ,
			  total_page_lock_wait_count BIGINT NULL ,
			  total_page_lock_wait_in_ms BIGINT NULL ,
			  avg_page_lock_wait_in_ms BIGINT NULL ,
 			  total_index_lock_promotion_attempt_count BIGINT NULL ,
			  total_index_lock_promotion_count BIGINT NULL ,
			  data_compression_desc VARCHAR(8000) NULL
			);

		CREATE TABLE #index_columns
			(
			  [object_id] INT NOT NULL ,
			  [index_id] INT NOT NULL ,
			  [key_ordinal] INT NULL ,
			  is_included_column BIT NULL ,
			  is_descending_key BIT NULL ,
			  [partition_ordinal] INT NULL ,
			  column_name NVARCHAR(256) NOT NULL ,
			  system_type_name NVARCHAR(256) NOT NULL,
			  max_length SMALLINT NOT NULL,
			  [precision] TINYINT NOT NULL,
			  [scale] TINYINT NOT NULL,
			  collation_name NVARCHAR(256) NULL,
			  is_nullable bit NULL,
			  is_identity bit NULL,
			  is_computed bit NULL,
			  is_replicated bit NULL,
			  is_sparse bit NULL,
			  is_filestream bit NULL,
			  seed_value BIGINT NULL,
			  increment_value INT NULL ,
			  last_value BIGINT NULL,
			  is_not_for_replication BIT NULL
			);

		CREATE TABLE #missing_indexes
			([object_id] INT NOT NULL,
			[database_name] NVARCHAR(256) NOT NULL ,
			[schema_name] NVARCHAR(256) NOT NULL ,
			[table_name] NVARCHAR(256),
			[statement] NVARCHAR(512) NOT NULL,
			magic_benefit_number AS (( user_seeks + user_scans ) * avg_total_user_cost * avg_user_impact),
			avg_total_user_cost NUMERIC(29,1) NOT NULL,
			avg_user_impact NUMERIC(29,1) NOT NULL,
			user_seeks BIGINT NOT NULL,
			user_scans BIGINT NOT NULL,
			unique_compiles BIGINT NULL,
			equality_columns NVARCHAR(4000), 
			inequality_columns NVARCHAR(4000),
			included_columns NVARCHAR(4000)
			);

		CREATE TABLE #foreign_keys (
			foreign_key_name NVARCHAR(256),
			parent_object_id INT,
			parent_object_name NVARCHAR(256),
			referenced_object_id INT,
			referenced_object_name NVARCHAR(256),
			is_disabled BIT,
			is_not_trusted BIT,
			is_not_for_replication BIT,
			parent_fk_columns NVARCHAR(MAX),
			referenced_fk_columns NVARCHAR(MAX),
			update_referential_action_desc NVARCHAR(16),
			delete_referential_action_desc NVARCHAR(60)
		)
		
		CREATE TABLE #index_create_tsql (
			index_sanity_id INT NOT NULL,
			create_tsql NVARCHAR(MAX) NOT NULL
		)

		--set @collation
		SELECT @collation=collation_name
		FROM sys.databases
		where database_id=@database_id;

		--insert columns for clustered indexes and heaps
		--collect info on identity columns for this one
		SET @dsql = N'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
				SELECT	
					si.object_id, 
					si.index_id, 
					sc.key_ordinal, 
					sc.is_included_column, 
					sc.is_descending_key,
					sc.partition_ordinal,
					c.name as column_name, 
					st.name as system_type_name,
					c.max_length,
					c.[precision],
					c.[scale],
					c.collation_name,
					c.is_nullable,
					c.is_identity,
					c.is_computed,
					c.is_replicated,
					' + case when @SQLServerProductVersion not like '9%' THEN N'c.is_sparse' else N'NULL as is_sparse' END + N',
					' + case when @SQLServerProductVersion not like '9%' THEN N'c.is_filestream' else N'NULL as is_filestream' END + N',
					CAST(ic.seed_value AS BIGINT),
					CAST(ic.increment_value AS INT),
					CAST(ic.last_value AS BIGINT),
					ic.is_not_for_replication
				FROM	' + QUOTENAME(@database_name) + N'.sys.indexes si
				JOIN	' + QUOTENAME(@database_name) + N'.sys.columns c ON
					si.object_id=c.object_id
				LEFT JOIN ' + QUOTENAME(@database_name) + N'.sys.index_columns sc ON 
					sc.object_id = si.object_id
					and sc.index_id=si.index_id
					AND sc.column_id=c.column_id
				LEFT JOIN sys.identity_columns ic ON
					c.object_id=ic.object_id and
					c.column_id=ic.column_id
				JOIN ' + QUOTENAME(@database_name) + N'.sys.types st ON 
					c.system_type_id=st.system_type_id
					AND c.user_type_id=st.user_type_id
				WHERE si.index_id in (0,1) ' 
					+ CASE WHEN @object_id IS NOT NULL 
						THEN N' AND si.object_id=' + CAST(@object_id AS NVARCHAR(30)) 
					ELSE N'' END 
				+ N';';

		IF @dsql IS NULL 
			RAISERROR('@dsql is null',16,1);

		RAISERROR (N'Inserting data into #index_columns for clustered indexes and heaps',0,1) WITH NOWAIT;
		INSERT	#index_columns ( object_id, index_id, key_ordinal, is_included_column, is_descending_key, partition_ordinal,
			column_name, system_type_name, max_length, precision, scale, collation_name, is_nullable, is_identity, is_computed,
			is_replicated, is_sparse, is_filestream, seed_value, increment_value, last_value, is_not_for_replication )
				EXEC sp_executesql @dsql;

		--insert columns for nonclustered indexes
		--this uses a full join to sys.index_columns
		--We don't collect info on identity columns here. They may be in NC indexes, but we just analyze identities in the base table.
		SET @dsql = N'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
				SELECT	
					si.object_id, 
					si.index_id, 
					sc.key_ordinal, 
					sc.is_included_column, 
					sc.is_descending_key,
					sc.partition_ordinal,
					c.name as column_name, 
					st.name as system_type_name,
					c.max_length,
					c.[precision],
					c.[scale],
					c.collation_name,
					c.is_nullable,
					c.is_identity,
					c.is_computed,
					c.is_replicated,
					' + case when @SQLServerProductVersion not like '9%' THEN N'c.is_sparse' else N'NULL as is_sparse' END + N',
					' + case when @SQLServerProductVersion not like '9%' THEN N'c.is_filestream' else N'NULL as is_filestream' END + N'				
				FROM	' + QUOTENAME(@database_name) + N'.sys.indexes si
				JOIN	' + QUOTENAME(@database_name) + N'.sys.columns c ON
					si.object_id=c.object_id
				JOIN ' + QUOTENAME(@database_name) + N'.sys.index_columns sc ON 
					sc.object_id = si.object_id
					and sc.index_id=si.index_id
					AND sc.column_id=c.column_id
				JOIN ' + QUOTENAME(@database_name) + N'.sys.types st ON 
					c.system_type_id=st.system_type_id
					AND c.user_type_id=st.user_type_id
				WHERE si.index_id not in (0,1) ' 
					+ CASE WHEN @object_id IS NOT NULL 
						THEN N' AND si.object_id=' + CAST(@object_id AS NVARCHAR(30)) 
					ELSE N'' END 
				+ N';';

		IF @dsql IS NULL 
			RAISERROR('@dsql is null',16,1);

		RAISERROR (N'Inserting data into #index_columns for nonclustered indexes',0,1) WITH NOWAIT;
		INSERT	#index_columns ( object_id, index_id, key_ordinal, is_included_column, is_descending_key, partition_ordinal,
			column_name, system_type_name, max_length, precision, scale, collation_name, is_nullable, is_identity, is_computed,
			is_replicated, is_sparse, is_filestream )
				EXEC sp_executesql @dsql;
					
		SET @dsql = N'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
				SELECT	' + CAST(@database_id AS NVARCHAR(10)) + ' AS database_id, 
						so.object_id, 
						si.index_id, 
						si.type,
						' + QUOTENAME(@database_name, '''') + ' AS database_name, 
						sc.NAME AS [schema_name],
						so.name AS [object_name], 
						si.name AS [index_name],
						CASE	WHEN so.[type] = CAST(''V'' AS CHAR(2)) THEN 1 ELSE 0 END, 
						si.is_unique, 
						si.is_primary_key, 
						CASE when si.type = 3 THEN 1 ELSE 0 END AS is_XML,
						CASE when si.type = 4 THEN 1 ELSE 0 END AS is_spatial,
						CASE when si.type = 6 THEN 1 ELSE 0 END AS is_NC_columnstore,
						si.is_disabled,
						si.is_hypothetical, 
						si.is_padded, 
						si.fill_factor,'
						+ case when @SQLServerProductVersion not like '9%' THEN '
						CASE WHEN si.filter_definition IS NOT NULL THEN si.filter_definition
							 ELSE ''''
						END AS filter_definition' ELSE ''''' AS filter_definition' END + '
						, ISNULL(us.user_seeks, 0), ISNULL(us.user_scans, 0),
						ISNULL(us.user_lookups, 0), ISNULL(us.user_updates, 0), us.last_user_seek, us.last_user_scan,
						us.last_user_lookup, us.last_user_update,
						so.create_date, so.modify_date
				FROM	' + QUOTENAME(@database_name) + '.sys.indexes AS si WITH (NOLOCK)
						JOIN ' + QUOTENAME(@database_name) + '.sys.objects AS so WITH (NOLOCK) ON si.object_id = so.object_id
											   AND so.is_ms_shipped = 0 /*Exclude objects shipped by Microsoft*/
											   AND so.type <> ''TF'' /*Exclude table valued functions*/
						JOIN ' + QUOTENAME(@database_name) + '.sys.schemas sc ON so.schema_id = sc.schema_id
						LEFT JOIN sys.dm_db_index_usage_stats AS us WITH (NOLOCK) ON si.[object_id] = us.[object_id]
																	   AND si.index_id = us.index_id
																	   AND us.database_id = '+ CAST(@database_id AS NVARCHAR(10)) + '
				WHERE	si.[type] IN ( 0, 1, 2, 3, 4, 6 ) /* Heaps, clustered, nonclustered, XML, spatial, NC Columnstore */ ' +
				CASE WHEN @table_name IS NOT NULL THEN ' and so.name=' + QUOTENAME(@table_name,'''') + ' ' ELSE '' END + 
		'OPTION	( RECOMPILE );
		';
		IF @dsql IS NULL 
			RAISERROR('@dsql is null',16,1);

		RAISERROR (N'Inserting data into #index_sanity',0,1) WITH NOWAIT;
		INSERT	#index_sanity ( [database_id], [object_id], [index_id], [index_type], [database_name], [schema_name], [object_name],
								index_name, is_indexed_view, is_unique, is_primary_key, is_XML, is_spatial, is_NC_columnstore, 
								is_disabled, is_hypothetical, is_padded, fill_factor, filter_definition, user_seeks, user_scans, 
								user_lookups, user_updates, last_user_seek, last_user_scan, last_user_lookup, last_user_update,
								create_date, modify_date )
				EXEC sp_executesql @dsql;

		RAISERROR (N'Updating #index_sanity.key_column_names',0,1) WITH NOWAIT;
		UPDATE	#index_sanity
		SET		key_column_names = D1.key_column_names
		FROM	#index_sanity si
				CROSS APPLY ( SELECT	RTRIM(STUFF( (SELECT	N', ' + c.column_name 
									+ N' {' + system_type_name + N' ' + CAST(max_length AS NVARCHAR(50)) +  N'}'
										AS col_definition
									FROM	#index_columns c
									WHERE	c.object_id = si.object_id
											AND c.index_id = si.index_id
											AND c.is_included_column = 0 /*Just Keys*/
											AND c.key_ordinal > 0 /*Ignore non-key columns, such as partitioning keys*/
									ORDER BY c.object_id, c.index_id, c.key_ordinal	
							FOR	  XML PATH('') ,TYPE).value('.', 'varchar(max)'), 1, 1, ''))
										) D1 ( key_column_names )

		RAISERROR (N'Updating #index_sanity.partition_key_column_name',0,1) WITH NOWAIT;
		UPDATE	#index_sanity
		SET		partition_key_column_name = D1.partition_key_column_name
		FROM	#index_sanity si
				CROSS APPLY ( SELECT	RTRIM(STUFF( (SELECT	N', ' + c.column_name AS col_definition
									FROM	#index_columns c
									WHERE	c.object_id = si.object_id
											AND c.index_id = si.index_id
											AND c.partition_ordinal <> 0 /*Just Partitioned Keys*/
									ORDER BY c.object_id, c.index_id, c.key_ordinal	
							FOR	  XML PATH('') , TYPE).value('.', 'varchar(max)'), 1, 1,''))) D1 
										( partition_key_column_name )

		RAISERROR (N'Updating #index_sanity.key_column_names_with_sort_order',0,1) WITH NOWAIT;
		UPDATE	#index_sanity
		SET		key_column_names_with_sort_order = D2.key_column_names_with_sort_order
		FROM	#index_sanity si
				CROSS APPLY ( SELECT	RTRIM(STUFF( (SELECT	N', ' + c.column_name + CASE c.is_descending_key
									WHEN 1 THEN N' DESC'
									ELSE N''
								+ N' {' + system_type_name + N' ' + CAST(max_length AS NVARCHAR(50)) +  N'}'
								END AS col_definition
							FROM	#index_columns c
							WHERE	c.object_id = si.object_id
									AND c.index_id = si.index_id
									AND c.is_included_column = 0 /*Just Keys*/
									AND c.key_ordinal > 0 /*Ignore non-key columns, such as partitioning keys*/
							ORDER BY c.object_id, c.index_id, c.key_ordinal	
					FOR	  XML PATH('') , TYPE).value('.', 'varchar(max)'), 1, 1, ''))
					) D2 ( key_column_names_with_sort_order )

		RAISERROR (N'Updating #index_sanity.key_column_names_with_sort_order_no_types (for create tsql)',0,1) WITH NOWAIT;
		UPDATE	#index_sanity
		SET		key_column_names_with_sort_order_no_types = D2.key_column_names_with_sort_order_no_types
		FROM	#index_sanity si
				CROSS APPLY ( SELECT	RTRIM(STUFF( (SELECT	N', ' + QUOTENAME(c.column_name) + CASE c.is_descending_key
									WHEN 1 THEN N' [DESC]'
									ELSE N''
								END AS col_definition
							FROM	#index_columns c
							WHERE	c.object_id = si.object_id
									AND c.index_id = si.index_id
									AND c.is_included_column = 0 /*Just Keys*/
									AND c.key_ordinal > 0 /*Ignore non-key columns, such as partitioning keys*/
							ORDER BY c.object_id, c.index_id, c.key_ordinal	
					FOR	  XML PATH('') , TYPE).value('.', 'varchar(max)'), 1, 1, ''))
					) D2 ( key_column_names_with_sort_order_no_types )

		RAISERROR (N'Updating #index_sanity.include_column_names',0,1) WITH NOWAIT;
		UPDATE	#index_sanity
		SET		include_column_names = D3.include_column_names
		FROM	#index_sanity si
				CROSS APPLY ( SELECT	RTRIM(STUFF( (SELECT	N', ' + c.column_name
								+ N' {' + system_type_name + N' ' + CAST(max_length AS NVARCHAR(50)) +  N'}'
								FROM	#index_columns c
								WHERE	c.object_id = si.object_id
										AND c.index_id = si.index_id
										AND c.is_included_column = 1 /*Just includes*/
								ORDER BY c.column_name /*Order doesn't matter in includes, 
										this is here to make rows easy to compare.*/ 
						FOR	  XML PATH('') ,  TYPE).value('.', 'varchar(max)'), 1, 1, ''))
						) D3 ( include_column_names );

		RAISERROR (N'Updating #index_sanity.include_column_names_no_types (for create tsql)',0,1) WITH NOWAIT;
		UPDATE	#index_sanity
		SET		include_column_names_no_types = D3.include_column_names_no_types
		FROM	#index_sanity si
				CROSS APPLY ( SELECT	RTRIM(STUFF( (SELECT	N', ' + QUOTENAME(c.column_name)
								FROM	#index_columns c
								WHERE	c.object_id = si.object_id
										AND c.index_id = si.index_id
										AND c.is_included_column = 1 /*Just includes*/
								ORDER BY c.column_name /*Order doesn't matter in includes, 
										this is here to make rows easy to compare.*/ 
						FOR	  XML PATH('') ,  TYPE).value('.', 'varchar(max)'), 1, 1, ''))
						) D3 ( include_column_names_no_types );

		RAISERROR (N'Updating #index_sanity.count_key_columns and count_include_columns',0,1) WITH NOWAIT;
		UPDATE	#index_sanity
		SET		count_included_columns = D4.count_included_columns,
				count_key_columns = D4.count_key_columns
		FROM	#index_sanity si
				CROSS APPLY ( SELECT	SUM(CASE WHEN is_included_column = 'true' THEN 1
												 ELSE 0
											END) AS count_included_columns,
										SUM(CASE WHEN is_included_column = 'false' AND c.key_ordinal > 0 THEN 1
												 ELSE 0
											END) AS count_key_columns
							  FROM		#index_columns c
							  WHERE		c.object_id = si.object_id
										AND c.index_id = si.index_id 
										) AS D4 ( count_included_columns, count_key_columns );

		IF (SELECT LEFT(@SQLServerProductVersion,
			  CHARINDEX('.',@SQLServerProductVersion,0)-1
			  )) < 11 --Anything prior to 2012
		BEGIN
			--NOTE: we're joining to sys.dm_db_index_operational_stats differently than you might think (not using a cross apply)
			--This is because of quirks prior to SQL Server 2012 with this DMV.
			SET @dsql = N'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
					SELECT	ps.object_id, 
							ps.index_id, 
							ps.partition_number, 
							ps.row_count,
							ps.reserved_page_count * 8. / 1024. AS reserved_MB,
							ps.lob_reserved_page_count * 8. / 1024. AS reserved_LOB_MB,
							ps.row_overflow_reserved_page_count * 8. / 1024. AS reserved_row_overflow_MB,
							os.leaf_insert_count, 
							os.leaf_delete_count, 
							os.leaf_update_count, 
							os.forwarded_fetch_count,
							os.lob_fetch_in_pages, 
							os.lob_fetch_in_bytes, 
							os.row_overflow_fetch_in_pages,
							os.row_overflow_fetch_in_bytes, 
							os.row_lock_count, 
							os.row_lock_wait_count,
							os.row_lock_wait_in_ms, 
							os.page_lock_count, 
							os.page_lock_wait_count, 
							os.page_lock_wait_in_ms,
							os.index_lock_promotion_attempt_count, 
							os.index_lock_promotion_count, 
							' + case when @SQLServerProductVersion not like '9%' THEN 'par.data_compression_desc ' ELSE 'null as data_compression_desc' END + '
					FROM	' + QUOTENAME(@database_name) + '.sys.dm_db_partition_stats AS ps  
					JOIN ' + QUOTENAME(@database_name) + '.sys.partitions AS par on ps.partition_id=par.partition_id
					JOIN ' + QUOTENAME(@database_name) + '.sys.objects AS so ON ps.object_id = so.object_id
							   AND so.is_ms_shipped = 0 /*Exclude objects shipped by Microsoft*/
							   AND so.type <> ''TF'' /*Exclude table valued functions*/
					LEFT JOIN ' + QUOTENAME(@database_name) + '.sys.dm_db_index_operational_stats('
				+ CAST(@database_id AS NVARCHAR(10)) + ', NULL, NULL,NULL) AS os ON
					ps.object_id=os.object_id and ps.index_id=os.index_id and ps.partition_number=os.partition_number 
					WHERE 1=1 
					' + CASE WHEN @object_id IS NOT NULL THEN N'AND so.object_id=' + CAST(@object_id AS NVARCHAR(30)) + N' ' ELSE N' ' END + '
					' + CASE WHEN @filter = 2 THEN N'AND ps.reserved_page_count * 8./1024. > ' + CAST(@filterMB AS NVARCHAR(5)) + N' ' ELSE N' ' END + '
			ORDER BY ps.object_id,  ps.index_id, ps.partition_number
			OPTION	( RECOMPILE );
			';
		END
		ELSE /* Otherwise use this syntax which takes advantage of OUTER APPLY on the os_partitions DMV. 
		This performs much better on 2012 tables using 1000+ partitions. */
		BEGIN
 		SET @dsql = N'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
						SELECT	ps.object_id, 
								ps.index_id, 
								ps.partition_number, 
								ps.row_count,
								ps.reserved_page_count * 8. / 1024. AS reserved_MB,
								ps.lob_reserved_page_count * 8. / 1024. AS reserved_LOB_MB,
								ps.row_overflow_reserved_page_count * 8. / 1024. AS reserved_row_overflow_MB,
								os.leaf_insert_count, 
								os.leaf_delete_count, 
								os.leaf_update_count, 
								os.forwarded_fetch_count,
								os.lob_fetch_in_pages, 
								os.lob_fetch_in_bytes, 
								os.row_overflow_fetch_in_pages,
								os.row_overflow_fetch_in_bytes, 
								os.row_lock_count, 
								os.row_lock_wait_count,
								os.row_lock_wait_in_ms, 
								os.page_lock_count, 
								os.page_lock_wait_count, 
								os.page_lock_wait_in_ms,
								os.index_lock_promotion_attempt_count, 
								os.index_lock_promotion_count, 
								' + case when @SQLServerProductVersion not like '9%' THEN N'par.data_compression_desc ' ELSE N'null as data_compression_desc' END + N'
						FROM	' + QUOTENAME(@database_name) + N'.sys.dm_db_partition_stats AS ps  
						JOIN ' + QUOTENAME(@database_name) + N'.sys.partitions AS par on ps.partition_id=par.partition_id
						JOIN ' + QUOTENAME(@database_name) + N'.sys.objects AS so ON ps.object_id = so.object_id
								   AND so.is_ms_shipped = 0 /*Exclude objects shipped by Microsoft*/
								   AND so.type <> ''TF'' /*Exclude table valued functions*/
						OUTER APPLY ' + QUOTENAME(@database_name) + N'.sys.dm_db_index_operational_stats('
					+ CAST(@database_id AS NVARCHAR(10)) + N', ps.object_id, ps.index_id,ps.partition_number) AS os
						WHERE 1=1 
						' + CASE WHEN @object_id IS NOT NULL THEN N'AND so.object_id=' + CAST(@object_id AS NVARCHAR(30)) + N' ' ELSE N' ' END + N'
						' + CASE WHEN @filter = 2 THEN N'AND ps.reserved_page_count * 8./1024. > ' + CAST(@filterMB AS NVARCHAR(5)) + N' ' ELSE N' ' END + '
				ORDER BY ps.object_id,  ps.index_id, ps.partition_number
				OPTION	( RECOMPILE );
				';
 
		END       

		IF @dsql IS NULL 
			RAISERROR('@dsql is null',16,1);

		RAISERROR (N'Inserting data into #index_partition_sanity',0,1) WITH NOWAIT;
		INSERT	#index_partition_sanity ( [object_id], index_id, partition_number, row_count, reserved_MB,
										  reserved_LOB_MB, reserved_row_overflow_MB, leaf_insert_count,
										  leaf_delete_count, leaf_update_count, forwarded_fetch_count,
										  lob_fetch_in_pages, lob_fetch_in_bytes, row_overflow_fetch_in_pages,
										  row_overflow_fetch_in_bytes, row_lock_count, row_lock_wait_count,
										  row_lock_wait_in_ms, page_lock_count, page_lock_wait_count,
										  page_lock_wait_in_ms, index_lock_promotion_attempt_count,
										  index_lock_promotion_count, data_compression_desc )
				EXEC sp_executesql @dsql;

		RAISERROR (N'Updating index_sanity_id on #index_partition_sanity',0,1) WITH NOWAIT;
		UPDATE	#index_partition_sanity
		SET		index_sanity_id = i.index_sanity_id
		FROM	#index_partition_sanity ps
				JOIN #index_sanity i ON ps.[object_id] = i.[object_id]
										AND ps.index_id = i.index_id

		RAISERROR (N'Inserting data into #index_sanity_size',0,1) WITH NOWAIT;
		INSERT	#index_sanity_size ( [index_sanity_id], partition_count, total_rows, total_reserved_MB,
									 total_reserved_LOB_MB, total_reserved_row_overflow_MB, total_row_lock_count,
									 total_row_lock_wait_count, total_row_lock_wait_in_ms, avg_row_lock_wait_in_ms,
									 total_page_lock_count, total_page_lock_wait_count, total_page_lock_wait_in_ms,
									 avg_page_lock_wait_in_ms, total_index_lock_promotion_attempt_count, 
									 total_index_lock_promotion_count, data_compression_desc )
				SELECT	index_sanity_id, COUNT(*), SUM(row_count), SUM(reserved_MB), SUM(reserved_LOB_MB),
						SUM(reserved_row_overflow_MB), 
						SUM(row_lock_count), 
						SUM(row_lock_wait_count),
						SUM(row_lock_wait_in_ms), 
						CASE WHEN SUM(row_lock_wait_in_ms) > 0 THEN
							SUM(row_lock_wait_in_ms)/(1.*SUM(row_lock_wait_count))
						ELSE 0 END AS avg_row_lock_wait_in_ms,           
						SUM(page_lock_count), 
						SUM(page_lock_wait_count),
						SUM(page_lock_wait_in_ms), 
						CASE WHEN SUM(page_lock_wait_in_ms) > 0 THEN
							SUM(page_lock_wait_in_ms)/(1.*SUM(page_lock_wait_count))
						ELSE 0 END AS avg_page_lock_wait_in_ms,           
						SUM(index_lock_promotion_attempt_count),
						SUM(index_lock_promotion_count),
						LEFT(MAX(data_compression_info.data_compression_rollup),8000)
				FROM	#index_partition_sanity ipp
				/* individual partitions can have distinct compression settings, just roll them into a list here*/
				OUTER APPLY (SELECT STUFF((
					SELECT	N', ' + data_compression_desc
					FROM	#index_partition_sanity ipp2
					WHERE ipp.[object_id]=ipp2.[object_id]
						AND ipp.[index_id]=ipp2.[index_id]
					ORDER BY ipp2.partition_number
					FOR	  XML PATH(''),TYPE).value('.', 'varchar(max)'), 1, 1, '')) 
						data_compression_info(data_compression_rollup)
				GROUP BY index_sanity_id
				ORDER BY index_sanity_id 
		OPTION	( RECOMPILE );

		RAISERROR (N'Adding UQ index on #index_sanity (object_id,index_id)',0,1) WITH NOWAIT;
		CREATE UNIQUE INDEX uq_object_id_index_id ON #index_sanity (object_id,index_id);

		RAISERROR (N'Inserting data into #missing_indexes',0,1) WITH NOWAIT;
		SET @dsql=N'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
				SELECT	id.object_id, ' + QUOTENAME(@database_name,'''') + N', sc.[name], so.[name], id.statement , gs.avg_total_user_cost, 
						gs.avg_user_impact, gs.user_seeks, gs.user_scans, gs.unique_compiles,id.equality_columns, 
						id.inequality_columns,id.included_columns
				FROM	sys.dm_db_missing_index_groups ig
						JOIN sys.dm_db_missing_index_details id ON ig.index_handle = id.index_handle
						JOIN sys.dm_db_missing_index_group_stats gs ON ig.index_group_handle = gs.group_handle
						JOIN ' + QUOTENAME(@database_name) + N'.sys.objects so on 
							id.object_id=so.object_id
						JOIN ' + QUOTENAME(@database_name) + N'.sys.schemas sc on 
							so.schema_id=sc.schema_id
				WHERE	id.database_id = ' + CAST(@database_id AS NVARCHAR(30)) + '
				' + CASE WHEN @object_id IS NULL THEN N'' 
					ELSE N'and id.object_id=' + CAST(@object_id AS NVARCHAR(30)) 
				END +
		N';'

		IF @dsql IS NULL 
			RAISERROR('@dsql is null',16,1);
		INSERT	#missing_indexes ( [object_id], [database_name], [schema_name], [table_name], [statement], avg_total_user_cost, 
									avg_user_impact, user_seeks, user_scans, unique_compiles, equality_columns, 
									inequality_columns,included_columns)
		EXEC sp_executesql @dsql;

		SET @dsql = N'
			SELECT 
				fk_object.name AS foreign_key_name,
				parent_object.[object_id] AS parent_object_id,
				parent_object.name AS parent_object_name,
				referenced_object.[object_id] AS referenced_object_id,
				referenced_object.name AS referenced_object_name,
				fk.is_disabled,
				fk.is_not_trusted,
				fk.is_not_for_replication,
				parent.fk_columns,
				referenced.fk_columns,
				[update_referential_action_desc],
				[delete_referential_action_desc]
			FROM ' + QUOTENAME(@database_name) + N'.sys.foreign_keys fk
			JOIN ' + QUOTENAME(@database_name) + N'.sys.objects fk_object ON fk.object_id=fk_object.object_id
			JOIN ' + QUOTENAME(@database_name) + N'.sys.objects parent_object ON fk.parent_object_id=parent_object.object_id
			JOIN ' + QUOTENAME(@database_name) + N'.sys.objects referenced_object ON fk.referenced_object_id=referenced_object.object_id
			CROSS APPLY ( SELECT	STUFF( (SELECT	N'', '' + c_parent.name AS fk_columns
											FROM	' + QUOTENAME(@database_name) + N'.sys.foreign_key_columns fkc 
											JOIN ' + QUOTENAME(@database_name) + N'.sys.columns c_parent ON fkc.parent_object_id=c_parent.[object_id]
												AND fkc.parent_column_id=c_parent.column_id
											WHERE	fk.parent_object_id=fkc.parent_object_id
												AND fk.[object_id]=fkc.constraint_object_id
											ORDER BY fkc.constraint_column_id 
									FOR	  XML PATH('''') ,
											  TYPE).value(''.'', ''varchar(max)''), 1, 1, '''')/*This is how we remove the first comma*/ ) parent ( fk_columns )
			CROSS APPLY ( SELECT	STUFF( (SELECT	N'', '' + c_referenced.name AS fk_columns
											FROM	' + QUOTENAME(@database_name) + N'.sys.	foreign_key_columns fkc 
											JOIN ' + QUOTENAME(@database_name) + N'.sys.columns c_referenced ON fkc.referenced_object_id=c_referenced.[object_id]
												AND fkc.referenced_column_id=c_referenced.column_id
											WHERE	fk.referenced_object_id=fkc.referenced_object_id
												and fk.[object_id]=fkc.constraint_object_id
											ORDER BY fkc.constraint_column_id  /*order by col name, we don''t have anything better*/
									FOR	  XML PATH('''') ,
											  TYPE).value(''.'', ''varchar(max)''), 1, 1, '''') ) referenced ( fk_columns )
			' + CASE WHEN @object_id IS NOT NULL THEN 
					'WHERE fk.parent_object_id=' + CAST(@object_id AS NVARCHAR(30)) + N' OR fk.referenced_object_id=' + CAST(@object_id AS NVARCHAR(30)) + N' ' 
					ELSE N' ' END + '
			ORDER BY parent_object_name, foreign_key_name;
		';
		IF @dsql IS NULL 
			RAISERROR('@dsql is null',16,1);

        RAISERROR (N'Inserting data into #foreign_keys',0,1) WITH NOWAIT;
        INSERT  #foreign_keys ( foreign_key_name, parent_object_id,parent_object_name, referenced_object_id, referenced_object_name,
                                is_disabled, is_not_trusted, is_not_for_replication, parent_fk_columns, referenced_fk_columns,
								[update_referential_action_desc], [delete_referential_action_desc] )
                EXEC sp_executesql @dsql;

        RAISERROR (N'Updating #index_sanity.referenced_by_foreign_key',0,1) WITH NOWAIT;
		UPDATE #index_sanity
			SET is_referenced_by_foreign_key=1
		FROM #index_sanity s
		JOIN #foreign_keys fk ON 
			s.object_id=fk.referenced_object_id
			AND LEFT(s.key_column_names,LEN(fk.referenced_fk_columns)) = fk.referenced_fk_columns

		RAISERROR (N'Add computed columns to #index_sanity to simplify queries.',0,1) WITH NOWAIT;
		ALTER TABLE #index_sanity ADD 
		[schema_object_name] AS [schema_name] + '.' + [object_name]  ,
		[schema_object_indexid] AS [schema_name] + '.' + [object_name]
			+ CASE WHEN [index_name] IS NOT NULL THEN '.' + index_name
			ELSE ''
			END + ' (' + CAST(index_id AS NVARCHAR(20)) + ')' ,
		first_key_column_name AS CASE	WHEN count_key_columns > 1
			THEN LEFT(key_column_names, CHARINDEX(',', key_column_names, 0) - 1)
			ELSE key_column_names
			END ,
		index_definition AS 
		CASE WHEN partition_key_column_name IS NOT NULL 
			THEN N'[PARTITIONED BY:' + partition_key_column_name +  N']' 
			ELSE '' 
			END +
			CASE index_id
				WHEN 0 THEN N'[HEAP] '
				WHEN 1 THEN N'[CX] '
				ELSE N'' END + CASE WHEN is_indexed_view = 1 THEN '[VIEW] '
				ELSE N'' END + CASE WHEN is_primary_key = 1 THEN N'[PK] '
				ELSE N'' END + CASE WHEN is_XML = 1 THEN N'[XML] '
				ELSE N'' END + CASE WHEN is_spatial = 1 THEN N'[SPATIAL] '
				ELSE N'' END + CASE WHEN is_NC_columnstore = 1 THEN N'[COLUMNSTORE] '
				ELSE N'' END + CASE WHEN is_disabled = 1 THEN N'[DISABLED] '
				ELSE N'' END + CASE WHEN is_hypothetical = 1 THEN N'[HYPOTHETICAL] '
				ELSE N'' END + CASE WHEN is_unique = 1 AND is_primary_key = 0 THEN N'[UNIQUE] '
				ELSE N'' END + CASE WHEN count_key_columns > 0 THEN 
					N'[' + CAST(count_key_columns AS VARCHAR(10)) + N' KEY' 
						+ CASE WHEN count_key_columns > 1 then  N'S' ELSE N'' END
						+ N'] ' + LTRIM(key_column_names_with_sort_order)
				ELSE N'' END + CASE WHEN count_included_columns > 0 THEN 
					N' [' + CAST(count_included_columns AS VARCHAR(10))  + N' INCLUDE' + 
						+ CASE WHEN count_included_columns > 1 then  N'S' ELSE N'' END					
						+ N'] ' + include_column_names
				ELSE N'' END + CASE WHEN filter_definition <> N'' THEN N' [FILTER] ' + filter_definition
				ELSE N'' END ,
		[total_reads] AS user_seeks + user_scans + user_lookups,
		[reads_per_write] AS CAST(CASE WHEN user_updates > 0
			THEN ( user_seeks + user_scans + user_lookups )  / (1.0 * user_updates)
			ELSE 0 END AS MONEY) ,
		[index_usage_summary] AS N'Reads: ' + 
			REPLACE(CONVERT(NVARCHAR(30),CAST((user_seeks + user_scans + user_lookups) AS money), 1), '.00', '')
			+ N'; Writes:' + 
			REPLACE(CONVERT(NVARCHAR(30),CAST(user_updates AS money), 1), '.00', ''),
		[more_info] AS N'EXEC dbo.sp_BlitzIndex @database_name=' + QUOTENAME([database_name],'''') + 
			N', @schema_name=' + QUOTENAME([schema_name],'''') + N', @table_name=' + QUOTENAME([object_name],'''') + N';'

		RAISERROR (N'Update index_secret on #index_sanity for NC indexes.',0,1) WITH NOWAIT;
		UPDATE nc 
		SET secret_columns=
			N'[' + 
			CASE tb.count_key_columns WHEN 0 THEN '1' ELSE CAST(tb.count_key_columns AS VARCHAR(10)) END +
			CASE nc.is_unique WHEN 1 THEN N' INCLUDE' ELSE N' KEY' END +
			CASE WHEN tb.count_key_columns > 1 then  N'S] ' ELSE N'] ' END +
			CASE tb.index_id WHEN 0 THEN '[RID]' ELSE LTRIM(tb.key_column_names) +
				/* Uniquifiers only needed on non-unique clustereds-- not heaps */
				CASE tb.is_unique WHEN 0 THEN ' [UNIQUIFIER]' ELSE N'' END
			END
			, count_secret_columns=
			CASE tb.index_id WHEN 0 THEN 1 ELSE 
				tb.count_key_columns +
					CASE tb.is_unique WHEN 0 THEN 1 ELSE 0 END
			END
		FROM #index_sanity AS nc
		JOIN #index_sanity AS tb ON nc.object_id=tb.object_id
			and tb.index_id in (0,1) 
		WHERE nc.index_id > 1;

		RAISERROR (N'Update index_secret on #index_sanity for heaps and non-unique clustered.',0,1) WITH NOWAIT;
		UPDATE tb
		SET secret_columns=	CASE tb.index_id WHEN 0 THEN '[RID]' ELSE '[UNIQUIFIER]' END
			, count_secret_columns = 1
		FROM #index_sanity AS tb
		WHERE tb.index_id = 0 /*Heaps-- these have the RID */
			or (tb.index_id=1 and tb.is_unique=0); /* Non-unique CX: has uniquifer (when needed) */

		RAISERROR (N'Add computed column to #index_sanity_size to simplify queries.',0,1) WITH NOWAIT;
		ALTER TABLE #index_sanity_size ADD 
			  index_size_summary AS ISNULL(
				CASE WHEN partition_count > 1
						THEN N'[' + CAST(partition_count AS NVARCHAR(10)) + N' PARTITIONS] '
						ELSE N''
				END + REPLACE(CONVERT(NVARCHAR(30),CAST([total_rows] AS money), 1), N'.00', N'') + N' rows; '
				+ CASE WHEN total_reserved_MB > 1024 THEN 
					CAST(CAST(total_reserved_MB/1024. AS NUMERIC(29,1)) AS NVARCHAR(30)) + N'GB'
				ELSE 
					CAST(CAST(total_reserved_MB AS NUMERIC(29,1)) AS NVARCHAR(30)) + N'MB'
				END
				+ CASE WHEN total_reserved_LOB_MB > 1024 THEN 
					N'; ' + CAST(CAST(total_reserved_LOB_MB/1024. AS NUMERIC(29,1)) AS NVARCHAR(30)) + N'GB LOB'
				WHEN total_reserved_LOB_MB > 0 THEN
					N'; ' + CAST(CAST(total_reserved_LOB_MB AS NUMERIC(29,1)) AS NVARCHAR(30)) + N'MB LOB'
				ELSE ''
				END
				 + CASE WHEN total_reserved_row_overflow_MB > 1024 THEN
					N'; ' + CAST(CAST(total_reserved_row_overflow_MB/1024. AS NUMERIC(29,1)) AS NVARCHAR(30)) + N'GB Row Overflow'
				WHEN total_reserved_row_overflow_MB > 0 THEN
					N'; ' + CAST(CAST(total_reserved_row_overflow_MB AS NUMERIC(29,1)) AS NVARCHAR(30)) + N'MB Row Overflow'
				ELSE ''
				END ,
					'Error- NULL in computed column'),
			index_lock_wait_summary AS ISNULL(
				CASE WHEN total_row_lock_wait_count = 0 and  total_page_lock_wait_count = 0 and
					total_index_lock_promotion_attempt_count = 0 THEN N'0 lock waits.'
				ELSE
					CASE WHEN total_row_lock_wait_count > 0 THEN
						N'Row lock waits: ' + REPLACE(CONVERT(NVARCHAR(30),CAST(total_row_lock_wait_count AS money), 1), N'.00', N'')
						+ N'; total duration: ' + 
							CASE WHEN total_row_lock_wait_in_ms >= 60000 THEN /*More than 1 min*/
								REPLACE(CONVERT(NVARCHAR(30),CAST((total_row_lock_wait_in_ms/60000) AS money), 1), N'.00', N'') + N' minutes; '
							ELSE                         
								REPLACE(CONVERT(NVARCHAR(30),CAST(ISNULL(total_row_lock_wait_in_ms/1000,0) AS money), 1), N'.00', N'') + N' seconds; '
							END
						+ N'avg duration: ' + 
							CASE WHEN avg_row_lock_wait_in_ms >= 60000 THEN /*More than 1 min*/
								REPLACE(CONVERT(NVARCHAR(30),CAST((avg_row_lock_wait_in_ms/60000) AS money), 1), N'.00', N'') + N' minutes; '
							ELSE                         
								REPLACE(CONVERT(NVARCHAR(30),CAST(ISNULL(avg_row_lock_wait_in_ms/1000,0) AS money), 1), N'.00', N'') + N' seconds; '
							END
					ELSE N''
					END +
					CASE WHEN total_page_lock_wait_count > 0 THEN
						N'Page lock waits: ' + REPLACE(CONVERT(NVARCHAR(30),CAST(total_page_lock_wait_count AS money), 1), N'.00', N'')
						+ N'; total duration: ' + 
							CASE WHEN total_page_lock_wait_in_ms >= 60000 THEN /*More than 1 min*/
								REPLACE(CONVERT(NVARCHAR(30),CAST((total_page_lock_wait_in_ms/60000) AS money), 1), N'.00', N'') + N' minutes; '
							ELSE                         
								REPLACE(CONVERT(NVARCHAR(30),CAST(ISNULL(total_page_lock_wait_in_ms/1000,0) AS money), 1), N'.00', N'') + N' seconds; '
							END
						+ N'avg duration: ' + 
							CASE WHEN avg_page_lock_wait_in_ms >= 60000 THEN /*More than 1 min*/
								REPLACE(CONVERT(NVARCHAR(30),CAST((avg_page_lock_wait_in_ms/60000) AS money), 1), N'.00', N'') + N' minutes; '
							ELSE                         
								REPLACE(CONVERT(NVARCHAR(30),CAST(ISNULL(avg_page_lock_wait_in_ms/1000,0) AS money), 1), N'.00', N'') + N' seconds; '
							END
					ELSE N''
					END +
					CASE WHEN total_index_lock_promotion_attempt_count > 0 THEN
						N'Lock escalation attempts: ' + REPLACE(CONVERT(NVARCHAR(30),CAST(total_index_lock_promotion_attempt_count AS money), 1), N'.00', N'')
						+ N'; Actual Escalations: ' + REPLACE(CONVERT(NVARCHAR(30),CAST(ISNULL(total_index_lock_promotion_count,0) AS money), 1), N'.00', N'') + N'.'
					ELSE N''
					END
				END                  
					,'Error- NULL in computed column')


		RAISERROR (N'Add computed columns to #missing_index to simplify queries.',0,1) WITH NOWAIT;
		ALTER TABLE #missing_indexes ADD 
				[index_estimated_impact] AS 
					CAST(user_seeks + user_scans AS NVARCHAR(30)) + N' use' 
						+ CASE WHEN (user_seeks + user_scans) > 1 THEN N's' ELSE N'' END
						 +N'; Impact: ' + CAST(avg_user_impact AS NVARCHAR(30))
						+ N'%; Avg query cost: '
						+ CAST(avg_total_user_cost AS NVARCHAR(30)),
				[missing_index_details] AS
					CASE WHEN equality_columns IS NOT NULL THEN N'EQUALITY: ' + equality_columns + N' '
						 ELSE N''
					END + CASE WHEN inequality_columns IS NOT NULL THEN N'INEQUALITY: ' + inequality_columns + N' '
					   ELSE N''
					END + CASE WHEN included_columns IS NOT NULL THEN N'INCLUDES: ' + included_columns + N' '
						ELSE N''
					END,
				[create_tsql] AS N'CREATE INDEX [ix_' + table_name + N'_' 
					+ REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(equality_columns,N'') 
					+ ISNULL(inequality_columns,''),',',''),'[',''),']',''),' ','_') +
					CASE WHEN included_columns IS NOT NULL THEN N'_includes' ELSE N'' END + N'] ON ' + 
					[statement] + N' (' + ISNULL(equality_columns,N'')+
					CASE WHEN equality_columns IS NOT NULL AND inequality_columns IS NOT NULL THEN N', ' ELSE N'' END + 
					CASE WHEN inequality_columns IS NOT NULL THEN inequality_columns ELSE N'' END + 
					') ' + CASE WHEN included_columns IS NOT NULL THEN N' INCLUDE (' + included_columns + N')' ELSE N'' END,
				[more_info] AS N'EXEC dbo.sp_BlitzIndex @database_name=' + QUOTENAME([database_name],'''') + 
					N', @schema_name=	' + QUOTENAME([schema_name],'''') + N', @table_name=' + QUOTENAME([table_name],'''') + N';'
				;


		RAISERROR (N'Populate #index_create_tsql.',0,1) WITH NOWAIT;
		INSERT #index_create_tsql (index_sanity_id, create_tsql)
		SELECT
			index_sanity_id,
			ISNULL (
			/* Script drops for disabled non-clustered indexes*/
			CASE WHEN is_disabled = 1 AND index_id <> 1
				THEN N'--DROP INDEX ' + QUOTENAME([index_name]) + N' ON '
				 + QUOTENAME([schema_name]) + N'.' + QUOTENAME([object_name]) 
			ELSE
				CASE index_id WHEN 0 THEN N'(HEAP)' 
				ELSE 
					CASE WHEN is_XML = 1 OR is_spatial=1 THEN N'' /* Not even trying for these just yet...*/
					ELSE 
						CASE WHEN is_primary_key=1 THEN
							N'ALTER TABLE ' + QUOTENAME([schema_name]) +
								N'.' + QUOTENAME([object_name]) + 
								N' ADD CONSTRAINT [' +
								index_name + 
								N'] PRIMARY KEY ' + 
								CASE WHEN index_id=1 THEN N'CLUSTERED (' ELSE N'(' END +
								key_column_names_with_sort_order_no_types + N' )' 
						ELSE /*Else not a PK */ 
							N'CREATE ' + 
							CASE WHEN is_unique=1 THEN N'UNIQUE ' ELSE N'' END +
							CASE WHEN index_id=1 THEN N'CLUSTERED ' ELSE N'' END +
							CASE WHEN is_NC_columnstore=1 THEN N'NONCLUSTERED COLUMNSTORE ' ELSE N'' END +
							N'INDEX ['
								 + index_name + N'] ON ' + 
								QUOTENAME([schema_name]) + '.' + QUOTENAME([object_name]) + 
									CASE WHEN is_NC_columnstore=1 THEN 
										N' (' + ISNULL(include_column_names_no_types,'') +  N' )' 
									ELSE /*Else not colunnstore */ 
										N' (' + ISNULL(key_column_names_with_sort_order_no_types,'') +  N' )' 
										+ CASE WHEN include_column_names_no_types IS NOT NULL THEN 
											N' INCLUDE (' + include_column_names_no_types + N')' 
											ELSE N'' 
										END
									END /*End non-colunnstore case */ 
								+ CASE WHEN filter_definition <> N'' THEN N' WHERE ' + filter_definition ELSE N'' END
							END /*End Non-PK index CASE */ +
						CASE WHEN (@SQLServerEdition =  3  AND is_NC_columnstore=0 ) THEN + N' WITH (ONLINE=ON);' ELSE N';' END
  					END /*End non-spatial and non-xml CASE */ 
				END
			END, '[Unknown Error]')
				AS create_tsql
		FROM #index_sanity;
					
	END
END TRY
BEGIN CATCH
		RAISERROR (N'Failure populating temp tables.', 0,1) WITH NOWAIT;

		IF @dsql IS NOT NULL
		BEGIN
			SET @msg= 'Last @dsql: ' + @dsql;
			RAISERROR(@msg, 0, 1) WITH NOWAIT;
		END

		SELECT	@msg = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
		RAISERROR (@msg,@ErrorSeverity, @ErrorState )WITH NOWAIT;
		
		
		WHILE @@trancount > 0 
			ROLLBACK;

		RETURN;
END CATCH;

----------------------------------------
--STEP 2: DIAGNOSE THE PATIENT
--EVERY QUERY AFTER THIS GOES AGAINST TEMP TABLES ONLY.
----------------------------------------
BEGIN TRY
----------------------------------------
--If @table_name is specified, just return information for that table.
--The @mode parameter doesn't matter if you're looking at a specific table.
----------------------------------------
IF @table_name IS NOT NULL
BEGIN
	RAISERROR(N'@table_name specified, giving detail only on that table.', 0,1) WITH NOWAIT;

	--We do a left join here in case this is a disabled NC.
	--In that case, it won't have any size info/pages allocated.
	WITH table_mode_cte AS (
		SELECT 
			s.schema_object_indexid, 
			s.key_column_names,
			s.index_definition, 
			ISNULL(s.secret_columns,N'') AS secret_columns,
			s.index_usage_summary, 
			ISNULL(sz.index_size_summary,'') /*disabled NCs will be null*/ AS index_size_summary,
			ISNULL(sz.index_lock_wait_summary,'') AS index_lock_wait_summary,
			s.is_referenced_by_foreign_key,
			(SELECT COUNT(*)
				FROM #foreign_keys fk WHERE fk.parent_object_id=s.object_id
				AND PATINDEX (fk.parent_fk_columns, s.key_column_names)=1) AS FKs_covered_by_index,
			s.last_user_seek,
			s.last_user_scan,
			s.last_user_lookup,
			s.last_user_update,
			s.create_date,
			s.modify_date,
			ct.create_tsql,
			1 as display_order
		FROM #index_sanity s
		LEFT JOIN #index_sanity_size sz ON 
			s.index_sanity_id=sz.index_sanity_id
		LEFT JOIN #index_create_tsql ct ON 
			s.index_sanity_id=ct.index_sanity_id
		WHERE s.[object_id]=@object_id
		UNION ALL
		SELECT 				
				N'sp_BlitzIndex version 2.0 (May 15, 2013)' ,   
				N'From Brent Ozar Unlimited' ,   
				N'http://BrentOzar.com/BlitzIndex' ,
				N'Thanks from the Brent Ozar Unlimited team.  We hope you found this tool useful, and if you need help relieving your SQL Server pains, email us at Help@BrentOzar.com.',
				NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
				0 as display_order
	)
	SELECT 
			schema_object_indexid AS [Details: schema.table.index(indexid)], 
			index_definition AS [Definition: [Property]] ColumnName {datatype maxbytes}], 
			secret_columns AS [Secret Columns],
			index_usage_summary AS [Usage], 
			index_size_summary AS [Size],
			index_lock_wait_summary AS [Lock Waits],
			is_referenced_by_foreign_key AS [Referenced by FK?],
			FKs_covered_by_index AS [FK Covered by Index?],
			last_user_seek AS [Last User Seek],
			last_user_scan AS [Last User Scan],
			last_user_lookup AS [Last User Lookup],
			last_user_update as [Last User Write],
			create_date AS [Created],
			modify_date AS [Last Modified],
			create_tsql AS [Create TSQL]
	FROM table_mode_cte
	ORDER BY display_order ASC, key_column_names ASC
	OPTION	( RECOMPILE );						

	IF (SELECT TOP 1 [object_id] FROM    #missing_indexes mi) IS NOT NULL
	BEGIN  
		SELECT  N'Missing index.' AS Finding ,
				N'http://BrentOzar.com/go/Indexaphobia' AS URL ,
				mi.[statement] + ' Est Benefit: '
					+ CASE WHEN magic_benefit_number >= 922337203685477 THEN '>= 922,337,203,685,477'
					ELSE REPLACE(CONVERT(NVARCHAR(256),CAST(CAST(magic_benefit_number AS BIGINT) AS money), 1), '.00', '')
					END AS [Estimated Benefit],
				missing_index_details AS [Missing Index Request] ,
				index_estimated_impact AS [Estimated Impact],
				create_tsql AS [Create TSQL]
		FROM    #missing_indexes mi
		WHERE   [object_id] = @object_id
		ORDER BY magic_benefit_number DESC
		OPTION	( RECOMPILE );
	END       
	ELSE     
	SELECT 'No missing indexes.' AS finding;

	SELECT 	
		column_name AS [Column Name],
		(SELECT COUNT(*)  
			FROM #index_columns c2 
			WHERE c2.column_name=c.column_name
			and c2.key_ordinal is not null)
		+ CASE WHEN c.index_id = 1 and c.key_ordinal is not null THEN
			-1+ (SELECT COUNT(DISTINCT index_id)
			from #index_columns c3
			where c3.index_id not in (0,1))
			ELSE 0 END
				AS [Found In],
		system_type_name + 
			CASE max_length WHEN -1 THEN N' (max)' ELSE
				CASE  
					WHEN system_type_name in (N'char',N'nchar',N'binary',N'varbinary') THEN N' (' + CAST(max_length as NVARCHAR(20)) + N')' 
					WHEN system_type_name in (N'varchar',N'nvarchar') THEN N' (' + CAST(max_length/2 as NVARCHAR(20)) + N')' 
					ELSE '' 
				END
			END
			AS [Type],
		CASE is_computed WHEN 1 THEN 'yes' ELSE '' END AS [Computed?],
		max_length AS [Length (max bytes)],
		[precision] AS [Prec],
		[scale] AS [Scale],
		CASE is_nullable WHEN 1 THEN 'yes' ELSE '' END AS [Nullable?],
		CASE is_identity WHEN 1 THEN 'yes' ELSE '' END AS [Identity?],
		CASE is_replicated WHEN 1 THEN 'yes' ELSE '' END AS [Replicated?],
		CASE is_sparse WHEN 1 THEN 'yes' ELSE '' END AS [Sparse?],
		CASE is_filestream WHEN 1 THEN 'yes' ELSE '' END AS [Filestream?],
		collation_name AS [Collation]
	FROM #index_columns AS c
	where index_id in (0,1);

	IF (SELECT TOP 1 parent_object_id FROM #foreign_keys) IS NOT NULL
	BEGIN
		SELECT parent_object_name + N': ' + foreign_key_name AS [Foreign Key],
			parent_fk_columns AS [Foreign Key Columns],
			referenced_object_name AS [Referenced Table],
			referenced_fk_columns AS [Referenced Table Columns],
			is_disabled AS [Is Disabled?],
			is_not_trusted as [Not Trusted?],
			is_not_for_replication [Not for Replication?],
			[update_referential_action_desc] as [Cascading Updates?],
			[delete_referential_action_desc] as [Cascading Deletes?]
		FROM #foreign_keys
		ORDER BY [Foreign Key]
		OPTION	( RECOMPILE );
	END
	ELSE
	SELECT 'No foreign keys.' AS finding;
END 

--If @table_name is NOT specified...
--Act based on the @mode and @filter. (@filter applies only when @mode=0 "diagnose")
ELSE
BEGIN;
	IF @mode=0 /* DIAGNOSE*/
	BEGIN;
		RAISERROR(N'@mode=0, we are diagnosing.', 0,1) WITH NOWAIT;

		RAISERROR(N'Insert a row to help people find help', 0,1) WITH NOWAIT;
		INSERT	#blitz_index_results ( check_id, findings_group, finding, URL, details, index_definition,
										index_usage_summary, index_size_summary )
		VALUES  ( 0 , N'Database=' + @database_name, N'sp_BlitzIndex version 2.0 (May 15, 2013)' ,
				N'From Brent Ozar Unlimited' ,   N'http://BrentOzar.com/BlitzIndex' ,
				N'Thanks from the Brent Ozar Unlimited team.  We hope you found this tool useful, and if you need help relieving your SQL Server pains, email us at Help@BrentOzar.com.'
				, N'',N''
				);

		----------------------------------------
		--Multiple Index Personalities: Check_id 0-10
		----------------------------------------
		BEGIN;
		RAISERROR('check_id 1: Duplicate keys', 0,1) WITH NOWAIT;
			WITH	duplicate_indexes
					  AS ( SELECT	[object_id], key_column_names
						   FROM		#index_sanity
						   WHERE  index_type IN (1,2) /* Clustered, NC only*/
								AND is_hypothetical = 0
								AND is_disabled = 0
						   GROUP BY	[object_id], key_column_names
						   HAVING	COUNT(*) > 1)
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	1 AS check_id, 
								ip.index_sanity_id,
								'Multiple Index Personalities' AS findings_group,
								'Duplicate keys' AS finding,
								N'http://BrentOzar.com/go/duplicateindex' AS URL,
								ip.schema_object_indexid AS details,
								ip.index_definition, 
								ip.secret_columns, 
								ip.index_usage_summary,
								ips.index_size_summary
						FROM	duplicate_indexes di
								JOIN #index_sanity ip ON di.[object_id] = ip.[object_id]
														 AND ip.key_column_names = di.key_column_names
								JOIN #index_sanity_size ips ON ip.index_sanity_id = ips.index_sanity_id
						ORDER BY ip.object_id, ip.key_column_names_with_sort_order	
				OPTION	( RECOMPILE );

		RAISERROR('check_id 2: Keys w/ identical leading columns.', 0,1) WITH NOWAIT;
			WITH	borderline_duplicate_indexes
					  AS ( SELECT DISTINCT [object_id], first_key_column_name, key_column_names,
									COUNT([object_id]) OVER ( PARTITION BY [object_id], first_key_column_name ) AS number_dupes
						   FROM		#index_sanity
						   WHERE index_type IN (1,2) /* Clustered, NC only*/
							AND is_hypothetical=0
							AND is_disabled=0)
				INSERT	#blitz_index_results ( check_id, index_sanity_id,  findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	2 AS check_id, 
								ip.index_sanity_id,
								'Multiple Index Personalities' AS findings_group,
								'Borderline duplicate keys' AS finding,
								N'http://BrentOzar.com/go/duplicateindex' AS URL,
								ip.schema_object_indexid AS details, 
								ip.index_definition, 
								ip.secret_columns,
								ip.index_usage_summary,
								ips.index_size_summary
						FROM	#index_sanity AS ip 
						JOIN #index_sanity_size ips ON ip.index_sanity_id = ips.index_sanity_id
						WHERE EXISTS (
							SELECT di.[object_id]
							FROM borderline_duplicate_indexes AS di
							WHERE di.[object_id] = ip.[object_id] AND
								di.first_key_column_name = ip.first_key_column_name AND
								di.key_column_names <> ip.key_column_names AND
								di.number_dupes > 1	
						)
						ORDER BY ip.[schema_name], ip.[object_name], ip.key_column_names, ip.include_column_names
			OPTION	( RECOMPILE );

		END
		----------------------------------------
		--Aggressive Indexes: Check_id 10-19
		----------------------------------------
		BEGIN;

		RAISERROR(N'check_id 11: Total lock wait time > 5 minutes (row + page)', 0,1) WITH NOWAIT;
		INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										secret_columns, index_usage_summary, index_size_summary )
				SELECT	11 AS check_id, 
						i.index_sanity_id,
						N'Aggressive Indexes' AS findings_group,
						N'Total lock wait time > 5 minutes (row + page)' AS finding, 
						N'http://BrentOzar.com/go/AggressiveIndexes' AS URL,
						i.schema_object_indexid + N': ' +
							sz.index_lock_wait_summary AS details, 
						i.index_definition,
						i.secret_columns,
						i.index_usage_summary,
						sz.index_size_summary
				FROM	#index_sanity AS i
				JOIN #index_sanity_size AS sz ON i.index_sanity_id = sz.index_sanity_id
				WHERE	(total_row_lock_wait_in_ms + total_page_lock_wait_in_ms) > 300000
				OPTION	( RECOMPILE );
		END

		---------------------------------------- 
		--Index Hoarder: Check_id 20-29
		----------------------------------------
		BEGIN
			RAISERROR(N'check_id 20: >=7 NC indexes on any given table. Yes, 7 is an arbitrary number.', 0,1) WITH NOWAIT;
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	20 AS check_id, 
								MAX(i.index_sanity_id) AS index_sanity_id, 
								'Index Hoarder' AS findings_group,
								'Many NC indexes on a single table' AS finding,
								N'http://BrentOzar.com/go/IndexHoarder' AS URL,
								CAST (COUNT(*) AS NVARCHAR(30)) + ' NC indexes on ' + i.schema_object_name AS details,
								i.schema_object_name + ' (' + CAST (COUNT(*) AS NVARCHAR(30)) + ' indexes)' AS index_definition,
								'' AS secret_columns,
								REPLACE(CONVERT(NVARCHAR(30),CAST(SUM(total_reads) AS money), 1), N'.00', N'') + N' reads (ALL); '
									+ REPLACE(CONVERT(NVARCHAR(30),CAST(SUM(user_updates) AS money), 1), N'.00', N'') + N' writes (ALL); ',
								REPLACE(CONVERT(NVARCHAR(30),CAST(MAX(total_rows) AS money), 1), N'.00', N'') + N' rows (MAX)'
									+ CASE WHEN SUM(total_reserved_MB) > 1024 THEN 
										N'; ' + CAST(CAST(SUM(total_reserved_MB)/1024. AS NUMERIC(29,1)) AS NVARCHAR(30)) + 'GB (ALL)'
									WHEN SUM(total_reserved_MB) > 0 THEN
										N'; ' + CAST(CAST(SUM(total_reserved_MB) AS NUMERIC(29,1)) AS NVARCHAR(30)) + 'MB (ALL)'
									ELSE ''
									END AS index_size_summary
						FROM	#index_sanity i
						JOIN #index_sanity_size ip ON i.index_sanity_id = ip.index_sanity_id
						WHERE	index_id NOT IN ( 0, 1 )
						GROUP BY schema_object_name
						HAVING	COUNT(*) >= 7
						ORDER BY i.schema_object_name DESC  OPTION	( RECOMPILE );

			if @filter = 1 /*@filter=1 is "ignore unusued" */
			BEGIN
				RAISERROR(N'Skipping checks on unused indexes (21 and 22) because @filter=1', 0,1) WITH NOWAIT;
			END
			ELSE /*Otherwise, go ahead and do the checks*/
			BEGIN
				RAISERROR(N'check_id 21: >=5 percent of indexes are unused. Yes, 5 is an arbitrary number.', 0,1) WITH NOWAIT;
					DECLARE @percent_NC_indexes_unused NUMERIC(29,1);
					DECLARE @NC_indexes_unused_reserved_MB NUMERIC(29,1);

					SELECT	@percent_NC_indexes_unused =( 100.00 * SUM(CASE	WHEN total_reads = 0 THEN 1
												ELSE 0
										   END) ) / COUNT(*) ,
							@NC_indexes_unused_reserved_MB = SUM(CASE WHEN total_reads = 0 THEN sz.total_reserved_MB
									 ELSE 0
								END) 
					FROM	#index_sanity i
					JOIN	#index_sanity_size sz ON i.index_sanity_id = sz.index_sanity_id
					WHERE	index_id NOT IN ( 0, 1 ) 
					OPTION	( RECOMPILE );

				IF @percent_NC_indexes_unused >= 5 
					INSERT	#blitz_index_results ( check_id, index_sanity_id,  findings_group, finding, URL, details, index_definition,
												   secret_columns, index_usage_summary, index_size_summary )
							SELECT	21 AS check_id, 
									MAX(i.index_sanity_id) AS index_sanity_id, 
									N'Index Hoarder' AS findings_group,
									N'More than 5% of NC indexes are unused' AS finding,
									N'http://BrentOzar.com/go/IndexHoarder' AS URL,
									CAST (@percent_NC_indexes_unused AS NVARCHAR(30)) + N'% of NC indexes (' + CAST(COUNT(*) AS NVARCHAR(10)) + N') are unused. ' +
									N'These take up ' + CAST (@NC_indexes_unused_reserved_MB AS NVARCHAR(30)) + N'MB of space.' AS details,
									i.database_name + ' (' + CAST (COUNT(*) AS NVARCHAR(30)) + N' indexes)' AS index_definition,
									'' AS secret_columns, 
									CAST(SUM(total_reads) AS NVARCHAR(256)) + N' reads (ALL); '
										+ CAST(SUM([user_updates]) AS NVARCHAR(256)) + N' writes (ALL)' AS index_usage_summary,
								
									REPLACE(CONVERT(NVARCHAR(30),CAST(MAX([total_rows]) AS money), 1), '.00', '') + N' rows (MAX)'
										+ CASE WHEN SUM(total_reserved_MB) > 1024 THEN 
											N'; ' + CAST(CAST(SUM(total_reserved_MB)/1024. AS NUMERIC(29,1)) AS NVARCHAR(30)) + 'GB (ALL)'
										WHEN SUM(total_reserved_MB) > 0 THEN
											N'; ' + CAST(CAST(SUM(total_reserved_MB) AS NUMERIC(29,1)) AS NVARCHAR(30)) + 'MB (ALL)'
										ELSE ''
										END AS index_size_summary
							FROM	#index_sanity i
							JOIN	#index_sanity_size sz ON i.index_sanity_id = sz.index_sanity_id
							WHERE	index_id NOT IN ( 0, 1 )
									AND total_reads = 0
							GROUP BY i.database_name 
					OPTION	( RECOMPILE );

				RAISERROR(N'check_id 22: NC indexes with 0 reads. (Borderline)', 0,1) WITH NOWAIT;
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	22 AS check_id, 
								i.index_sanity_id,
								N'Index Hoarder' AS findings_group,
								N'Unused NC index' AS finding, 
								N'http://BrentOzar.com/go/IndexHoarder' AS URL,
								N'0 reads: ' + i.schema_object_indexid AS details, 
								i.index_definition, 
								i.secret_columns, 
								i.index_usage_summary,
								sz.index_size_summary
						FROM	#index_sanity AS i
						JOIN	#index_sanity_size AS sz ON i.index_sanity_id = sz.index_sanity_id
						WHERE	i.total_reads=0
								AND i.index_id NOT IN (0,1) /*NCs only*/
						ORDER BY i.schema_object_indexid
						OPTION	( RECOMPILE );
			END /*end checks only run when @filter <> 1*/

			RAISERROR(N'check_id 23: Indexes with 7 or more columns. (Borderline)', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	23 AS check_id, 
							i.index_sanity_id, 
							N'Index Hoarder' AS findings_group,
							N'Borderline: Wide indexes (7 or more columns)' AS finding, 
							N'http://BrentOzar.com/go/IndexHoarder' AS URL,
							CAST(count_key_columns + count_included_columns AS NVARCHAR(10)) + ' columns on '
							+ i.schema_object_indexid AS details, i.index_definition, 
							i.secret_columns, 
							i.index_usage_summary,
							sz.index_size_summary
					FROM	#index_sanity AS i
					JOIN	#index_sanity_size AS sz ON i.index_sanity_id = sz.index_sanity_id
					WHERE	( count_key_columns + count_included_columns ) >= 7
					OPTION	( RECOMPILE );

			RAISERROR(N'check_id 24: Wide clustered indexes (> 3 columns or > 16 bytes).', 0,1) WITH NOWAIT;
				WITH count_columns AS (
							SELECT [object_id],
								SUM(CASE max_length when -1 THEN 0 ELSE max_length END) AS sum_max_length
							FROM #index_columns ic
							WHERE index_id in (1,0) /*Heap or clustered only*/
							and key_ordinal > 0
							GROUP BY object_id
							)
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	24 AS check_id, 
								i.index_sanity_id, 
								N'Index Hoarder' AS findings_group,
								N'Wide clustered index' AS finding,
								N'http://BrentOzar.com/go/IndexHoarder' AS URL,
								CAST (i.count_key_columns AS NVARCHAR(10)) + N' columns with potential size of '
									+ CAST(cc.sum_max_length AS NVARCHAR(10))
									+ N' bytes in clustered index:' + i.schema_object_name 
									+ N'. ' + 
										(SELECT CAST(COUNT(*) AS NVARCHAR(23)) FROM #index_sanity i2 
										WHERE i2.[object_id]=i.[object_id] AND i2.index_id <> 1
										AND i2.is_disabled=0 AND i2.is_hypothetical=0)
										+ N' NC indexes on the table.'
									AS details,
								i.index_definition,
								secret_columns, 
								i.index_usage_summary,
								ip.index_size_summary
						FROM	#index_sanity i
						JOIN	#index_sanity_size ip ON i.index_sanity_id = ip.index_sanity_id
						JOIN	count_columns AS cc ON i.[object_id]=cc.[object_id]	
						WHERE	index_id = 1 /* clustered only */
								AND 
									(count_key_columns > 3 /*More than three key columns.*/
									OR cc.sum_max_length > 15 /*More than 16 bytes in key */)
						ORDER BY i.schema_object_name DESC OPTION	( RECOMPILE );

			RAISERROR(N'check_id 25: Addicted to nullable columns.', 0,1) WITH NOWAIT;
				WITH count_columns AS (
							SELECT [object_id],
								SUM(CASE is_nullable WHEN 1 THEN 0 ELSE 1 END) as non_nullable_columns,
								COUNT(*) as total_columns
							FROM #index_columns ic
							WHERE index_id in (1,0) /*Heap or clustered only*/
							GROUP BY object_id
							)
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	25 AS check_id, 
								i.index_sanity_id, 
								N'Index Hoarder' AS findings_group,
								N'Addicted to nulls' AS finding,
								N'http://BrentOzar.com/go/IndexHoarder' AS URL,
								i.schema_object_name 
									+ N' allows null in ' + CAST((total_columns-non_nullable_columns) as NVARCHAR(10))
									+ N' of ' + CAST(total_columns as NVARCHAR(10))
									+ N' columns.' AS details,
								i.index_definition,
								secret_columns, 
								ISNULL(i.index_usage_summary,''),
								ISNULL(ip.index_size_summary,'')
						FROM	#index_sanity i
						JOIN	#index_sanity_size ip ON i.index_sanity_id = ip.index_sanity_id
						JOIN	count_columns AS cc ON i.[object_id]=cc.[object_id]
						WHERE	i.index_id in (1,0)
							AND cc.non_nullable_columns < 2
							and cc.total_columns > 3
						ORDER BY i.schema_object_name DESC OPTION	( RECOMPILE );

			RAISERROR(N'check_id 26: Wide tables (35+ cols or > 2000 non-LOB bytes).', 0,1) WITH NOWAIT;
				WITH count_columns AS (
							SELECT [object_id],
								SUM(CASE max_length when -1 THEN 1 ELSE 0 END) AS count_lob_columns,
								SUM(CASE max_length when -1 THEN 0 ELSE max_length END) AS sum_max_length,
								COUNT(*) as total_columns
							FROM #index_columns ic
							WHERE index_id in (1,0) /*Heap or clustered only*/
							GROUP BY object_id
							)
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	26 AS check_id, 
								i.index_sanity_id, 
								N'Index Hoarder' AS findings_group,
								N'Wide tables: 35+ cols or > 2000 non-LOB bytes' AS finding,
								N'http://BrentOzar.com/go/IndexHoarder' AS URL,
								i.schema_object_name 
									+ N' has ' + CAST((total_columns) as NVARCHAR(10))
									+ N' total columns with a max possible width of ' + CAST(sum_max_length as NVARCHAR(10))
									+ N' bytes.' +
									CASE WHEN count_lob_columns > 0 THEN CAST((count_lob_columns) as NVARCHAR(10))
										+ ' columns are LOB types.' ELSE ''
									END
										AS details,
								i.index_definition,
								secret_columns, 
								ISNULL(i.index_usage_summary,''),
								ISNULL(ip.index_size_summary,'')
						FROM	#index_sanity i
						JOIN	#index_sanity_size ip ON i.index_sanity_id = ip.index_sanity_id
						JOIN	count_columns AS cc ON i.[object_id]=cc.[object_id]
						WHERE	i.index_id in (1,0)
							and 
							(cc.total_columns >= 35 OR
							cc.sum_max_length >= 2000)
						ORDER BY i.schema_object_name DESC OPTION	( RECOMPILE );
					
			RAISERROR(N'check_id 27: Addicted to strings.', 0,1) WITH NOWAIT;
				WITH count_columns AS (
							SELECT [object_id],
								SUM(CASE WHEN system_type_name in ('varchar','nvarchar','char') or max_length=-1 THEN 1 ELSE 0 END) as string_or_LOB_columns,
								COUNT(*) as total_columns
							FROM #index_columns ic
							WHERE index_id in (1,0) /*Heap or clustered only*/
							GROUP BY object_id
							)
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	27 AS check_id, 
								i.index_sanity_id, 
								N'Index Hoarder' AS findings_group,
								N'Addicted to strings' AS finding,
								N'http://BrentOzar.com/go/IndexHoarder' AS URL,
								i.schema_object_name 
									+ N' uses string or LOB types for ' + CAST((string_or_LOB_columns) as NVARCHAR(10))
									+ N' of ' + CAST(total_columns as NVARCHAR(10))
									+ N' columns. Check if data types are valid.' AS details,
								i.index_definition,
								secret_columns, 
								ISNULL(i.index_usage_summary,''),
								ISNULL(ip.index_size_summary,'')
						FROM	#index_sanity i
						JOIN	#index_sanity_size ip ON i.index_sanity_id = ip.index_sanity_id
						JOIN	count_columns AS cc ON i.[object_id]=cc.[object_id]
						CROSS APPLY (SELECT cc.total_columns - string_or_LOB_columns AS non_string_or_lob_columns) AS calc1
						WHERE	i.index_id in (1,0)
							AND calc1.non_string_or_lob_columns <= 1
							AND cc.total_columns > 3
						ORDER BY i.schema_object_name DESC OPTION	( RECOMPILE );

		END
		 ----------------------------------------
		--Feature-Phobic Indexes: Check_id 30-39
		---------------------------------------- 
		BEGIN
			RAISERROR(N'check_id 30: No indexes with includes', 0,1) WITH NOWAIT;

			DECLARE	@number_indexes_with_includes INT;
			DECLARE	@percent_indexes_with_includes NUMERIC(10, 1);

			SELECT	@number_indexes_with_includes = SUM(CASE WHEN count_included_columns > 0 THEN 1 ELSE 0	END),
					@percent_indexes_with_includes = 100.* 
						SUM(CASE WHEN count_included_columns > 0 THEN 1 ELSE 0 END) / ( 1.0 * COUNT(*) )
			FROM	#index_sanity;

			IF @number_indexes_with_includes = 0 
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	30 AS check_id, 
								NULL AS index_sanity_id, 
								N'Feature-Phobic Indexes' AS findings_group,
								N'No indexes use includes' AS finding, 'http://BrentOzar.com/go/IndexFeatures' AS URL,
								N'No indexes use includes' AS details,
								N'Entire database' AS index_definition, 
								N'' AS secret_columns, 
								N'N/A' AS index_usage_summary, 
								N'N/A' AS index_size_summary OPTION	( RECOMPILE );

			RAISERROR(N'check_id 31: < 3 percent of indexes have includes', 0,1) WITH NOWAIT;
			IF @percent_indexes_with_includes <= 3 AND @number_indexes_with_includes > 0 
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	31 AS check_id,
								NULL AS index_sanity_id, 
								N'Feature-Phobic Indexes' AS findings_group,
								N'Borderline: Includes are used in < 3% of indexes' AS findings,
								N'http://BrentOzar.com/go/IndexFeatures' AS URL,
								N'Only ' + CAST(@percent_indexes_with_includes AS NVARCHAR(10)) + '% of indexes have includes' AS details, 
								N'Entire database' AS index_definition, 
								N'' AS secret_columns,
								N'N/A' AS index_usage_summary, 
								N'N/A' AS index_size_summary OPTION	( RECOMPILE );

			RAISERROR(N'check_id 32: filtered indexes and indexed views', 0,1) WITH NOWAIT;
			DECLARE @count_filtered_indexes INT;
			DECLARE @count_indexed_views INT;

				SELECT	@count_filtered_indexes=COUNT(*)
				FROM	#index_sanity
				WHERE	filter_definition <> '' OPTION	( RECOMPILE );

				SELECT	@count_indexed_views=COUNT(*)
				FROM	#index_sanity AS i
						JOIN #index_sanity_size AS sz ON i.index_sanity_id = sz.index_sanity_id
				WHERE	is_indexed_view = 1 OPTION	( RECOMPILE );

			IF @count_filtered_indexes = 0 AND @count_indexed_views=0
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	32 AS check_id, 
								NULL AS index_sanity_id,
								N'Feature-Phobic Indexes' AS findings_group,
								N'Borderline: No filtered indexes or indexed views exist' AS finding, 
								N'http://BrentOzar.com/go/IndexFeatures' AS URL,
								N'These are NOT always needed-- but do you know when you would use them?' AS details,
								N'Entire database' AS index_definition, 
								N'' AS secret_columns,
								N'N/A' AS index_usage_summary, 
								N'N/A' AS index_size_summary OPTION	( RECOMPILE );
		END;

		RAISERROR(N'check_id 33: Potential filtered indexes based on column names.', 0,1) WITH NOWAIT;

		INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										secret_columns, index_usage_summary, index_size_summary )
		SELECT	33 AS check_id, 
				i.index_sanity_id AS index_sanity_id,
				N'Feature-Phobic Indexes' AS findings_group,
				N'Potential filtered index (based on column name)' AS finding, 
				N'http://BrentOzar.com/go/IndexFeatures' AS URL,
				N'A column name in this index suggests it might be a candidate for filtering (is%, %archive%, %active%, %flag%)' AS details,
				i.index_definition, 
				i.secret_columns,
				i.index_usage_summary, 
				sz.index_size_summary
		FROM #index_columns ic 
		join #index_sanity i on 
			ic.[object_id]=i.[object_id] and
			ic.[index_id]=i.[index_id] and
			i.[index_id] > 1 /* non-clustered index */
		JOIN	#index_sanity_size AS sz ON i.index_sanity_id = sz.index_sanity_id
		WHERE column_name like 'is%'
			or column_name like '%archive%'
			or column_name like '%active%'
			or column_name like '%flag%'
		OPTION	( RECOMPILE );

		 ----------------------------------------
		--Self Loathing Indexes : Check_id 40-49
		----------------------------------------
		BEGIN

			RAISERROR(N'check_id 40: Fillfactor in nonclustered 80 percent or less', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	40 AS check_id, 
							i.index_sanity_id,
							N'Self Loathing Indexes' AS findings_group,
							N'Low Fill Factor: nonclustered index' AS finding, 
							N'http://BrentOzar.com/go/SelfLoathing' AS URL,
							N'Fill factor on ' + schema_object_indexid + N' is ' + CAST(fill_factor AS NVARCHAR(10)) + N'%. '+
								CASE WHEN (last_user_update is null OR user_updates < 1)
								THEN N'No writes have been made.'
								ELSE
									N'Last write was ' +  CONVERT(NVARCHAR(16),last_user_update,121) + N' and ' + 
									CAST(user_updates as NVARCHAR(25)) + N' updates have been made.'
								END
								AS details, 
							i.index_definition,
							i.secret_columns,
							i.index_usage_summary,
							sz.index_size_summary
					FROM	#index_sanity AS i
					JOIN	#index_sanity_size AS sz ON i.index_sanity_id = sz.index_sanity_id
					WHERE	index_id > 1
					and	fill_factor BETWEEN 1 AND 80 OPTION	( RECOMPILE );

			RAISERROR(N'check_id 40: Fillfactor in clustered 90 percent or less', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	40 AS check_id, 
							i.index_sanity_id,
							N'Self Loathing Indexes' AS findings_group,
							N'Low Fill Factor: clustered index' AS finding, 
							N'http://BrentOzar.com/go/SelfLoathing' AS URL,
							N'Fill factor on ' + schema_object_indexid + N' is ' + CAST(fill_factor AS NVARCHAR(10)) + N'%. '+
								CASE WHEN (last_user_update is null OR user_updates < 1)
								THEN N'No writes have been made.'
								ELSE
									N'Last write was ' +  CONVERT(NVARCHAR(16),last_user_update,121) + N' and ' + 
									CAST(user_updates as NVARCHAR(25)) + N' updates have been made.'
								END
								AS details, 
							i.index_definition,
							i.secret_columns,
							i.index_usage_summary,
							sz.index_size_summary
					FROM	#index_sanity AS i
					JOIN #index_sanity_size AS sz ON i.index_sanity_id = sz.index_sanity_id
					WHERE	index_id = 1
					and fill_factor BETWEEN 1 AND 90 OPTION	( RECOMPILE );


			RAISERROR(N'check_id 41: Hypothetical indexes ', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	41 AS check_id, 
							N'Self Loathing Indexes' AS findings_group,
							N'Hypothetical Index' AS finding, 'http://BrentOzar.com/go/SelfLoathing' AS URL,
							N'Hypothetical Index: ' + schema_object_indexid AS details, 
							i.index_definition,
							i.secret_columns,
							N'' AS index_usage_summary, 
							N'' AS index_size_summary
					FROM	#index_sanity AS i
					WHERE	is_hypothetical = 1 OPTION	( RECOMPILE );


			RAISERROR(N'check_id 42: Disabled indexes', 0,1) WITH NOWAIT;
			--Note: disabled NC indexes will have O rows in #index_sanity_size!
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	42 AS check_id, 
							index_sanity_id,
							N'Self Loathing Indexes' AS findings_group,
							N'Disabled Index' AS finding, 
							N'http://BrentOzar.com/go/SelfLoathing' AS URL,
							N'Disabled Index:' + schema_object_indexid AS details, 
							i.index_definition,
							i.secret_columns,
							i.index_usage_summary,
							'DISABLED' AS index_size_summary
					FROM	#index_sanity AS i
					WHERE	is_disabled = 1 OPTION	( RECOMPILE );

			RAISERROR(N'check_id 43: Heaps with forwarded records or deletes', 0,1) WITH NOWAIT;
			WITH	heaps_cte
					  AS ( SELECT	[object_id], SUM(forwarded_fetch_count) AS forwarded_fetch_count,
									SUM(leaf_delete_count) AS leaf_delete_count
						   FROM		#index_partition_sanity
						   GROUP BY	[object_id]
						   HAVING	SUM(forwarded_fetch_count) > 0
									OR SUM(leaf_delete_count) > 0)
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	43 AS check_id, 
								i.index_sanity_id,
								N'Self Loathing Indexes' AS findings_group,
								N'Heaps with forwarded records or deletes' AS finding, 
								N'http://BrentOzar.com/go/SelfLoathing' AS URL,
								CAST(h.forwarded_fetch_count AS NVARCHAR(256)) + ' forwarded fetches, '
								+ CAST(h.leaf_delete_count AS NVARCHAR(256)) + ' deletes against heap:'
								+ schema_object_indexid AS details, 
								i.index_definition, 
								i.secret_columns,
								i.index_usage_summary,
								sz.index_size_summary
						FROM	#index_sanity i
						JOIN heaps_cte h ON i.[object_id] = h.[object_id]
						JOIN #index_sanity_size sz ON i.index_sanity_id = sz.index_sanity_id
						WHERE	i.index_id = 0 
				OPTION	( RECOMPILE );

			RAISERROR(N'check_id 44: Heaps with reads or writes.', 0,1) WITH NOWAIT;
			WITH	heaps_cte
					  AS ( SELECT	[object_id], SUM(forwarded_fetch_count) AS forwarded_fetch_count,
									SUM(leaf_delete_count) AS leaf_delete_count
						   FROM		#index_partition_sanity
						   GROUP BY	[object_id]
						   HAVING	SUM(forwarded_fetch_count) > 0
									OR SUM(leaf_delete_count) > 0)
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	44 AS check_id, 
								i.index_sanity_id,
								N'Self Loathing Indexes' AS findings_group,
								N'Active heap' AS finding, 
								N'http://BrentOzar.com/go/SelfLoathing' AS URL,
								N'Should this table be a heap? ' + schema_object_indexid AS details, 
								i.index_definition, 
								'N/A' AS secret_columns,
								i.index_usage_summary,
								sz.index_size_summary
						FROM	#index_sanity i
						LEFT JOIN heaps_cte h ON i.[object_id] = h.[object_id]
						JOIN #index_sanity_size sz ON i.index_sanity_id = sz.index_sanity_id
						WHERE	i.index_id = 0 
								AND 
									(i.total_reads > 0 OR i.user_updates > 0)
								AND h.[object_id] IS NULL /*don't duplicate the prior check.*/
				OPTION	( RECOMPILE );


			END;
		----------------------------------------
		--Indexaphobia
		--Missing indexes with value >= 5 million: : Check_id 50-59
		----------------------------------------
		BEGIN
			RAISERROR(N'check_id 50: Indexaphobia.', 0,1) WITH NOWAIT;
			WITH	index_size_cte
					  AS ( SELECT	i.[object_id], 
									MAX(i.index_sanity_id) AS index_sanity_id,
								ISNULL (
									CAST(SUM(CASE WHEN index_id NOT IN (0,1) THEN 1 ELSE 0 END)
										 AS NVARCHAR(30))+ N' NC indexes exist (' + 
									CASE WHEN SUM(CASE WHEN index_id NOT IN (0,1) THEN sz.total_reserved_MB ELSE 0 END) > 1024
										THEN CAST(CAST(SUM(CASE WHEN index_id NOT IN (0,1) THEN sz.total_reserved_MB ELSE 0 END )/1024. 
											AS NUMERIC(29,1)) AS NVARCHAR(30)) + N'GB); ' 
										ELSE CAST(SUM(CASE WHEN index_id NOT IN (0,1) THEN sz.total_reserved_MB ELSE 0 END) 
											AS NVARCHAR(30)) + N'MB); '
									END + 
										CASE WHEN MAX(sz.[total_rows]) >= 922337203685477 THEN '>= 922,337,203,685,477'
										ELSE REPLACE(CONVERT(NVARCHAR(30),CAST(MAX(sz.[total_rows]) AS money), 1), '.00', '') 
										END +
									+ N' Estimated Rows;' 
								,N'') AS index_size_summary
							FROM	#index_sanity AS i
							LEFT	JOIN #index_sanity_size AS sz ON i.index_sanity_id = sz.index_sanity_id
						   GROUP BY	i.[object_id])
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   index_usage_summary, index_size_summary, create_tsql, more_info )
						SELECT	50 AS check_id, 
								sz.index_sanity_id,
								N'Indexaphobia' AS findings_group,
								N'High value missing index' AS finding, 
								N'http://BrentOzar.com/go/Indexaphobia' AS URL,
								mi.[statement] + ' estimated benefit: ' + 
									CASE WHEN magic_benefit_number >= 922337203685477 THEN '>= 922,337,203,685,477'
									ELSE REPLACE(CONVERT(NVARCHAR(256),CAST(CAST(magic_benefit_number AS BIGINT) AS money), 1), '.00', '') 
									END AS details,
								missing_index_details AS [definition],
								index_estimated_impact,
								sz.index_size_summary,
								mi.create_tsql,
								mi.more_info
				FROM	#missing_indexes mi
						LEFT JOIN index_size_cte sz ON mi.[object_id] = sz.object_id
				WHERE magic_benefit_number > 500000
				ORDER BY magic_benefit_number DESC;

	END
		 ----------------------------------------
		--Abnormal Psychology : Check_id 60-69
		----------------------------------------
	BEGIN
			RAISERROR(N'check_id 60: XML indexes', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	60 AS check_id, 
							i.index_sanity_id,
							N'Abnormal Psychology' AS findings_group,
							N'XML Indexes' AS finding, 
							N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
							i.schema_object_indexid AS details, 
							i.index_definition,
							i.secret_columns,
							N'' AS index_usage_summary,
							ISNULL(sz.index_size_summary,'') AS index_size_summary
					FROM	#index_sanity AS i
					JOIN #index_sanity_size sz ON i.index_sanity_id = sz.index_sanity_id
					WHERE i.is_XML = 1 OPTION	( RECOMPILE );

			RAISERROR(N'check_id 61: NC Columnstore indexes', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	61 AS check_id, 
							i.index_sanity_id,
							N'Abnormal Psychology' AS findings_group,
							N'NC Columnstore indexes' AS finding, 
							N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
							i.schema_object_indexid AS details, 
							i.index_definition,
							i.secret_columns,
							i.index_usage_summary,
							ISNULL(sz.index_size_summary,'') AS index_size_summary
					FROM	#index_sanity AS i
					JOIN #index_sanity_size sz ON i.index_sanity_id = sz.index_sanity_id
					WHERE i.is_NC_columnstore = 1 OPTION	( RECOMPILE );


			RAISERROR(N'check_id 62: Spatial indexes', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	62 AS check_id, 
							i.index_sanity_id,
							N'Abnormal Psychology' AS findings_group,
							N'Spatial indexes' AS finding, 
							N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
							i.schema_object_indexid AS details, 
							i.index_definition,
							i.secret_columns,
							i.index_usage_summary,
							ISNULL(sz.index_size_summary,'') AS index_size_summary
					FROM	#index_sanity AS i
					JOIN #index_sanity_size sz ON i.index_sanity_id = sz.index_sanity_id
					WHERE i.is_spatial = 1 OPTION	( RECOMPILE );

			RAISERROR(N'check_id 63: Compressed indexes', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	63 AS check_id, 
							i.index_sanity_id,
							N'Abnormal Psychology' AS findings_group,
							N'Compressed indexes' AS finding, 
							N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
							i.schema_object_indexid  + N'. COMPRESSION: ' + sz.data_compression_desc AS details, 
							i.index_definition,
							i.secret_columns,
							i.index_usage_summary,
							ISNULL(sz.index_size_summary,'') AS index_size_summary
					FROM	#index_sanity AS i
					JOIN #index_sanity_size sz ON i.index_sanity_id = sz.index_sanity_id
					WHERE sz.data_compression_desc LIKE '%PAGE%' OR sz.data_compression_desc LIKE '%ROW%' OPTION	( RECOMPILE );

			RAISERROR(N'check_id 64: Partitioned', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	64 AS check_id, 
							i.index_sanity_id,
							N'Abnormal Psychology' AS findings_group,
							N'Partitioned indexes' AS finding, 
							N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
							i.schema_object_indexid AS details, 
							i.index_definition,
							i.secret_columns,
							i.index_usage_summary,
							ISNULL(sz.index_size_summary,'') AS index_size_summary
					FROM	#index_sanity AS i
					JOIN #index_sanity_size sz ON i.index_sanity_id = sz.index_sanity_id
					WHERE i.partition_key_column_name IS NOT NULL OPTION	( RECOMPILE );

			RAISERROR(N'check_id 65: Non-Aligned Partitioned', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	65 AS check_id, 
							i.index_sanity_id,
							N'Abnormal Psychology' AS findings_group,
							N'Non-Aligned index on a partitioned table' AS finding, 
							N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
							i.schema_object_indexid AS details, 
							i.index_definition,
							i.secret_columns,
							i.index_usage_summary,
							ISNULL(sz.index_size_summary,'') AS index_size_summary
					FROM	#index_sanity AS i
					JOIN #index_sanity AS iParent ON
						i.[object_id]=iParent.[object_id]
						AND iParent.index_id IN (0,1) /* could be a partitioned heap or clustered table */
						AND iParent.partition_key_column_name IS NOT NULL /* parent is partitioned*/         
					JOIN #index_sanity_size sz ON i.index_sanity_id = sz.index_sanity_id
					WHERE i.partition_key_column_name IS NULL 
						OPTION	( RECOMPILE );

			RAISERROR(N'check_id 66: Recently created tables/indexes (1 week)', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	66 AS check_id, 
							i.index_sanity_id,
							N'Abnormal Psychology' AS findings_group,
							N'Recently created tables/indexes (1 week)' AS finding, 
							N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
							i.schema_object_indexid + N' was created on ' + 
								CONVERT(NVARCHAR(16),i.create_date,121) + 
								N'. Tables/indexes which are dropped/created regularly require special methods for index tuning.'
									 AS details, 
							i.index_definition,
							i.secret_columns,
							i.index_usage_summary,
							ISNULL(sz.index_size_summary,'') AS index_size_summary
					FROM	#index_sanity AS i
					JOIN #index_sanity_size sz ON i.index_sanity_id = sz.index_sanity_id
					WHERE i.create_date >= DATEADD(dd,-7,GETDATE()) 
						OPTION	( RECOMPILE );

			RAISERROR(N'check_id 67: Recently modified tables/indexes (2 days)', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
										   secret_columns, index_usage_summary, index_size_summary )
					SELECT	67 AS check_id, 
							i.index_sanity_id,
							N'Abnormal Psychology' AS findings_group,
							N'Recently modified tables/indexes (2 days)' AS finding, 
							N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
							i.schema_object_indexid + N' was modified on ' + 
								CONVERT(NVARCHAR(16),i.modify_date,121) + 
								N'. A large amount of recently modified indexes may mean a lot of rebuilds are occurring each night.'
									 AS details, 
							i.index_definition,
							i.secret_columns,
							i.index_usage_summary,
							ISNULL(sz.index_size_summary,'') AS index_size_summary
					FROM	#index_sanity AS i
					JOIN #index_sanity_size sz ON i.index_sanity_id = sz.index_sanity_id
					WHERE i.modify_date > DATEADD(dd,-2,GETDATE()) 
					and /*Exclude recently created tables unless they've been modified after being created.*/
					(i.create_date < DATEADD(dd,-7,GETDATE()) or i.create_date <> i.modify_date)
						OPTION	( RECOMPILE );

			RAISERROR(N'check_id 68: Identity columns within 30% of the end of range', 0,1) WITH NOWAIT;
			-- Allowed Ranges: 
				--int -2,147,483,648 to 2,147,483,647
				--smallint -32,768 to 32,768
				--tinyint 0 to 255
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	68 AS check_id, 
								i.index_sanity_id, 
								N'Abnormal Psychology' AS findings_group,
								N'Identity column within ' + 									
									CAST (calc1.percent_remaining as nvarchar(256))
									+ N'% of end of range' AS finding,
								N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
								i.schema_object_name + N'.' +  QUOTENAME(ic.column_name)
									+ N' is an identity with type ' + ic.system_type_name 
									+ N', last value of ' 
										+ ISNULL(REPLACE(CONVERT(NVARCHAR(256),CAST(CAST(ic.last_value AS BIGINT) AS money), 1), '.00', ''),N'NULL')
									+ N', seed of '
										+ ISNULL(REPLACE(CONVERT(NVARCHAR(256),CAST(CAST(ic.seed_value AS BIGINT) AS money), 1), '.00', ''),N'NULL')
									+ N', increment of ' + CAST(ic.increment_value AS NVARCHAR(256)) 
									+ N', and range of ' +
										CASE ic.system_type_name WHEN 'int' THEN N'+/- 2,147,483,647'
											WHEN 'smallint' THEN N'+/- 32,768'
											WHEN 'tinyint' THEN N'0 to 255'
										END
										AS details,
								i.index_definition,
								secret_columns, 
								ISNULL(i.index_usage_summary,''),
								ISNULL(ip.index_size_summary,'')
						FROM	#index_sanity i
						JOIN	#index_columns ic on
							i.object_id=ic.object_id
							and ic.is_identity=1
							and ic.system_type_name in ('tinyint', 'smallint', 'int')
						JOIN	#index_sanity_size ip ON i.index_sanity_id = ip.index_sanity_id
						CROSS APPLY (
							SELECT CAST(CASE WHEN ic.increment_value >= 0
									THEN
										CASE ic.system_type_name 
											WHEN 'int' then (2147483647 - (ISNULL(ic.last_value,ic.seed_value) + ic.increment_value)) / 2147483647.*100
											WHEN 'smallint' then (32768 - (ISNULL(ic.last_value,ic.seed_value) + ic.increment_value)) / 32768.*100
											WHEN 'tinyint' then ( 255 - (ISNULL(ic.last_value,ic.seed_value) + ic.increment_value)) / 255.*100
											ELSE 999
										END
								ELSE --ic.increment_value is negative
										CASE ic.system_type_name 
											WHEN 'int' then ABS(-2147483647 - (ISNULL(ic.last_value,ic.seed_value) + ic.increment_value)) / 2147483647.*100
											WHEN 'smallint' then ABS(-32768 - (ISNULL(ic.last_value,ic.seed_value) + ic.increment_value)) / 32768.*100
											WHEN 'tinyint' then ABS( 0 - (ISNULL(ic.last_value,ic.seed_value) + ic.increment_value)) / 255.*100
											ELSE -1
										END 
								END AS NUMERIC(4,1)) AS percent_remaining
								) as calc1
						WHERE	i.index_id in (1,0)
							and calc1.percent_remaining <= 30
						UNION ALL
						SELECT	68 AS check_id, 
								i.index_sanity_id, 
								N'Abnormal Psychology' AS findings_group,
								N'Identity column using a negative seed or increment other than 1' AS finding,
								N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
								i.schema_object_name + N'.' +  QUOTENAME(ic.column_name)
									+ N' is an identity with type ' + ic.system_type_name 
									+ N', last value of ' 
										+ ISNULL(REPLACE(CONVERT(NVARCHAR(256),CAST(CAST(ic.last_value AS BIGINT) AS money), 1), '.00', ''),N'NULL')
									+ N', seed of '
										+ ISNULL(REPLACE(CONVERT(NVARCHAR(256),CAST(CAST(ic.seed_value AS BIGINT) AS money), 1), '.00', ''),N'NULL')
									+ N', increment of ' + CAST(ic.increment_value AS NVARCHAR(256)) 
									+ N', and range of ' +
										CASE ic.system_type_name WHEN 'int' THEN N'+/- 2,147,483,647'
											WHEN 'smallint' THEN N'+/- 32,768'
											WHEN 'tinyint' THEN N'0 to 255'
										END
										AS details,
								i.index_definition,
								secret_columns, 
								ISNULL(i.index_usage_summary,''),
								ISNULL(ip.index_size_summary,'')
						FROM	#index_sanity i
						JOIN	#index_columns ic on
							i.object_id=ic.object_id
							and ic.is_identity=1
							and ic.system_type_name in ('tinyint', 'smallint', 'int')
						JOIN	#index_sanity_size ip ON i.index_sanity_id = ip.index_sanity_id
						WHERE	i.index_id in (1,0)
							and (ic.seed_value < 0 or ic.increment_value <> 1)
						ORDER BY finding, details DESC OPTION	( RECOMPILE );

			RAISERROR(N'check_id 69: Column collation does not match database collation', 0,1) WITH NOWAIT;
				WITH count_columns AS (
							SELECT [object_id],
								COUNT(*) as column_count
							FROM #index_columns ic
							WHERE index_id in (1,0) /*Heap or clustered only*/
								and collation_name <> @collation
							GROUP BY object_id
							)
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	69 AS check_id, 
								i.index_sanity_id, 
								N'Abnormal Psychology' AS findings_group,
								N'Column collation does not match database collation' AS finding,
								N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
								i.schema_object_name 
									+ N' has ' + CAST(column_count AS NVARCHAR(20))
									+ N' column' + CASE WHEN column_count > 1 THEN 's' ELSE '' END
									+ N' with a different collation than the db collation of '
									+ @collation	AS details,
								i.index_definition,
								secret_columns, 
								ISNULL(i.index_usage_summary,''),
								ISNULL(ip.index_size_summary,'')
						FROM	#index_sanity i
						JOIN	#index_sanity_size ip ON i.index_sanity_id = ip.index_sanity_id
						JOIN	count_columns AS cc ON i.[object_id]=cc.[object_id]
						WHERE	i.index_id in (1,0)
						ORDER BY i.schema_object_name DESC OPTION	( RECOMPILE );

			RAISERROR(N'check_id 70: Replicated columns', 0,1) WITH NOWAIT;
				WITH count_columns AS (
							SELECT [object_id],
								COUNT(*) as column_count,
								SUM(CASE is_replicated WHEN 1 THEN 1 ELSE 0 END) as replicated_column_count
							FROM #index_columns ic
							WHERE index_id in (1,0) /*Heap or clustered only*/
							GROUP BY object_id
							)
				INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
											   secret_columns, index_usage_summary, index_size_summary )
						SELECT	70 AS check_id, 
								i.index_sanity_id, 
								N'Abnormal Psychology' AS findings_group,
								N'Replicated columns' AS finding,
								N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
								i.schema_object_name 
									+ N' has ' + CAST(replicated_column_count AS NVARCHAR(20))
									+ N' out of ' + CAST(column_count AS NVARCHAR(20))
									+ N' column' + CASE WHEN column_count > 1 THEN 's' ELSE '' END
									+ N' in one or more publications.'
										AS details,
								i.index_definition,
								secret_columns, 
								ISNULL(i.index_usage_summary,''),
								ISNULL(ip.index_size_summary,'')
						FROM	#index_sanity i
						JOIN	#index_sanity_size ip ON i.index_sanity_id = ip.index_sanity_id
						JOIN	count_columns AS cc ON i.[object_id]=cc.[object_id]
						WHERE	i.index_id in (1,0)
							and replicated_column_count > 0
						ORDER BY i.schema_object_name DESC OPTION	( RECOMPILE );

			RAISERROR(N'check_id 71: Cascading updates or cascading deletes.', 0,1) WITH NOWAIT;
			INSERT	#blitz_index_results ( check_id, index_sanity_id, findings_group, finding, URL, details, index_definition,
								   secret_columns, index_usage_summary, index_size_summary, more_info )
			SELECT	71 AS check_id, 
					null as index_sanity_id,
					N'Abnormal Psychology' AS findings_group,
					N'Cascading Updates or Deletes' AS finding, 
					N'http://BrentOzar.com/go/AbnormalPsychology' AS URL,
					N'Foreign Key ' + foreign_key_name +
					N' on ' + QUOTENAME(parent_object_name)  + N'(' + LTRIM(parent_fk_columns) + N')'
						+ N' referencing ' + QUOTENAME(referenced_object_name) + N'(' + LTRIM(referenced_fk_columns) + N')'
						+ N' has settings:'
						+ CASE [delete_referential_action_desc] WHEN N'NO_ACTION' THEN N'' ELSE N' ON DELETE ' +[delete_referential_action_desc] END
						+ CASE [update_referential_action_desc] WHEN N'NO_ACTION' THEN N'' ELSE N' ON UPDATE ' + [update_referential_action_desc] END
							AS details, 
					N'N/A' 
							AS index_definition, 
					N'N/A' AS secret_columns,
					N'N/A' AS index_usage_summary,
					N'N/A' AS index_size_summary,
					(SELECT TOP 1 more_info from #index_sanity i where i.object_id=fk.parent_object_id)
						AS more_info
			from #foreign_keys fk
			where [delete_referential_action_desc] <> N'NO_ACTION'
			OR [update_referential_action_desc] <> N'NO_ACTION'

	END
		 ----------------------------------------
		--FINISHING UP
		----------------------------------------
	BEGIN
				INSERT	#blitz_index_results ( check_id, findings_group, finding, URL, details, index_definition,secret_columns,
											   index_usage_summary, index_size_summary )
				VALUES  ( 1000 , N'Database=' + @database_name,
						N' Learn how to use this script at:' ,   N'http://www.BrentOzar.com/BlitzIndex' ,
						N'Thanks from the Brent Ozar Unlimited, LLC team.',
						N'We hope you found this tool useful.',
						N'If you need help relieving your SQL Server pains, email us at Help@BrentOzar.com.'
						, N'',N''
						);


	END
		RAISERROR(N'Returning results.', 0,1) WITH NOWAIT;
			
		/*Return results.*/
		SELECT br.findings_group + 
			N': ' + br.finding AS [Finding], 
			br.URL, 
			br.details AS [Details: schema.table.index(indexid)], 
			br.index_definition AS [Definition: [Property]] ColumnName {datatype maxbytes}], 
			ISNULL(br.secret_columns,'') AS [Secret Columns],          
			br.index_usage_summary AS [Usage], 
			br.index_size_summary AS [Size],
			COALESCE(br.more_info,sn.more_info,'') AS [More Info],
			COALESCE(br.create_tsql,ts.create_tsql,'') AS [Create TSQL]
		FROM #blitz_index_results br
		LEFT JOIN #index_sanity sn ON 
			br.index_sanity_id=sn.index_sanity_id
		LEFT JOIN #index_create_tsql ts ON 
			br.index_sanity_id=ts.index_sanity_id
		ORDER BY [check_id] ASC, blitz_result_id ASC, findings_group;

	END; /* End @mode=0 (diagnose)*/
	ELSE IF @mode=1 /*Summarize*/
	BEGIN
	--This mode is to give some overall stats on the database.
		RAISERROR(N'@mode=1, we are summarizing.', 0,1) WITH NOWAIT;

		SELECT 
			CAST((COUNT(*)) AS NVARCHAR(256)) AS [Number Objects],
			CAST(CAST(SUM(sz.total_reserved_MB)/
				1024. AS numeric(29,1)) AS NVARCHAR(500)) AS [All GB],
			CAST(CAST(SUM(sz.total_reserved_LOB_MB)/
				1024. AS numeric(29,1)) AS NVARCHAR(500)) AS [LOB GB],
			CAST(CAST(SUM(sz.total_reserved_row_overflow_MB)/
				1024. AS numeric(29,1)) AS NVARCHAR(500)) AS [Row Overflow GB],
			CAST(SUM(CASE WHEN index_id=1 THEN 1 ELSE 0 END)AS NVARCHAR(50)) AS [Clustered Tables],
			CAST(SUM(CASE WHEN index_id=1 THEN sz.total_reserved_MB ELSE 0 END)
				/1024. AS numeric(29,1)) AS [Clustered Tables GB],
			SUM(CASE WHEN index_id NOT IN (0,1) THEN 1 ELSE 0 END) AS [NC Indexes],
			CAST(SUM(CASE WHEN index_id NOT IN (0,1) THEN sz.total_reserved_MB ELSE 0 END)
				/1024. AS numeric(29,1)) AS [NC Indexes GB],
			CASE WHEN SUM(CASE WHEN index_id NOT IN (0,1) THEN sz.total_reserved_MB ELSE 0 END)  > 0 THEN
				CAST(SUM(CASE WHEN index_id IN (0,1) THEN sz.total_reserved_MB ELSE 0 END)
					/ SUM(CASE WHEN index_id NOT IN (0,1) THEN sz.total_reserved_MB ELSE 0 END) AS NUMERIC(29,1)) 
				ELSE 0 END AS [ratio table: NC Indexes],
			SUM(CASE WHEN index_id=0 THEN 1 ELSE 0 END) AS [Heaps],
			CAST(SUM(CASE WHEN index_id=0 THEN sz.total_reserved_MB ELSE 0 END)
				/1024. AS numeric(29,1)) AS [Heaps GB],
			SUM(CASE WHEN index_id IN (0,1) AND partition_key_column_name IS NOT NULL THEN 1 ELSE 0 END) AS [Partitioned Tables],
			SUM(CASE WHEN index_id NOT IN (0,1) AND  partition_key_column_name IS NOT NULL THEN 1 ELSE 0 END) AS [Partitioned NCs],
			CAST(SUM(CASE WHEN partition_key_column_name IS NOT NULL THEN sz.total_reserved_MB ELSE 0 END)/1024. AS numeric(29,1)) AS [Partitioned GB],
			SUM(CASE WHEN filter_definition <> '' THEN 1 ELSE 0 END) AS [Filtered Indexes],
			SUM(CASE WHEN is_indexed_view=1 THEN 1 ELSE 0 END) AS [Indexed Views],
			MAX(total_rows) AS [Max Row Count],
			CAST(MAX(CASE WHEN index_id IN (0,1) THEN sz.total_reserved_MB ELSE 0 END)
				/1024. AS numeric(29,1)) AS [Max Table GB],
			CAST(MAX(CASE WHEN index_id NOT IN (0,1) THEN sz.total_reserved_MB ELSE 0 END)
				/1024. AS numeric(29,1)) AS [Max NC Index GB],
			SUM(CASE WHEN index_id IN (0,1) AND sz.total_reserved_MB > 1024 THEN 1 ELSE 0 END) AS [Count Tables > 1GB],
			SUM(CASE WHEN index_id IN (0,1) AND sz.total_reserved_MB > 10240 THEN 1 ELSE 0 END) AS [Count Tables > 10GB],
			SUM(CASE WHEN index_id IN (0,1) AND sz.total_reserved_MB > 102400 THEN 1 ELSE 0 END) AS [Count Tables > 100GB],	
			SUM(CASE WHEN index_id NOT IN (0,1) AND sz.total_reserved_MB > 1024 THEN 1 ELSE 0 END) AS [Count NCs > 1GB],
			SUM(CASE WHEN index_id NOT IN (0,1) AND sz.total_reserved_MB > 10240 THEN 1 ELSE 0 END) AS [Count NCs > 10GB],
			SUM(CASE WHEN index_id NOT IN (0,1) AND sz.total_reserved_MB > 102400 THEN 1 ELSE 0 END) AS [Count NCs > 100GB],
			MIN(create_date) AS [Oldest Create Date],
			MAX(create_date) AS [Most Recent Create Date],
			MAX(modify_date) as [Most Recent Modify Date],
			1 as [Display Order]
		FROM #index_sanity AS i
		--left join here so we don't lose disabled nc indexes
		LEFT JOIN #index_sanity_size AS sz 
			ON i.index_sanity_id=sz.index_sanity_id 
		UNION ALL
		SELECT	N'Database='+ @database_name,		
				N'sp_BlitzIndex version 2.0 (May 15, 2013)' ,   
				N'From Brent Ozar Unlimited' ,   
				N'http://BrentOzar.com/BlitzIndex' ,
				N'Thanks from the Brent Ozar Unlimited team.  We hope you found this tool useful, and if you need help relieving your SQL Server pains, email us at Help@BrentOzar.com.',
				NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
				NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
				NULL,0 as display_order
		ORDER BY [Display Order] ASC
		OPTION (RECOMPILE);
	   	
	END /* End @mode=1 (summarize)*/
	ELSE IF @mode=2 /*Index Detail*/
	BEGIN
		--This mode just spits out all the detail without filters.
		--This supports slicing AND dicing in Excel
		RAISERROR(N'@mode=2, here''s the details on existing indexes.', 0,1) WITH NOWAIT;

		SELECT	database_name AS [Database Name], 
				[schema_name] AS [Schema Name], 
				[object_name] AS [Object Name], 
				ISNULL(index_name, '') AS [Index Name], 
				cast(index_id as VARCHAR(10))AS [Index ID],
				schema_object_indexid AS [Details: schema.table.index(indexid)], 
				CASE	WHEN index_id IN ( 1, 0 ) THEN 'TABLE'
					ELSE 'NonClustered'
					END AS [Object Type], 
				index_definition AS [Definition: [Property]] ColumnName {datatype maxbytes}],
				ISNULL(LTRIM(key_column_names_with_sort_order), '') AS [Key Column Names With Sort],
				ISNULL(count_key_columns, 0) AS [Count Key Columns],
				ISNULL(include_column_names, '') AS [Include Column Names], 
				ISNULL(count_included_columns,0) AS [Count Included Columns],
				ISNULL(secret_columns,'') AS [Secret Column Names], 
				ISNULL(count_secret_columns,0) AS [Count Secret Columns],
				ISNULL(partition_key_column_name, '') AS [Partition Key Column Name],
				ISNULL(filter_definition, '') AS [Filter Definition], 
				is_indexed_view AS [Is Indexed View], 
				is_primary_key AS [Is Primary Key],
				is_XML AS [Is XML],
				is_spatial AS [Is Spatial],
				is_NC_columnstore AS [Is NC Columnstore],
				is_disabled AS [Is Disabled], 
				is_hypothetical AS [Is Hypothetical],
				is_padded AS [Is Padded], 
				fill_factor AS [Fill Factor], 
				is_referenced_by_foreign_key AS [Is Reference by Foreign Key], 
				last_user_seek AS [Last User Seek], 
				last_user_scan AS [Last User Scan], 
				last_user_lookup AS [Last User Lookup],
				last_user_update AS [Last User Update], 
				total_reads AS [Total Reads], 
				user_updates AS [User Updates], 
				reads_per_write AS [Reads Per Write], 
				index_usage_summary AS [Index Usage], 
				sz.partition_count AS [Partition Count],
				sz.total_rows AS [Rows], 
				sz.total_reserved_MB AS [Reserved MB], 
				sz.total_reserved_LOB_MB AS [Reserved LOB MB], 
				sz.total_reserved_row_overflow_MB AS [Reserved Row Overflow MB],
				sz.index_size_summary AS [Index Size], 
				sz.total_row_lock_count AS [Row Lock Count],
				sz.total_row_lock_wait_count AS [Row Lock Wait Count],
				sz.total_row_lock_wait_in_ms AS [Row Lock Wait ms],
				sz.avg_row_lock_wait_in_ms AS [Avg Row Lock Wait ms],
				sz.total_page_lock_count AS [Page Lock Count],
				sz.total_page_lock_wait_count AS [Page Lock Wait Count],
				sz.total_page_lock_wait_in_ms AS [Page Lock Wait ms],
				sz.avg_page_lock_wait_in_ms AS [Avg Page Lock Wait ms],
				sz.total_index_lock_promotion_attempt_count AS [Lock Escalation Attempts],
				sz.total_index_lock_promotion_count AS [Lock Escalations],
				sz.data_compression_desc AS [Data Compression],
				i.create_date AS [Create Date],
				i.modify_date as [Modify Date],
				more_info AS [More Info],
				1 as [Display Order]
		FROM	#index_sanity AS i --left join here so we don't lose disabled nc indexes
				LEFT JOIN #index_sanity_size AS sz ON i.index_sanity_id = sz.index_sanity_id
		UNION ALL
		SELECT 	N'Database=' + @database_name,			
				N'sp_BlitzIndex version 2.0 (May 15, 2013)' ,   
				N'From Brent Ozar Unlimited' ,   
				N'http://BrentOzar.com/BlitzIndex' ,
				N'Thanks from the Brent Ozar Unlimited team.  We hope you found this tool useful, and if you need help relieving your SQL Server pains, email us at Help@BrentOzar.com.',
				NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
				NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
				NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
				NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
				NULL,NULL,NULL, NULL,NULL, NULL, NULL, NULL, NULL,
				0 as [Display Order]
		ORDER BY [Display Order] ASC, [Reserved MB] DESC
		OPTION (RECOMPILE);

	END /* End @mode=2 (index detail)*/
	ELSE IF @mode=3 /*Missing index Detail*/
	BEGIN
		SELECT 
			database_name AS [Database], 
			[schema_name] AS [Schema], 
			table_name AS [Table], 
			CAST(magic_benefit_number AS BIGINT)
				AS [Magic Benefit Number], 
			missing_index_details AS [Missing Index Details], 
			avg_total_user_cost AS [Avg Query Cost], 
			avg_user_impact AS [Est Index Improvement], 
			user_seeks AS [Seeks], 
			user_scans AS [Scans],
			unique_compiles AS [Compiles], 
			equality_columns AS [Equality Columns], 
			inequality_columns AS [Inequality Columns], 
			included_columns AS [Included Columns], 
			index_estimated_impact AS [Estimated Impact], 
			create_tsql AS [Create TSQL], 
			more_info AS [More Info],
			1 as [Display Order]
		FROM #missing_indexes
		UNION ALL
		SELECT 				
			N'sp_BlitzIndex version 2.0 (May 15, 2013)' ,   
			N'From Brent Ozar Unlimited' ,   
			N'http://BrentOzar.com/BlitzIndex' ,
			100000000000,
			N'Thanks from the Brent Ozar Unlimited team. We hope you found this tool useful, and if you need help relieving your SQL Server pains, email us at Help@BrentOzar.com.',
			NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
			NULL, 0 as display_order
		ORDER BY [Display Order] ASC, [Magic Benefit Number] DESC

	END /* End @mode=3 (index detail)*/
END
END TRY
BEGIN CATCH
		RAISERROR (N'Failure analyzing temp tables.', 0,1) WITH NOWAIT;

		SELECT	@msg = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();

		RAISERROR (@msg, 
               @ErrorSeverity, 
               @ErrorState 
               );
		
		WHILE @@trancount > 0 
			ROLLBACK;

		RETURN;
	END CATCH;
GO

USE master;
GO

IF OBJECT_ID('master.dbo.sp_Blitz') IS NOT NULL 
    DROP PROC dbo.sp_Blitz;
GO

CREATE PROCEDURE [dbo].[sp_Blitz]
    @CheckUserDatabaseObjects TINYINT = 1 ,
    @CheckProcedureCache TINYINT = 0 ,
    @OutputType VARCHAR(20) = 'TABLE' ,
    @OutputProcedureCache TINYINT = 0 ,
    @CheckProcedureCacheFilter VARCHAR(10) = NULL ,
    @CheckServerInfo TINYINT = 0 ,
    @Version INT = NULL OUTPUT
AS 
    SET NOCOUNT ON;
/*
    sp_Blitz v16 - December 13, 2012
    
    (C) 2012, Brent Ozar Unlimited

To learn more, visit http://www.BrentOzar.com/blitz where you can download
new versions for free, watch training videos on how it works, get more info on
the findings, and more.  To contribute code and see your name in the change
log, email your improvements & checks to Help@BrentOzar.com.

Explanation of priority levels:
  1 - Critical risk of data loss.  Fix this ASAP.
 10 - Security risk.
 20 - Security risk due to unusual configuration, but requires more research.
 50 - Reliability risk.
 60 - Reliability risk due to unusual configuration, but requires more research.
100 - Performance risk.
110 - Performance risk due to unusual configuration, but requires more research.
200 - Informational.
250 - Server info. Not warnings, just explaining data about the server.

Known limitations of this version:
 - No support for SQL Server 2000 or compatibility mode 80.
 - If a database name has a question mark in it, some tests will fail.  Gotta
   love that unsupported sp_MSforeachdb.

Unknown limitations of this version:
 - None.  (If we knew them, they'd be known.  Duh.)

Changes in v16:
 - Chris Fradenburg @ChrisFradenburg http://www.fradensql.com:
   - Check 81 for non-active sp_configure options not yet taking effect.
   - Improved check 35 to not alert if Optimize for Ad Hoc is already enabled.
 - Rob Sullivan @DataChomp http://datachomp.com:
   - Suggested to add output variable @Version to manage server installations.
 - Vadim Mordkovich:
   - Added check 85 for database users with elevated database roles like
     db_owner, db_securityadmin, etc.
 - Vladimir Vissoultchev rewrote the DBCC CHECKDB check to work around a bug in
   SQL Server 2008 & R2 that report dbi_dbccLastKnownGood twice. For more info
   on the bug, check Connect ID 485869.
 - Added check 77 for database snapshots.
 - Added check 78 for stored procedures with WITH RECOMPILE in the source code.
 - Added check 79 for Agent jobs with SHRINKDATABASE or SHRINKFILE.
 - Added check 80 for databases with a max file size set.
 - Added @CheckServerInfo perameter default 0. Adds additional server inventory
   data in checks 83-85 for things like CPU, memory, service logins.  None of
   these are problems, but if you're using sp_Blitz to assess a server you've
   never seen, you may want to know more about what you're working with. I do.
 - Tweaked check 75 for large log files so that it only alerts on files > 1GB.
 - Changed one of the two check 59's to be check 82. (Doh!)
 - Added WITH NO_INFOMSGS to the DBCC calls to ease life for automation folks.
 - Works with offline and restoring databases. (Just happened to test it in
   this version and it already worked - must have fixed this earlier.)

Changes in v15:
 - Mikael Wedham caught bugs in a few checks that reported the wrong database name.
 - Bob Klimes fixed bugs in several checks where v14 broke case sensitivity.
 - Seth Washeck fixed bugs in the VLF checks so they include the number of VLFs.

Changes in v14:
 - Lori Edwards @LoriEdwards http://sqlservertimes2.com
     - Did all the coding in this version! She did a killer job of integrating
	   improvements and suggestions from all kinds of people, including:
 - Chris Fradenburg @ChrisFradenburg http://www.fradensql.com 
     - Check 74 to identify globally enabled traceflags
 - Jeremy Lowell @DataRealized http://datarealized.com added:
     - Check 72 for non-aligned indexes on partitioned tables
 - Paul Anderton @Panders69 added check 69 to check for high VLF count
 - Ron van Moorsel added several changes
	 - Added a change to check 6 to use sys.server_principals instead of syslogins
	 - Added a change to check 25 to check whether tempdb was set to autogrow.  
	 - Added a change to check 49 to check for linked servers configured with the SA login
 - Shaun Stuart @shaunjstu http://shaunjstuart.com added several changes:
	 - Added check 68 to check for the last successful DBCC CHECKDB
	 - Updated check 1 to verify the backup came from the current 
	 - Added check 70 to verify that @@servername is not null
 - Typo in check 51 changing free to present thanks to Sabu Varghese
 - Check 73 to determine if a failsafe operator has been configured
 - Check 75 for transaction log files larger than data files suggested by Chris Adkin
 - Fixed a bunch of bugs for oddball database names (like apostrophes).

Changes in v13:
 - Fixed typos in descriptions of checks 60 & 61 thanks to Mark Hions.
 - Improved check 14 to work with collations thanks to Greg Ackerland.
 - Improved several of the backup checks to exclude database snapshots and
   databases that are currently being restored thanks to Greg Ackerland.
 - Improved wording on check 51 thanks to Stephen Criddle.
 - Added top line introducing the reader to sp_Blitz and the version number.
 - Changed Brent Ozar PLF, LLC to Brent Ozar Unlimited. Great catch by
   Hondo Henriques, @SQLHondo.
 - If you've submitted code recently to sp_Blitz, hang in there! We're still
   building a big new version with lots of new checks. Just fixing bugs in
   this small release.

Changes in v12:
 - Added plan cache (aka procedure cache) analysis. Examines top resource-using
   queries for common problems like implicit conversions, missing indexes, etc.
 - Added @CheckProcedureCacheFilter to focus plan cache analysis on
   CPU, Reads, Duration, or ExecCount. If null, we analyze all of them.
 - Added @OutputProcedureCache to include the queries we analyzed. Results are
   sorted using the @CheckProcedureCacheFilter parameter, otherwise by CPU.
 - Fixed case sensitive calls of sp_MSforeachdb reported by several users.

Changes in v11:
 - Added check for optimize for ad hoc workloads in sys.configurations.
 - Added @OutputType parameter. Choices:
 	- 'TABLE' - default of one result set table with all warnings.
	- 'COUNT' - Sesame Street's favorite character will tell you how many
				problems sp_Blitz found.  Useful if you want to use a
				monitoring tool to alert you when something changed.

Changes in v10:
 - Jeremiah Peschka added check 59 for file growths set to a percentage.
 - Ned Otter added check 62 for old compatibility levels.
 - Wayne Sheffield improved checks 38 & 39 by excluding more system tables.
 - Christopher Fradenburg improved check 30 (missing alerts) by making sure
   that alerts are set up for all of the severity levels involved, not just
   some of them.
 - James Siebengartner and others improved check 14 (page verification) by
   excluding TempDB, which can't be set to checksum in older versions.
 - Added check 60 for index fill factors <> 0, 100.
 - Added check 61 for unusual SQL Server editions (not Standard, Enterprise, or
   Developer)
 - Added limitations note to point out that compatibility mode 80 won't work.
 - Fixed a bug where changes in sp_configure weren't always reported.

Changes in v9:
 - Alex Pixley fixed a spelling typo.
 - Steinar Anderson http://www.sqlservice.se fixed a date bug in checkid 2.
   That bug was reported by several users, but Steinar coded the fix.
 - Stephen Schissler added a filter for checkid 2 (missing log backups) to look
   only for databases where source_database_id is null because these are
   database snapshots, and you can't run transaction log backups on snapshots.
 - Mark Fleming @markflemingnl added checkid 62 looking for disabled alerts.
 - Checkid 17 typo changed from "disabled" to "enabled" - the check
   functionality was right, but it was warning that auto update stats async
   was "disabled".  Disabled is actually the default, but the check was
   firing because it had been enabled.  (This one was reported by many.)

Changes in v8 May 10 2012:
 - Switched more-details URLs to be short.  This way they'll render better
   when viewed in our SQL Server Management Studio reports.
 - Removed ?VersionNumber querystring parameter to shorten links in SSMS.
 - Eliminated duplicate check for startup stored procedures.

Changes in v7 April 30 2012:
 - Thomas Rushton http://thelonedba.wordpress.com/ @ThomasRushton added check
   58 for database collations that don't match the server collation.
 - Rob Pellicaan caught a bug in check 13: it was only checking for plan guides
   in the master database rather than all user databases.
 - Michal Tinthofer http://www.woodler.eu improved check 2 to work across
   collations and fix a bug in the backup_finish_date check.  (Several people
   reported this, but Michal contributed the most improvements to this check.)
 - Chris Fradenburg improved checks 38 and 39 by excluding heaps if they are
   marked is_ms_shipped, thereby excluding more system stuff.
 - Jack Whittaker fixed a bug in checkid 1.  When checking for databases
   without a full backup, we were ignoring the model database, but some shops
   really do need to back up model because they put stuff in there to be
   copied into each new database, so let's alert on that too.  Larry Silverman
   also noticed this bug.
 - Michael Burgess caught a bug in the untrusted key/constraint checks that
   were not checking for is_disabled = 0.
 - Alex Friedman fixed a bug in check 44 which required a running trace.
 - New check for SQL Agent alerts configured without operator notifications.
 - Even if @CheckUserDatabaseObjects was set to 0, some user database object
   checks were being done.
 - Check 48 for untrusted foreign keys now just returns one line per database
   that has the issue rather than listing every foreign key individually. For
   the full list of untrusted keys, run the query in the finding's URL.

Changes in v6 Dec 26 2011:
 - Jonathan Allen @FatherJack suggested tweaking sp_BlitzUpdate's error message
    about Ad Hoc Queries not being enabled so that it also includes
    instructions on how to disable them again after temporarily enabling
    it to update sp_Blitz. 

Changes in v5 Dec 18 2011:
 - John Miner suggested tweaking checkid 48 and 56, the untrusted constraints
    and keys, to look for is_not_for_replication = 0 too.  This filters out
    constraints/keys that are only used for replication and don't need to
    be trusted.
 - Ned Otter caught a bug in the URL for check 7, startup stored procs.
 - Scott (Anon) recommended using SUSER_SNAME(0x01) instead of 'sa' when
    checking for job ownership, database ownership, etc.
 - Martin Schmidt http://www.geniiius.com/blog/ caught a bug in checkid 1 and
    contributed code to catch databases that had never been backed up.
 - Added parameter for @CheckProcedureCache.  When set to 0, we skip the checks
    that are typically the slowest on servers with lots of memory.  I'm
    defaulting this to 0 so more users can get results back faster.

Changes in v4 Nov 1 2011:
 - Andreas Schubert caught a typo in the explanations for checks 15-17.
 - K. Brian Kelley @kbriankelley added checkid 57 for SQL Agent jobs set to
      start automatically on startup.
 - Added parameter for @CheckUserDatabaseObjects.  When set to 0, we skip the
    checks that are typically the slowest on large servers, the user
    database schema checks for things like triggers, hypothetical
    indexes, untrusted constraints, etc.

Changes in v3 Oct 16 2011:
 - David Tolbert caught a bug in checkid 2.  If some backups had failed or
        been aborted, we raised a false alarm about no transaction log backups.
 - Fixed more bugs in checking for SQL Server 2005. (I need more 2005 VMs!)

Changes in v2 Oct 14 2011:
 - Ali Razeghi http://www.alirazeghi.com added checkid 55 looking for
   databases owned by <> SA.
 - Fixed bugs in checking for SQL Server 2005 (leading % signs)

*/

    IF OBJECT_ID('tempdb..#BlitzResults') IS NOT NULL 
        DROP TABLE #BlitzResults;
    CREATE TABLE #BlitzResults
        (
          ID INT IDENTITY(1, 1) ,
          CheckID INT ,
          Priority TINYINT ,
          FindingsGroup VARCHAR(50) ,
          Finding VARCHAR(200) ,
          URL VARCHAR(200) ,
          Details NVARCHAR(4000) ,
          QueryPlan [XML] NULL ,
          QueryPlanFiltered [NVARCHAR](MAX) NULL
        );

    IF OBJECT_ID('tempdb..#ConfigurationDefaults') IS NOT NULL 
        DROP TABLE #ConfigurationDefaults;
    CREATE TABLE #ConfigurationDefaults
        (
          name NVARCHAR(128) ,
          DefaultValue BIGINT
        );

    IF @CheckProcedureCache = 1 
        BEGIN
            IF OBJECT_ID('tempdb..#dm_exec_query_stats') IS NOT NULL 
                DROP TABLE #dm_exec_query_stats;
            CREATE TABLE #dm_exec_query_stats
                (
                  [id] [int] NOT NULL
                             IDENTITY(1, 1) ,
                  [sql_handle] [varbinary](64) NOT NULL ,
                  [statement_start_offset] [int] NOT NULL ,
                  [statement_end_offset] [int] NOT NULL ,
                  [plan_generation_num] [bigint] NOT NULL ,
                  [plan_handle] [varbinary](64) NOT NULL ,
                  [creation_time] [datetime] NOT NULL ,
                  [last_execution_time] [datetime] NOT NULL ,
                  [execution_count] [bigint] NOT NULL ,
                  [total_worker_time] [bigint] NOT NULL ,
                  [last_worker_time] [bigint] NOT NULL ,
                  [min_worker_time] [bigint] NOT NULL ,
                  [max_worker_time] [bigint] NOT NULL ,
                  [total_physical_reads] [bigint] NOT NULL ,
                  [last_physical_reads] [bigint] NOT NULL ,
                  [min_physical_reads] [bigint] NOT NULL ,
                  [max_physical_reads] [bigint] NOT NULL ,
                  [total_logical_writes] [bigint] NOT NULL ,
                  [last_logical_writes] [bigint] NOT NULL ,
                  [min_logical_writes] [bigint] NOT NULL ,
                  [max_logical_writes] [bigint] NOT NULL ,
                  [total_logical_reads] [bigint] NOT NULL ,
                  [last_logical_reads] [bigint] NOT NULL ,
                  [min_logical_reads] [bigint] NOT NULL ,
                  [max_logical_reads] [bigint] NOT NULL ,
                  [total_clr_time] [bigint] NOT NULL ,
                  [last_clr_time] [bigint] NOT NULL ,
                  [min_clr_time] [bigint] NOT NULL ,
                  [max_clr_time] [bigint] NOT NULL ,
                  [total_elapsed_time] [bigint] NOT NULL ,
                  [last_elapsed_time] [bigint] NOT NULL ,
                  [min_elapsed_time] [bigint] NOT NULL ,
                  [max_elapsed_time] [bigint] NOT NULL ,
                  [query_hash] [binary](8) NULL ,
                  [query_plan_hash] [binary](8) NULL ,
                  [query_plan] [xml] NULL ,
                  [query_plan_filtered] [nvarchar](MAX) NULL ,
                  [text] [nvarchar](MAX) COLLATE SQL_Latin1_General_CP1_CI_AS
                                         NULL ,
                  [text_filtered] [nvarchar](MAX)
                    COLLATE SQL_Latin1_General_CP1_CI_AS
                    NULL
                )
	
        END

    DECLARE @StringToExecute NVARCHAR(4000);

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  1 AS CheckID ,
                    1 AS Priority ,
                    'Backup' AS FindingsGroup ,
                    'Backups Not Performed Recently' AS Finding ,
                    'http://BrentOzar.com/go/nobak' AS URL ,
                    'Database ' + d.Name + ' last backed up: '
                    + CAST(COALESCE(MAX(b.backup_finish_date), ' never ') AS VARCHAR(200)) AS Details
            FROM    master.sys.databases d
                    LEFT OUTER JOIN msdb.dbo.backupset b ON d.name = b.database_name
                                                            AND b.type = 'D'
                                                            AND b.server_name = @@SERVERNAME /*Backupset ran on current server */
            WHERE   d.database_id <> 2  /* Bonus points if you know what that means */
                    AND d.state <> 1 /* Not currently restoring, like log shipping databases */
                    AND d.is_in_standby = 0 /* Not a log shipping target database */
                    AND d.source_database_id IS NULL /* Excludes database snapshots */
            GROUP BY d.name
            HAVING  MAX(b.backup_finish_date) <= DATEADD(dd, -7, GETDATE());


    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
              
            )
            SELECT  1 AS CheckID ,
                    1 AS Priority ,
                    'Backup' AS FindingsGroup ,
                    'Backups Not Performed Recently' AS Finding ,
                    'http://BrentOzar.com/go/nobak' AS URL ,
                    ( 'Database ' + d.Name + ' never backed up.' ) AS Details
            FROM    master.sys.databases d
            WHERE   d.database_id <> 2 /* Bonus points if you know what that means */
                    AND d.state <> 1 /* Not currently restoring, like log shipping databases */
                    AND d.is_in_standby = 0 /* Not a log shipping target database */
                    AND d.source_database_id IS NULL /* Excludes database snapshots */
                    AND NOT EXISTS ( SELECT *
                                     FROM   msdb.dbo.backupset b
                                     WHERE  d.name = b.database_name
                                            AND b.type = 'D'
                                            AND b.server_name = @@SERVERNAME /*Backupset ran on current server */)

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT DISTINCT
                    2 AS CheckID ,
                    1 AS Priority ,
                    'Backup' AS FindingsGroup ,
                    'Full Recovery Mode w/o Log Backups' AS Finding ,
                    'http://BrentOzar.com/go/biglogs' AS URL ,
                    ( 'Database ' + ( d.Name COLLATE database_default )
                      + ' is in ' + d.recovery_model_desc
                      + ' recovery mode but has not had a log backup in the last week.' ) AS Details
            FROM    master.sys.databases d
            WHERE   d.recovery_model IN ( 1, 2 )
                    AND d.database_id NOT IN ( 2, 3 )
                    AND d.source_database_id IS NULL
                    AND d.state <> 1 /* Not currently restoring, like log shipping databases */
                    AND d.is_in_standby = 0 /* Not a log shipping target database */
                    AND d.source_database_id IS NULL /* Excludes database snapshots */
                    AND NOT EXISTS ( SELECT *
                                     FROM   msdb.dbo.backupset b
                                     WHERE  d.name = b.database_name
                                            AND b.type = 'L'
                                            AND b.backup_finish_date >= DATEADD(dd,
                                                              -7, GETDATE()) );




    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT TOP 1
                    3 AS CheckID ,
                    200 AS Priority ,
                    'Backup' AS FindingsGroup ,
                    'MSDB Backup History Not Purged' AS Finding ,
                    'http://BrentOzar.com/go/history' AS URL ,
                    ( 'Database backup history retained back to '
                      + CAST(bs.backup_start_date AS VARCHAR(20)) ) AS Details
            FROM    msdb.dbo.backupset bs
            WHERE   bs.backup_start_date <= DATEADD(dd, -60, GETDATE())
            ORDER BY backup_set_id ASC;


    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  4 AS CheckID ,
                    10 AS Priority ,
                    'Security' AS FindingsGroup ,
                    'Sysadmins' AS Finding ,
                    'http://BrentOzar.com/go/sa' AS URL ,
                    ( 'Login [' + l.name
                      + '] is a sysadmin - meaning they can do absolutely anything in SQL Server, including dropping databases or hiding their tracks.' ) AS Details
            FROM    master.sys.syslogins l
            WHERE   l.sysadmin = 1
                    AND l.name <> SUSER_SNAME(0x01)
                    AND l.denylogin = 0;

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  5 AS CheckID ,
                    10 AS Priority ,
                    'Security' AS FindingsGroup ,
                    'Security Admins' AS Finding ,
                    'http://BrentOzar.com/go/sa' AS URL ,
                    ( 'Login [' + l.name
                      + '] is a security admin - meaning they can give themselves permission to do absolutely anything in SQL Server, including dropping databases or hiding their tracks.' ) AS Details
            FROM    master.sys.syslogins l
            WHERE   l.securityadmin = 1
                    AND l.name <> SUSER_SNAME(0x01)
                    AND l.denylogin = 0;

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  6 AS CheckID ,
                    200 AS Priority ,
                    'Security' AS FindingsGroup ,
                    'Jobs Owned By Users' AS Finding ,
                    'http://BrentOzar.com/go/owners' AS URL ,
                    ( 'Job [' + j.name + '] is owned by [' + sl.name
                      + '] - meaning if their login is disabled or not available due to Active Directory problems, the job will stop working.' ) AS Details
            FROM    msdb.dbo.sysjobs j
                    LEFT OUTER JOIN sys.server_principals sl ON j.owner_sid = sl.sid
            WHERE   j.enabled = 1
                    AND sl.name <> SUSER_SNAME(0x01);

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  7 AS CheckID ,
                    10 AS Priority ,
                    'Security' AS FindingsGroup ,
                    'Stored Procedure Runs at Startup' AS Finding ,
                    'http://BrentOzar.com/go/startup' AS URL ,
                    ( 'Stored procedure [master].[' + r.SPECIFIC_SCHEMA
                      + '].[' + r.SPECIFIC_NAME
                      + '] runs automatically when SQL Server starts up.  Make sure you know exactly what this stored procedure is doing, because it could pose a security risk.' ) AS Details
            FROM    master.INFORMATION_SCHEMA.ROUTINES r
            WHERE   OBJECTPROPERTY(OBJECT_ID(ROUTINE_NAME), 'ExecIsStartup') = 1;

    IF @@VERSION NOT LIKE '%Microsoft SQL Server 2000%'
        AND @@VERSION NOT LIKE '%Microsoft SQL Server 2005%' 
        BEGIN
            SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
SELECT 8 AS CheckID, 150 AS Priority, ''Security'' AS FindingsGroup, ''Server Audits Running'' AS Finding, 
    ''http://BrentOzar.com/go/audits'' AS URL,
    (''SQL Server built-in audit functionality is being used by server audit: '' + [name]) AS Details FROM sys.dm_server_audit_status'
            EXECUTE(@StringToExecute)
        END;

    IF @@VERSION NOT LIKE '%Microsoft SQL Server 2000%' 
        BEGIN
            SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
SELECT 9 AS CheckID, 200 AS Priority, ''Surface Area'' AS FindingsGroup, ''Endpoints Configured'' AS Finding, 
    ''http://BrentOzar.com/go/endpoints/'' AS URL,
    (''SQL Server endpoints are configured.  These can be used for database mirroring or Service Broker, but if you do not need them, avoid leaving them enabled.  Endpoint name: '' + [name]) AS Details FROM sys.endpoints WHERE type <> 2'
            EXECUTE(@StringToExecute)
        END;

    IF @@VERSION NOT LIKE '%Microsoft SQL Server 2000%'
        AND @@VERSION NOT LIKE '%Microsoft SQL Server 2005%' 
        BEGIN
            SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
SELECT 10 AS CheckID, 100 AS Priority, ''Performance'' AS FindingsGroup, ''Resource Governor Enabled'' AS Finding, 
    ''http://BrentOzar.com/go/rg'' AS URL,
    (''Resource Governor is enabled.  Queries may be throttled.  Make sure you understand how the Classifier Function is configured.'') AS Details FROM sys.resource_governor_configuration WHERE is_enabled = 1'
            EXECUTE(@StringToExecute)
        END;


    IF @@VERSION NOT LIKE '%Microsoft SQL Server 2000%' 
        BEGIN
            SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
SELECT 11 AS CheckID, 100 AS Priority, ''Performance'' AS FindingsGroup, ''Server Triggers Enabled'' AS Finding, 
    ''http://BrentOzar.com/go/logontriggers/'' AS URL,
    (''Server Trigger ['' + [name] ++ ''] is enabled, so it runs every time someone logs in.  Make sure you understand what that trigger is doing - the less work it does, the better.'') AS Details FROM sys.server_triggers WHERE is_disabled = 0 AND is_ms_shipped = 0'
            EXECUTE(@StringToExecute)
        END;


    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  12 AS CheckID ,
                    10 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Auto-Close Enabled' AS Finding ,
                    'http://BrentOzar.com/go/autoclose' AS URL ,
                    ( 'Database [' + [name]
                      + '] has auto-close enabled.  This setting can dramatically decrease performance.' ) AS Details
            FROM    sys.databases
            WHERE   is_auto_close_on = 1;

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  12 AS CheckID ,
                    10 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Auto-Shrink Enabled' AS Finding ,
                    'http://BrentOzar.com/go/autoshrink' AS URL ,
                    ( 'Database [' + [name]
                      + '] has auto-shrink enabled.  This setting can dramatically decrease performance.' ) AS Details
            FROM    sys.databases
            WHERE   is_auto_shrink_on = 1;


    IF @@VERSION LIKE '%Microsoft SQL Server 2000%' 
        BEGIN
            SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
SELECT 14 AS CheckID, 50 AS Priority, ''Reliability'' AS FindingsGroup, ''Page Verification Not Optimal'' AS Finding, 
    ''http://BrentOzar.com/go/torn'' AS URL,
    (''Database ['' + [name] + ''] has '' + [page_verify_option_desc] + '' for page verification.  SQL Server may have a harder time recognizing and recovering from storage corruption.  Consider using CHECKSUM instead.'') COLLATE database_default AS Details FROM sys.databases WHERE page_verify_option < 1 AND name <> ''tempdb'''
            EXECUTE(@StringToExecute)
        END;

    IF @@VERSION NOT LIKE '%Microsoft SQL Server 2000%' 
        BEGIN
            SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
SELECT 14 AS CheckID, 50 AS Priority, ''Reliability'' AS FindingsGroup, ''Page Verification Not Optimal'' AS Finding, 
    ''http://BrentOzar.com/go/torn'' AS URL,
    (''Database ['' + [name] + ''] has '' + [page_verify_option_desc] + '' for page verification.  SQL Server may have a harder time recognizing and recovering from storage corruption.  Consider using CHECKSUM instead.'') AS Details FROM sys.databases WHERE page_verify_option < 2 AND name <> ''tempdb'''
            EXECUTE(@StringToExecute)
        END;

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  15 AS CheckID ,
                    110 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Auto-Create Stats Disabled' AS Finding ,
                    'http://BrentOzar.com/go/acs' AS URL ,
                    ( 'Database [' + [name]
                      + '] has auto-create-stats disabled.  SQL Server uses statistics to build better execution plans, and without the ability to automatically create more, performance may suffer.' ) AS Details
            FROM    sys.databases
            WHERE   is_auto_create_stats_on = 0;

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  16 AS CheckID ,
                    110 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Auto-Update Stats Disabled' AS Finding ,
                    'http://BrentOzar.com/go/aus' AS URL ,
                    ( 'Database [' + [name]
                      + '] has auto-update-stats disabled.  SQL Server uses statistics to build better execution plans, and without the ability to automatically update them, performance may suffer.' ) AS Details
            FROM    sys.databases
            WHERE   is_auto_update_stats_on = 0;

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  17 AS CheckID ,
                    110 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Stats Updated Asynchronously' AS Finding ,
                    'http://BrentOzar.com/go/asyncstats' AS URL ,
                    ( 'Database [' + [name]
                      + '] has auto-update-stats-async enabled.  When SQL Server gets a query for a table with out-of-date statistics, it will run the query with the stats it has - while updating stats to make later queries better. The initial run of the query may suffer, though.' ) AS Details
            FROM    sys.databases
            WHERE   is_auto_update_stats_async_on = 1;


    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  18 AS CheckID ,
                    110 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Forced Parameterization On' AS Finding ,
                    'http://BrentOzar.com/go/forced' AS URL ,
                    ( 'Database [' + [name]
                      + '] has forced parameterization enabled.  SQL Server will aggressively reuse query execution plans even if the applications do not parameterize their queries.  This can be a performance booster with some programming languages, or it may use universally bad execution plans when better alternatives are available for certain parameters.' ) AS Details
            FROM    sys.databases
            WHERE   is_parameterization_forced = 1;


    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  19 AS CheckID ,
                    200 AS Priority ,
                    'Informational' AS FindingsGroup ,
                    'Replication In Use' AS Finding ,
                    'http://BrentOzar.com/go/repl' AS URL ,
                    ( 'Database [' + [name]
                      + '] is a replication publisher, subscriber, or distributor.' ) AS Details
            FROM    sys.databases
            WHERE   is_published = 1
                    OR is_subscribed = 1
                    OR is_merge_published = 1
                    OR is_distributor = 1;

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  20 AS CheckID ,
                    110 AS Priority ,
                    'Informational' AS FindingsGroup ,
                    'Date Correlation On' AS Finding ,
                    'http://BrentOzar.com/go/corr' AS URL ,
                    ( 'Database [' + [name]
                      + '] has date correlation enabled.  This is not a default setting, and it has some performance overhead.  It tells SQL Server that date fields in two tables are related, and SQL Server maintains statistics showing that relation.' ) AS Details
            FROM    sys.databases
            WHERE   is_date_correlation_on = 1;

    IF @@VERSION NOT LIKE '%Microsoft SQL Server 2000%'
        AND @@VERSION NOT LIKE '%Microsoft SQL Server 2005%' 
        BEGIN
            SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
SELECT 21 AS CheckID, 20 AS Priority, ''Encryption'' AS FindingsGroup, ''Database Encrypted'' AS Finding, 
    ''http://BrentOzar.com/go/tde'' AS URL,
    (''Database ['' + [name] + ''] has Transparent Data Encryption enabled.  Make absolutely sure you have backed up the certificate and private key, or else you will not be able to restore this database.'') AS Details FROM sys.databases WHERE is_encrypted = 1'
            EXECUTE(@StringToExecute)
        END;

/* Compare sp_configure defaults */
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'Ad Hoc Distributed Queries', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'affinity I/O mask', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'affinity mask', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'Agent XPs', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'allow updates', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'awe enabled', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'blocked process threshold', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'c2 audit mode', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'clr enabled', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'cost threshold for parallelism', 5 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'cross db ownership chaining', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'cursor threshold', -1 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'Database Mail XPs', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'default full-text language', 1033 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'default language', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'default trace enabled', 1 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'disallow results from triggers', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'fill factor (%)', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'ft crawl bandwidth (max)', 100 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'ft crawl bandwidth (min)', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'ft notify bandwidth (max)', 100 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'ft notify bandwidth (min)', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'index create memory (KB)', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'in-doubt xact resolution', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'lightweight pooling', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'locks', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'max degree of parallelism', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'max full-text crawl range', 4 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'max server memory (MB)', 2147483647 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'max text repl size (B)', 65536 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'max worker threads', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'media retention', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'min memory per query (KB)', 1024 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'min server memory (MB)', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'nested triggers', 1 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'network packet size (B)', 4096 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'Ole Automation Procedures', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'open objects', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'optimize for ad hoc workloads', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'PH timeout (s)', 60 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'precompute rank', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'priority boost', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'query governor cost limit', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'query wait (s)', -1 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'recovery interval (min)', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'remote access', 1 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'remote admin connections', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'remote login timeout (s)', 20 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'remote proc trans', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'remote query timeout (s)', 600 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'Replication XPs', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'RPC parameter data validation', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'scan for startup procs', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'server trigger recursion', 1 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'set working set size', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'show advanced options', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'SMO and DMO XPs', 1 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'SQL Mail XPs', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'transform noise words', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'two digit year cutoff', 2049 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'user connections', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'user options', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'Web Assistant Procedures', 0 );
    INSERT  INTO #ConfigurationDefaults
    VALUES  ( 'xp_cmdshell', 0 );

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  22 AS CheckID ,
                    200 AS Priority ,
                    'Non-Default Server Config' AS FindingsGroup ,
                    cd.name AS Finding ,
                    'http://BrentOzar.com/go/conf' AS URL ,
                    ( 'This sp_configure option has been changed.  Its default value is '
                      + CAST(cd.[DefaultValue] AS VARCHAR(100))
                      + ' and it has been set to '
                      + CAST(cr.value_in_use AS VARCHAR(100)) + '.' ) AS Details
            FROM    #ConfigurationDefaults cd
                    INNER JOIN sys.configurations cr ON cd.name = cr.name
            WHERE   cd.DefaultValue <> cr.value_in_use;

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT DISTINCT
                    24 AS CheckID ,
                    20 AS Priority ,
                    'Reliability' AS FindingsGroup ,
                    'System Database on C Drive' AS Finding ,
                    'http://BrentOzar.com/go/drivec' AS URL ,
                    ( 'The ' + DB_NAME(database_id)
                      + ' database has a file on the C drive.  Putting system databases on the C drive runs the risk of crashing the server when it runs out of space.' ) AS Details
            FROM    sys.master_files
            WHERE   UPPER(LEFT(physical_name, 1)) = 'C'
                    AND DB_NAME(database_id) IN ( 'master', 'model', 'msdb' );

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT TOP 1
                    25 AS CheckID ,
                    100 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'TempDB on C Drive' AS Finding ,
                    'http://BrentOzar.com/go/drivec' AS URL ,
                    CASE WHEN growth > 0
                         THEN ( 'The tempdb database has files on the C drive.  TempDB frequently grows unpredictably, putting your server at risk of running out of C drive space and crashing hard.  C is also often much slower than other drives, so performance may be suffering.' )
                         ELSE ( 'The tempdb database has files on the C drive.  TempDB is not set to Autogrow, hopefully it is big enough.  C is also often much slower than other drives, so performance may be suffering.' )
                    END AS Details
            FROM    sys.master_files
            WHERE   UPPER(LEFT(physical_name, 1)) = 'C'
                    AND DB_NAME(database_id) = 'tempdb';

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT DISTINCT
                    26 AS CheckID ,
                    20 AS Priority ,
                    'Reliability' AS FindingsGroup ,
                    'User Databases on C Drive' AS Finding ,
                    'http://BrentOzar.com/go/cdrive' AS URL ,
                    ( 'The ' + DB_NAME(database_id)
                      + ' database has a file on the C drive.  Putting databases on the C drive runs the risk of crashing the server when it runs out of space.' ) AS Details
            FROM    sys.master_files
            WHERE   UPPER(LEFT(physical_name, 1)) = 'C'
                    AND DB_NAME(database_id) NOT IN ( 'master', 'model',
                                                      'msdb', 'tempdb' );


    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  27 AS CheckID ,
                    200 AS Priority ,
                    'Informational' AS FindingsGroup ,
                    'Tables in the Master Database' AS Finding ,
                    'http://BrentOzar.com/go/mastuser' AS URL ,
                    ( 'The ' + name
                      + ' table in the master database was created by end users on '
                      + CAST(create_date AS VARCHAR(20))
                      + '. Tables in the master database may not be restored in the event of a disaster.' ) AS Details
            FROM    master.sys.tables
            WHERE   is_ms_shipped = 0;

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  28 AS CheckID ,
                    200 AS Priority ,
                    'Informational' AS FindingsGroup ,
                    'Tables in the MSDB Database' AS Finding ,
                    'http://BrentOzar.com/go/msdbuser' AS URL ,
                    ( 'The ' + name
                      + ' table in the msdb database was created by end users on '
                      + CAST(create_date AS VARCHAR(20))
                      + '. Tables in the msdb database may not be restored in the event of a disaster.' ) AS Details
            FROM    msdb.sys.tables
            WHERE   is_ms_shipped = 0;

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  29 AS CheckID ,
                    200 AS Priority ,
                    'Informational' AS FindingsGroup ,
                    'Tables in the Model Database' AS Finding ,
                    'http://BrentOzar.com/go/model' AS URL ,
                    ( 'The ' + name
                      + ' table in the model database was created by end users on '
                      + CAST(create_date AS VARCHAR(20))
                      + '. Tables in the model database are automatically copied into all new databases.' ) AS Details
            FROM    model.sys.tables
            WHERE   is_ms_shipped = 0;


    IF ( SELECT COUNT(*)
         FROM   msdb.dbo.sysalerts
         WHERE  severity BETWEEN 19 AND 25
       ) < 7 
        INSERT  INTO #BlitzResults
                ( CheckID ,
                  Priority ,
                  FindingsGroup ,
                  Finding ,
                  URL ,
                  Details
                )
                SELECT  30 AS CheckID ,
                        50 AS Priority ,
                        'Reliability' AS FindingsGroup ,
                        'Not All Alerts Configured' AS Finding ,
                        'http://BrentOzar.com/go/alert' AS URL ,
                        ( 'Not all SQL Server Agent alerts have been configured.  This is a free, easy way to get notified of corruption, job failures, or major outages even before monitoring systems pick it up.' ) AS Details;
    
    IF EXISTS ( SELECT  *
                FROM    msdb.dbo.sysalerts
                WHERE   enabled = 1
                        AND COALESCE(has_notification, 0) = 0
                        AND job_id IS NULL ) 
        INSERT  INTO #BlitzResults
                ( CheckID ,
                  Priority ,
                  FindingsGroup ,
                  Finding ,
                  URL ,
                  Details
                )
                SELECT  59 AS CheckID ,
                        50 AS Priority ,
                        'Reliability' AS FindingsGroup ,
                        'Alerts Configured without Follow Up' AS Finding ,
                        'http://BrentOzar.com/go/alert' AS URL ,
                        ( 'SQL Server Agent alerts have been configured but they either do not notify anyone or else they do not take any action.  This is a free, easy way to get notified of corruption, job failures, or major outages even before monitoring systems pick it up.' ) AS Details;

    IF NOT EXISTS ( SELECT  *
                    FROM    msdb.dbo.sysalerts
                    WHERE   message_id IN ( 823, 824, 825 ) ) 
        INSERT  INTO #BlitzResults
                ( CheckID ,
                  Priority ,
                  FindingsGroup ,
                  Finding ,
                  URL ,
                  Details
                )
                SELECT  60 AS CheckID ,
                        50 AS Priority ,
                        'Reliability' AS FindingsGroup ,
                        'No Alerts for Corruption' AS Finding ,
                        'http://BrentOzar.com/go/alert' AS URL ,
                        ( 'SQL Server Agent alerts do not exist for errors 823, 824, and 825.  These three errors can give you notification about early hardware failure. Enabling them can prevent you a lot of heartbreak.' ) AS Details;

    IF NOT EXISTS ( SELECT  *
                    FROM    msdb.dbo.sysalerts
                    WHERE   severity BETWEEN 19 AND 25 ) 
        INSERT  INTO #BlitzResults
                ( CheckID ,
                  Priority ,
                  FindingsGroup ,
                  Finding ,
                  URL ,
                  Details
                )
                SELECT  61 AS CheckID ,
                        50 AS Priority ,
                        'Reliability' AS FindingsGroup ,
                        'No Alerts for Sev 19-25' AS Finding ,
                        'http://BrentOzar.com/go/alert' AS URL ,
                        ( 'SQL Server Agent alerts do not exist for severity levels 19 through 25.  These are some very severe SQL Server errors. Knowing that these are happening may let you recover from errors faster.' ) AS Details;

            --check for disabled alerts
    IF EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   enabled = 0 ) 
        INSERT  INTO #BlitzResults
                ( CheckID ,
                  Priority ,
                  FindingsGroup ,
                  Finding ,
                  URL ,
                  Details
            
                )
                SELECT  62 AS CheckID ,
                        50 AS Priority ,
                        'Reliability' AS FindingsGroup ,
                        'Alerts Disabled' AS Finding ,
                        'http://www.BrentOzar.com/go/alerts/' AS URL ,
                        ( 'The following Alert is disabled, please review and enable if desired: '
                          + name ) AS Details
                FROM    msdb.dbo.sysalerts
                WHERE   enabled = 0


    IF NOT EXISTS ( SELECT  *
                    FROM    msdb.dbo.sysoperators
                    WHERE   enabled = 1 ) 
        INSERT  INTO #BlitzResults
                ( CheckID ,
                  Priority ,
                  FindingsGroup ,
                  Finding ,
                  URL ,
                  Details
                )
                SELECT  31 AS CheckID ,
                        50 AS Priority ,
                        'Reliability' AS FindingsGroup ,
                        'No Operators Configured/Enabled' AS Finding ,
                        'http://BrentOzar.com/go/op' AS URL ,
                        ( 'No SQL Server Agent operators (emails) have been configured.  This is a free, easy way to get notified of corruption, job failures, or major outages even before monitoring systems pick it up.' ) AS Details;

    IF @@VERSION NOT LIKE '%Microsoft SQL Server 2000%'
        AND @@VERSION NOT LIKE '%Microsoft SQL Server 2005%' 
        BEGIN
            EXEC dbo.sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT DISTINCT 33, 200, ''Licensing'', ''Enterprise Edition Features In Use'', ''http://BrentOzar.com/go/ee'', (''The ['' + DB_NAME() + ''] database is using '' + feature_name + ''.  If this database is restored onto a Standard Edition server, the restore will fail.'') FROM [?].sys.dm_db_persisted_sku_features';
        END;

    IF @@VERSION NOT LIKE '%Microsoft SQL Server 2000%'
        AND @@VERSION NOT LIKE '%Microsoft SQL Server 2005%' 
        BEGIN
            SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
            SELECT TOP 1
                    34 AS CheckID ,
                    1 AS Priority ,
                    ''Corruption'' AS FindingsGroup ,
                    ''Database Corruption Detected'' AS Finding ,
                    ''http://BrentOzar.com/go/repair'' AS URL ,
                    ( ''Database mirroring has automatically repaired at least one corrupt page in the last 30 days. For more information, query the DMV sys.dm_db_mirroring_auto_page_repair.'' ) AS Details
            FROM    sys.dm_db_mirroring_auto_page_repair
            WHERE   modification_time >= DATEADD(dd, -30, GETDATE()) ;'
            EXECUTE(@StringToExecute)
        END;

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT DISTINCT
                    36 AS CheckID ,
                    100 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Slow Storage Reads on Drive '
                    + UPPER(LEFT(mf.physical_name, 1)) AS Finding ,
                    'http://BrentOzar.com/go/slow' AS URL ,
                    'Reads are averaging longer than 100ms for at least one database on this drive.  For specific database file speeds, run the query from the information link.' AS Details
            FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS fs
                    INNER JOIN sys.master_files AS mf ON fs.database_id = mf.database_id
                                                         AND fs.[file_id] = mf.[file_id]
            WHERE   ( io_stall_read_ms / ( 1.0 + num_of_reads ) ) > 100;

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT DISTINCT
                    37 AS CheckID ,
                    100 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Slow Storage Writes on Drive '
                    + UPPER(LEFT(mf.physical_name, 1)) AS Finding ,
                    'http://BrentOzar.com/go/slow' AS URL ,
                    'Writes are averaging longer than 20ms for at least one database on this drive.  For specific database file speeds, run the query from the information link.' AS Details
            FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS fs
                    INNER JOIN sys.master_files AS mf ON fs.database_id = mf.database_id
                                                         AND fs.[file_id] = mf.[file_id]
            WHERE   ( io_stall_write_ms / ( 1.0 + num_of_writes ) ) > 20;


    IF ( SELECT COUNT(*)
         FROM   tempdb.sys.database_files
         WHERE  type_desc = 'ROWS'
       ) = 1 
        BEGIN
            INSERT  INTO #BlitzResults
                    ( CheckID ,
                      Priority ,
                      FindingsGroup ,
                      Finding ,
                      URL ,
                      Details
                    )
            VALUES  ( 40 ,
                      100 ,
                      'Performance' ,
                      'TempDB Only Has 1 Data File' ,
                      'http://BrentOzar.com/go/tempdb' ,
                      'TempDB is only configured with one data file.  More data files are usually required to alleviate SGAM contention.'
                    );
        END;

    EXEC dbo.sp_MSforeachdb 'use [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT 41, 100, ''Performance'', ''Multiple Log Files on One Drive'', ''http://BrentOzar.com/go/manylogs'', (''The ['' + DB_NAME() + ''] database has multiple log files on the '' + LEFT(physical_name, 1) + '' drive. This is not a performance booster because log file access is sequential, not parallel.'') FROM [?].sys.database_files WHERE type_desc = ''LOG'' AND ''?'' <> ''[tempdb]'' GROUP BY LEFT(physical_name, 1) HAVING COUNT(*) > 1';

    EXEC dbo.sp_MSforeachdb 'use [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT DISTINCT 42, 100, ''Performance'', ''Uneven File Growth Settings in One Filegroup'', ''http://BrentOzar.com/go/grow'', (''The ['' + DB_NAME() + ''] database has multiple data files in one filegroup, but they are not all set up to grow in identical amounts.  This can lead to uneven file activity inside the filegroup.'') FROM [?].sys.database_files WHERE type_desc = ''ROWS'' GROUP BY data_space_id HAVING COUNT(DISTINCT growth) > 1 OR COUNT(DISTINCT is_percent_growth) > 1';

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
                    
            )
            SELECT  44 AS CheckID ,
                    110 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Queries Forcing Order Hints' AS Finding ,
                    'http://BrentOzar.com/go/hints' AS URL ,
                    CAST(occurrence AS VARCHAR(10))
                    + ' instances of order hinting have been recorded since restart.  This means queries are bossing the SQL Server optimizer around, and if they don''t know what they''re doing, this can cause more harm than good.  This can also explain why DBA tuning efforts aren''t working.' AS Details
            FROM    sys.dm_exec_query_optimizer_info
            WHERE   counter = 'order hint'
                    AND occurrence > 1

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  45 AS CheckID ,
                    110 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Queries Forcing Join Hints' AS Finding ,
                    'http://BrentOzar.com/go/hints' AS URL ,
                    CAST(occurrence AS VARCHAR(10))
                    + ' instances of join hinting have been recorded since restart.  This means queries are bossing the SQL Server optimizer around, and if they don''t know what they''re doing, this can cause more harm than good.  This can also explain why DBA tuning efforts aren''t working.' AS Details
            FROM    sys.dm_exec_query_optimizer_info
            WHERE   counter = 'join hint'
                    AND occurrence > 1



    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT DISTINCT
                    49 AS CheckID ,
                    200 AS Priority ,
                    'Informational' AS FindingsGroup ,
                    'Linked Server Configured' AS Finding ,
                    'http://BrentOzar.com/go/link' AS URL ,
                    +CASE WHEN l.remote_name = 'sa'
                          THEN s.data_source
                               + ' is configured as a linked server. Check its security configuration as it is connecting with sa, because any user who queries it will get admin-level permissions.'
                          ELSE s.data_source
                               + ' is configured as a linked server. Check its security configuration to make sure it isn''t connecting with SA or some other bone-headed administrative login, because any user who queries it might get admin-level permissions.'
                     END AS Details
            FROM    sys.servers s
                    INNER JOIN sys.linked_logins l ON s.server_id = l.server_id
            WHERE   s.is_linked = 1



    IF @@VERSION NOT LIKE '%Microsoft SQL Server 2000%'
        AND @@VERSION NOT LIKE '%Microsoft SQL Server 2005%' 
        BEGIN
            SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
            SELECT  50 AS CheckID ,
                    100 AS Priority ,
                    ''Performance'' AS FindingsGroup ,
                    ''Max Memory Set Too High'' AS Finding ,
                    ''http://BrentOzar.com/go/max'' AS URL ,
                    ''SQL Server max memory is set to ''
                    + CAST(c.value_in_use AS VARCHAR(20))
                    + '' megabytes, but the server only has ''
                    + CAST(( CAST(m.total_physical_memory_kb AS BIGINT) / 1024 ) AS VARCHAR(20))
                    + '' megabytes.  SQL Server may drain the system dry of memory, and under certain conditions, this can cause Windows to swap to disk.'' AS Details
            FROM    sys.dm_os_sys_memory m
                    INNER JOIN sys.configurations c ON c.name = ''max server memory (MB)''
            WHERE   CAST(m.total_physical_memory_kb AS BIGINT) < ( CAST(c.value_in_use AS BIGINT) * 1024 )'
            EXECUTE(@StringToExecute)
        END;


    IF @@VERSION NOT LIKE '%Microsoft SQL Server 2000%'
        AND @@VERSION NOT LIKE '%Microsoft SQL Server 2005%' 
        BEGIN
            SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
            SELECT  51 AS CheckID ,
                    1 AS Priority ,
                    ''Performance'' AS FindingsGroup ,
                    ''Memory Dangerously Low'' AS Finding ,
                    ''http://BrentOzar.com/go/max'' AS URL ,
                    ''Although available memory is ''
                    + CAST(( CAST(m.available_physical_memory_kb AS BIGINT)
                             / 1024 ) AS VARCHAR(20))
                    + '' megabytes, only ''
                    + CAST(( CAST(m.total_physical_memory_kb AS BIGINT) / 1024 ) AS VARCHAR(20))
                    + ''megabytes of memory are present.  As the server runs out of memory, there is danger of swapping to disk, which will kill performance.'' AS Details
            FROM    sys.dm_os_sys_memory m
            WHERE   CAST(m.available_physical_memory_kb AS BIGINT) < 262144'
            EXECUTE(@StringToExecute)
        END;


    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT TOP 1
                    53 AS CheckID ,
                    200 AS Priority ,
                    'High Availability' AS FindingsGroup ,
                    'Cluster Node' AS Finding ,
                    'http://BrentOzar.com/go/node' AS URL ,
                    'This is a node in a cluster.' AS Details
            FROM    sys.dm_os_cluster_nodes

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  55 AS CheckID ,
                    200 AS Priority ,
                    'Security' AS FindingsGroup ,
                    'Database Owner <> SA' AS Finding ,
                    'http://BrentOzar.com/go/owndb' AS URL ,
                    ( 'Database name: ' + name + '   ' + 'Owner name: '
                      + SUSER_SNAME(owner_sid) ) AS Details
            FROM    sys.databases
            WHERE   SUSER_SNAME(owner_sid) <> SUSER_SNAME(0x01);

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  57 AS CheckID ,
                    10 AS Priority ,
                    'Security' AS FindingsGroup ,
                    'SQL Agent Job Runs at Startup' AS Finding ,
                    'http://BrentOzar.com/go/startup' AS URL ,
                    ( 'Job ' + j.name
                      + '] runs automatically when SQL Server Agent starts up.  Make sure you know exactly what this job is doing, because it could pose a security risk.' ) AS Details
            FROM    msdb.dbo.sysschedules sched
                    JOIN msdb.dbo.sysjobschedules jsched ON sched.schedule_id = jsched.schedule_id
                    JOIN msdb.dbo.sysjobs j ON jsched.job_id = j.job_id
            WHERE   sched.freq_type = 64;


    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  58 AS CheckID ,
                    200 AS Priority ,
                    'Reliability' AS FindingsGroup ,
                    'Database Collation Mismatch' AS Finding ,
                    'http://BrentOzar.com/go/collate' AS URL ,
                    ( 'Database ' + d.NAME + ' has collation '
                      + d.collation_name + '; Server collation is '
                      + CONVERT(VARCHAR(100), SERVERPROPERTY('collation')) ) AS Details
            FROM    master.sys.databases d
            WHERE   d.collation_name <> SERVERPROPERTY('collation')

    EXEC sp_MSforeachdb 'use [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
SELECT  DISTINCT 82 AS CheckID, 
        100 AS Priority, 
        ''Performance'' AS FindingsGroup, 
        ''File growth set to percent'', 
        ''http://brentozar.com/go/percentgrowth'' AS URL,
        ''The ['' + DB_NAME() + ''] database is using percent filegrowth settings. This can lead to out of control filegrowth.''
FROM    [?].sys.database_files 
WHERE   is_percent_growth = 1 ';


    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  61 AS CheckID ,
                    100 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Unusual SQL Server Edition' AS Finding ,
                    'http://BrentOzar.com/go/workgroup' AS URL ,
                    ( 'This server is using '
                      + CAST(SERVERPROPERTY('edition') AS VARCHAR(100))
                      + ', which is capped at low amounts of CPU and memory.' ) AS Details
            WHERE   CAST(SERVERPROPERTY('edition') AS VARCHAR(100)) NOT LIKE '%Standard%'
                    AND CAST(SERVERPROPERTY('edition') AS VARCHAR(100)) NOT LIKE '%Enterprise%'
                    AND CAST(SERVERPROPERTY('edition') AS VARCHAR(100)) NOT LIKE '%Developer%'

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
	          
            )
            SELECT  62 AS CheckID ,
                    200 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Old Compatibility Level' AS Finding ,
                    'http://BrentOzar.com/go/compatlevel' AS URL ,
                    ( 'Database ' + name + ' is compatibility level '
                      + CAST(compatibility_level AS VARCHAR(20))
                      + ', which may cause unwanted results when trying to run queries that have newer T-SQL features.' ) AS Details
            FROM    sys.databases
            WHERE   compatibility_level <> ( SELECT compatibility_level
                                             FROM   sys.databases
                                             WHERE  name = 'model'
                                           )
	  
	  
	  

    IF @CheckUserDatabaseObjects = 1 
        BEGIN

            EXEC dbo.sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT DISTINCT 32, 110, ''Performance'', ''Triggers on Tables'', ''http://BrentOzar.com/go/trig'', (''The ['' + DB_NAME() + ''] database has triggers on the '' + s.name + ''.'' + o.name + '' table.'') FROM [?].sys.triggers t INNER JOIN [?].sys.objects o ON t.parent_id = o.object_id INNER JOIN [?].sys.schemas s ON o.schema_id = s.schema_id WHERE t.is_ms_shipped = 0';

            EXEC dbo.sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT DISTINCT 38, 110, ''Performance'', ''Active Tables Without Clustered Indexes'', ''http://BrentOzar.com/go/heaps'', (''The ['' + DB_NAME() + ''] database has heaps - tables without a clustered index - that are being actively queried.'') FROM [?].sys.indexes i INNER JOIN [?].sys.objects o ON i.object_id = o.object_id INNER JOIN [?].sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id INNER JOIN sys.databases sd ON sd.name = ''?'' LEFT OUTER JOIN [?].sys.dm_db_index_usage_stats ius ON i.object_id = ius.object_id AND i.index_id = ius.index_id AND ius.database_id = sd.database_id WHERE i.type_desc = ''HEAP'' AND COALESCE(ius.user_seeks, ius.user_scans, ius.user_lookups, ius.user_updates) IS NOT NULL AND sd.name <> ''tempdb'' AND o.is_ms_shipped = 0 AND o.type <> ''S''';

            EXEC dbo.sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT DISTINCT 39, 110, ''Performance'', ''Inactive Tables Without Clustered Indexes'', ''http://BrentOzar.com/go/heaps'', (''The ['' + DB_NAME() + ''] database has heaps - tables without a clustered index - that have not been queried since the last restart.  These may be backup tables carelessly left behind.'') FROM [?].sys.indexes i INNER JOIN [?].sys.objects o ON i.object_id = o.object_id INNER JOIN [?].sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id INNER JOIN sys.databases sd ON sd.name = ''?'' LEFT OUTER JOIN [?].sys.dm_db_index_usage_stats ius ON i.object_id = ius.object_id AND i.index_id = ius.index_id AND ius.database_id = sd.database_id WHERE i.type_desc = ''HEAP'' AND COALESCE(ius.user_seeks, ius.user_scans, ius.user_lookups, ius.user_updates) IS NULL AND sd.name <> ''tempdb'' AND o.is_ms_shipped = 0 AND o.type <> ''S''';

            EXEC dbo.sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT 46, 100, ''Performance'', ''Leftover Fake Indexes From Wizards'', ''http://BrentOzar.com/go/hypo'', (''The index ['' + DB_NAME() + ''].['' + s.name + ''].['' + o.name + ''].['' + i.name + ''] is a leftover hypothetical index from the Index Tuning Wizard or Database Tuning Advisor.  This index is not actually helping performance and should be removed.'') from [?].sys.indexes i INNER JOIN [?].sys.objects o ON i.object_id = o.object_id INNER JOIN [?].sys.schemas s ON o.schema_id = s.schema_id WHERE i.is_hypothetical = 1';

            EXEC dbo.sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT 47, 100, ''Performance'', ''Indexes Disabled'', ''http://BrentOzar.com/go/ixoff'', (''The index ['' + DB_NAME() + ''].['' + s.name + ''].['' + o.name + ''].['' + i.name + ''] is disabled.  This index is not actually helping performance and should either be enabled or removed.'') from [?].sys.indexes i INNER JOIN [?].sys.objects o ON i.object_id = o.object_id INNER JOIN [?].sys.schemas s ON o.schema_id = s.schema_id WHERE i.is_disabled = 1';

            EXEC dbo.sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT DISTINCT 48, 100, ''Performance'', ''Foreign Keys Not Trusted'', ''http://BrentOzar.com/go/trust'', (''The ['' + DB_NAME() + ''] database has foreign keys that were probably disabled, data was changed, and then the key was enabled again.  Simply enabling the key is not enough for the optimizer to use this key - we have to alter the table using the WITH CHECK CHECK CONSTRAINT parameter.'') from [?].sys.foreign_keys i INNER JOIN [?].sys.objects o ON i.parent_object_id = o.object_id INNER JOIN [?].sys.schemas s ON o.schema_id = s.schema_id WHERE i.is_not_trusted = 1 AND i.is_not_for_replication = 0 AND i.is_disabled = 0';

            EXEC dbo.sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT 56, 100, ''Performance'', ''Check Constraint Not Trusted'', ''http://BrentOzar.com/go/trust'', (''The check constraint ['' + DB_NAME() + ''].['' + s.name + ''].['' + o.name + ''].['' + i.name + ''] is not trusted - meaning, it was disabled, data was changed, and then the constraint was enabled again.  Simply enabling the constraint is not enough for the optimizer to use this constraint - we have to alter the table using the WITH CHECK CHECK CONSTRAINT parameter.'') from [?].sys.check_constraints i INNER JOIN [?].sys.objects o ON i.parent_object_id = o.object_id INNER JOIN [?].sys.schemas s ON o.schema_id = s.schema_id WHERE i.is_not_trusted = 1 AND i.is_not_for_replication = 0 AND i.is_disabled = 0';

            IF @@VERSION NOT LIKE '%Microsoft SQL Server 2000%'
                AND @@VERSION NOT LIKE '%Microsoft SQL Server 2005%' 
                BEGIN
                    EXEC dbo.sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT TOP 1 13 AS CheckID, 110 AS Priority, ''Performance'' AS FindingsGroup, ''Plan Guides Enabled'' AS Finding, ''http://BrentOzar.com/go/guides'' AS URL, (''Database ['' + DB_NAME() + ''] has query plan guides so a query will always get a specific execution plan. If you are having trouble getting query performance to improve, it might be due to a frozen plan. Review the DMV sys.plan_guides to learn more about the plan guides in place on this server.'') AS Details FROM [?].sys.plan_guides WHERE is_disabled = 0'
                END;

            EXEC sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
		SELECT  DISTINCT 60 AS CheckID, 
		        100 AS Priority, 
		        ''Performance'' AS FindingsGroup, 
		        ''Fill Factor Changed'', 
		        ''http://brentozar.com/go/fillfactor'' AS URL,
		        ''The ['' + DB_NAME() + ''] database has objects with fill factor <> 0. This can cause memory and storage performance problems, but may also prevent page splits.''
		FROM    [?].sys.indexes 
		WHERE   fill_factor <> 0 AND fill_factor <> 100 AND is_disabled = 0 AND is_hypothetical = 0';

            EXEC dbo.sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT 78, 100, ''Performance'', ''Stored Procedure WITH RECOMPILE'', ''http://BrentOzar.com/go/recompile'', (''['' + DB_NAME() + ''].['' + SPECIFIC_SCHEMA + ''].['' + SPECIFIC_NAME + ''] has WITH RECOMPILE in the stored procedure code, which may cause increased CPU usage due to constant recompiles of the code.'') from [?].INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_DEFINITION LIKE N''%WITH RECOMPILE%''';

            EXEC dbo.sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT DISTINCT 86, 20, ''Security'', ''Elevated Permissions on a Database'', ''http://BrentOzar.com/go/elevated'', (''In ['' + DB_NAME() + ''], user ['' + u.name + '']  has the role ['' + g.name + ''].  This user can perform tasks beyond just reading and writing data.'') FROM [?].dbo.sysmembers m inner join [?].dbo.sysusers u on m.memberuid = u.uid inner join sysusers g on m.groupuid = g.uid where u.name <> ''dbo'' and g.name in (''db_owner'' , ''db_accessAdmin'' , ''db_securityadmin'' , ''db_ddladmin'')';



        END /* IF @CheckUserDatabaseObjects = 1 */


    IF @CheckProcedureCache = 1 
        BEGIN
			
            INSERT  INTO #BlitzResults
                    ( CheckID ,
                      Priority ,
                      FindingsGroup ,
                      Finding ,
                      URL ,
                      Details
	                    
                    )
                    SELECT  35 AS CheckID ,
                            100 AS Priority ,
                            'Performance' AS FindingsGroup ,
                            'Single-Use Plans in Procedure Cache' AS Finding ,
                            'http://BrentOzar.com/go/single' AS URL ,
                            ( CAST(COUNT(*) AS VARCHAR(10))
                              + ' query plans are taking up memory in the procedure cache. This may be wasted memory if we cache plans for queries that never get called again. This may be a good use case for SQL Server 2008''s Optimize for Ad Hoc or for Forced Parameterization.' ) AS Details
                    FROM    sys.dm_exec_cached_plans AS cp
                    WHERE   cp.usecounts = 1
                            AND cp.objtype = 'Adhoc'
                            AND EXISTS ( SELECT 1
                                         FROM   sys.configurations
                                         WHERE  name = 'optimize for ad hoc workloads'
                                                AND value_in_use = 0 )
                    HAVING  COUNT(*) > 1;


				/* Set up the cache tables. Different on 2005 since it doesn't support query_hash, query_plan_hash. */
            IF @@VERSION LIKE '%Microsoft SQL Server 2005%' 
                BEGIN
                    IF @CheckProcedureCacheFilter = 'CPU'
                        OR @CheckProcedureCacheFilter IS NULL 
                        BEGIN
                            SET @StringToExecute = 'WITH queries ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time])
			            AS (SELECT TOP 20 qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time]
						FROM sys.dm_exec_query_stats qs
						ORDER BY qs.total_worker_time DESC)
						INSERT INTO #dm_exec_query_stats ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time])
						SELECT qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time]
						FROM queries qs
						LEFT OUTER JOIN #dm_exec_query_stats qsCaught ON qs.sql_handle = qsCaught.sql_handle AND qs.plan_handle = qsCaught.plan_handle AND qs.statement_start_offset = qsCaught.statement_start_offset
						WHERE qsCaught.sql_handle IS NULL;'
                            EXECUTE(@StringToExecute)
                        END

                    IF @CheckProcedureCacheFilter = 'Reads'
                        OR @CheckProcedureCacheFilter IS NULL 
                        BEGIN
                            SET @StringToExecute = 'WITH queries ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time])
			            AS (SELECT TOP 20 qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time]
						FROM sys.dm_exec_query_stats qs
						ORDER BY qs.total_logical_reads DESC)
						INSERT INTO #dm_exec_query_stats ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time])
						SELECT qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time]
						FROM queries qs
						LEFT OUTER JOIN #dm_exec_query_stats qsCaught ON qs.sql_handle = qsCaught.sql_handle AND qs.plan_handle = qsCaught.plan_handle AND qs.statement_start_offset = qsCaught.statement_start_offset
						WHERE qsCaught.sql_handle IS NULL;'
                        END

                    IF @CheckProcedureCacheFilter = 'ExecCount'
                        OR @CheckProcedureCacheFilter IS NULL 
                        BEGIN
                            SET @StringToExecute = 'WITH queries ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time])
			            AS (SELECT TOP 20 qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time]
						FROM sys.dm_exec_query_stats qs
						ORDER BY qs.execution_count DESC)
						INSERT INTO #dm_exec_query_stats ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time])
						SELECT qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time]
						FROM queries qs
						LEFT OUTER JOIN #dm_exec_query_stats qsCaught ON qs.sql_handle = qsCaught.sql_handle AND qs.plan_handle = qsCaught.plan_handle AND qs.statement_start_offset = qsCaught.statement_start_offset
						WHERE qsCaught.sql_handle IS NULL;'
                            EXECUTE(@StringToExecute)
                        END

                    IF @CheckProcedureCacheFilter = 'Duration'
                        OR @CheckProcedureCacheFilter IS NULL 
                        BEGIN
                            SET @StringToExecute = 'WITH queries ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time])
			            AS (SELECT TOP 20 qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time]
						FROM sys.dm_exec_query_stats qs
						ORDER BY qs.total_elapsed_time DESC)
						INSERT INTO #dm_exec_query_stats ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time])
						SELECT qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time]
						FROM queries qs
						LEFT OUTER JOIN #dm_exec_query_stats qsCaught ON qs.sql_handle = qsCaught.sql_handle AND qs.plan_handle = qsCaught.plan_handle AND qs.statement_start_offset = qsCaught.statement_start_offset
						WHERE qsCaught.sql_handle IS NULL;'
                            EXECUTE(@StringToExecute)
                        END

                END;
            IF @@VERSION LIKE '%Microsoft SQL Server 2008%'
                OR @@VERSION LIKE '%Microsoft SQL Server 2012%' 
                BEGIN
                    IF @CheckProcedureCacheFilter = 'CPU'
                        OR @CheckProcedureCacheFilter IS NULL 
                        BEGIN
                            SET @StringToExecute = 'WITH queries ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time],[query_hash],[query_plan_hash])
			            AS (SELECT TOP 20 qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time],qs.[query_hash],qs.[query_plan_hash]
						FROM sys.dm_exec_query_stats qs
						ORDER BY qs.total_worker_time DESC)
						INSERT INTO #dm_exec_query_stats ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time],[query_hash],[query_plan_hash])
						SELECT qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time],qs.[query_hash],qs.[query_plan_hash]
						FROM queries qs
						LEFT OUTER JOIN #dm_exec_query_stats qsCaught ON qs.sql_handle = qsCaught.sql_handle AND qs.plan_handle = qsCaught.plan_handle AND qs.statement_start_offset = qsCaught.statement_start_offset
						WHERE qsCaught.sql_handle IS NULL;'
                            EXECUTE(@StringToExecute)
                        END

                    IF @CheckProcedureCacheFilter = 'Reads'
                        OR @CheckProcedureCacheFilter IS NULL 
                        BEGIN
                            SET @StringToExecute = 'WITH queries ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time],[query_hash],[query_plan_hash])
			            AS (SELECT TOP 20 qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time],qs.[query_hash],qs.[query_plan_hash]
						FROM sys.dm_exec_query_stats qs
						ORDER BY qs.total_logical_reads DESC)
						INSERT INTO #dm_exec_query_stats ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time],[query_hash],[query_plan_hash])
						SELECT qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time],qs.[query_hash],qs.[query_plan_hash]
						FROM queries qs
						LEFT OUTER JOIN #dm_exec_query_stats qsCaught ON qs.sql_handle = qsCaught.sql_handle AND qs.plan_handle = qsCaught.plan_handle AND qs.statement_start_offset = qsCaught.statement_start_offset
						WHERE qsCaught.sql_handle IS NULL;'
                            EXECUTE(@StringToExecute)
                        END
	
                    IF @CheckProcedureCacheFilter = 'ExecCount'
                        OR @CheckProcedureCacheFilter IS NULL 
                        BEGIN
                            SET @StringToExecute = 'WITH queries ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time],[query_hash],[query_plan_hash])
			            AS (SELECT TOP 20 qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time],qs.[query_hash],qs.[query_plan_hash]
						FROM sys.dm_exec_query_stats qs
						ORDER BY qs.execution_count DESC)
						INSERT INTO #dm_exec_query_stats ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time],[query_hash],[query_plan_hash])
						SELECT qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time],qs.[query_hash],qs.[query_plan_hash]
						FROM queries qs
						LEFT OUTER JOIN #dm_exec_query_stats qsCaught ON qs.sql_handle = qsCaught.sql_handle AND qs.plan_handle = qsCaught.plan_handle AND qs.statement_start_offset = qsCaught.statement_start_offset
						WHERE qsCaught.sql_handle IS NULL;'
                            EXECUTE(@StringToExecute)
                        END

                    IF @CheckProcedureCacheFilter = 'Duration'
                        OR @CheckProcedureCacheFilter IS NULL 
                        BEGIN
                            SET @StringToExecute = 'WITH queries ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time],[query_hash],[query_plan_hash])
			            AS (SELECT TOP 20 qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time],qs.[query_hash],qs.[query_plan_hash]
						FROM sys.dm_exec_query_stats qs
						ORDER BY qs.total_elapsed_time DESC)
						INSERT INTO #dm_exec_query_stats ([sql_handle],[statement_start_offset],[statement_end_offset],[plan_generation_num],[plan_handle],[creation_time],[last_execution_time],[execution_count],[total_worker_time],[last_worker_time],[min_worker_time],[max_worker_time],[total_physical_reads],[last_physical_reads],[min_physical_reads],[max_physical_reads],[total_logical_writes],[last_logical_writes],[min_logical_writes],[max_logical_writes],[total_logical_reads],[last_logical_reads],[min_logical_reads],[max_logical_reads],[total_clr_time],[last_clr_time],[min_clr_time],[max_clr_time],[total_elapsed_time],[last_elapsed_time],[min_elapsed_time],[max_elapsed_time],[query_hash],[query_plan_hash])
						SELECT qs.[sql_handle],qs.[statement_start_offset],qs.[statement_end_offset],qs.[plan_generation_num],qs.[plan_handle],qs.[creation_time],qs.[last_execution_time],qs.[execution_count],qs.[total_worker_time],qs.[last_worker_time],qs.[min_worker_time],qs.[max_worker_time],qs.[total_physical_reads],qs.[last_physical_reads],qs.[min_physical_reads],qs.[max_physical_reads],qs.[total_logical_writes],qs.[last_logical_writes],qs.[min_logical_writes],qs.[max_logical_writes],qs.[total_logical_reads],qs.[last_logical_reads],qs.[min_logical_reads],qs.[max_logical_reads],qs.[total_clr_time],qs.[last_clr_time],qs.[min_clr_time],qs.[max_clr_time],qs.[total_elapsed_time],qs.[last_elapsed_time],qs.[min_elapsed_time],qs.[max_elapsed_time],qs.[query_hash],qs.[query_plan_hash]
						FROM queries qs
						LEFT OUTER JOIN #dm_exec_query_stats qsCaught ON qs.sql_handle = qsCaught.sql_handle AND qs.plan_handle = qsCaught.plan_handle AND qs.statement_start_offset = qsCaught.statement_start_offset
						WHERE qsCaught.sql_handle IS NULL;'
                            EXECUTE(@StringToExecute)
                        END

					/* Populate the query_plan_filtered field. Only works in 2005SP2+, but we're just doing it in 2008 to be safe. */
                    UPDATE  #dm_exec_query_stats
                    SET     query_plan_filtered = qp.query_plan
                    FROM    #dm_exec_query_stats qs
                            CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle,
                                                              qs.statement_start_offset,
                                                              qs.statement_end_offset)
                            AS qp 

                END;

				/* Populate the additional query_plan, text, and text_filtered fields */
            UPDATE  #dm_exec_query_stats
            SET     query_plan = qp.query_plan ,
                    [text] = st.[text] ,
                    text_filtered = SUBSTRING(st.text,
                                              ( qs.statement_start_offset / 2 )
                                              + 1,
                                              ( ( CASE qs.statement_end_offset
                                                    WHEN -1
                                                    THEN DATALENGTH(st.text)
                                                    ELSE qs.statement_end_offset
                                                  END
                                                  - qs.statement_start_offset )
                                                / 2 ) + 1)
            FROM    #dm_exec_query_stats qs
                    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
                    CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp

				/* Dump instances of our own script. We're not trying to tune ourselves. */
            DELETE  #dm_exec_query_stats
            WHERE   text LIKE '%sp_Blitz%'
                    OR text LIKE '%#BlitzResults%'

				/* Look for implicit conversions */
            INSERT  INTO #BlitzResults
                    ( CheckID ,
                      Priority ,
                      FindingsGroup ,
                      Finding ,
                      URL ,
                      Details ,
                      QueryPlan ,
                      QueryPlanFiltered
						  
                    )
                    SELECT  63 AS CheckID ,
                            120 AS Priority ,
                            'Query Plans' AS FindingsGroup ,
                            'Implicit Conversion' AS Finding ,
                            'http://BrentOzar.com/go/implicit' AS URL ,
                            ( 'One of the top resource-intensive queries is comparing two fields that are not the same datatype.' ) AS Details ,
                            qs.query_plan ,
                            qs.query_plan_filtered
                    FROM    #dm_exec_query_stats qs
                    WHERE   COALESCE(qs.query_plan_filtered,
                                     CAST(qs.query_plan AS NVARCHAR(MAX))) LIKE '%CONVERT_IMPLICIT%'
                            AND COALESCE(qs.query_plan_filtered,
                                         CAST(qs.query_plan AS NVARCHAR(MAX))) LIKE '%PhysicalOp="Index Scan"%'

            INSERT  INTO #BlitzResults
                    ( CheckID ,
                      Priority ,
                      FindingsGroup ,
                      Finding ,
                      URL ,
                      Details ,
                      QueryPlan ,
                      QueryPlanFiltered
								  
                    )
                    SELECT  63 AS CheckID ,
                            120 AS Priority ,
                            'Query Plans' AS FindingsGroup ,
                            'Implicit Conversion Affecting Cardinality' AS Finding ,
                            'http://BrentOzar.com/go/implicit' AS URL ,
                            ( 'One of the top resource-intensive queries has an implicit conversion that is affecting cardinality estimation.' ) AS Details ,
                            qs.query_plan ,
                            qs.query_plan_filtered
                    FROM    #dm_exec_query_stats qs
                    WHERE   COALESCE(qs.query_plan_filtered,
                                     CAST(qs.query_plan AS NVARCHAR(MAX))) LIKE '%<PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT%'


				/* Look for missing indexes */
            INSERT  INTO #BlitzResults
                    ( CheckID ,
                      Priority ,
                      FindingsGroup ,
                      Finding ,
                      URL ,
                      Details ,
                      QueryPlan ,
                      QueryPlanFiltered
						  
                    )
                    SELECT  65 AS CheckID ,
                            120 AS Priority ,
                            'Query Plans' AS FindingsGroup ,
                            'Missing Index' AS Finding ,
                            'http://BrentOzar.com/go/missingindex' AS URL ,
                            ( 'One of the top resource-intensive queries may be dramatically improved by adding an index.' ) AS Details ,
                            qs.query_plan ,
                            qs.query_plan_filtered
                    FROM    #dm_exec_query_stats qs
                    WHERE   COALESCE(qs.query_plan_filtered,
                                     CAST(qs.query_plan AS NVARCHAR(MAX))) LIKE '%MissingIndexGroup%'
				
				/* Look for cursors */
            INSERT  INTO #BlitzResults
                    ( CheckID ,
                      Priority ,
                      FindingsGroup ,
                      Finding ,
                      URL ,
                      Details ,
                      QueryPlan ,
                      QueryPlanFiltered
						  
                    )
                    SELECT  66 AS CheckID ,
                            120 AS Priority ,
                            'Query Plans' AS FindingsGroup ,
                            'Cursor' AS Finding ,
                            'http://BrentOzar.com/go/cursor' AS URL ,
                            ( 'One of the top resource-intensive queries is using a cursor.' ) AS Details ,
                            qs.query_plan ,
                            qs.query_plan_filtered
                    FROM    #dm_exec_query_stats qs
                    WHERE   COALESCE(qs.query_plan_filtered,
                                     CAST(qs.query_plan AS NVARCHAR(MAX))) LIKE '%<StmtCursor%'


				/* Look for scalar user-defined functions */
            INSERT  INTO #BlitzResults
                    ( CheckID ,
                      Priority ,
                      FindingsGroup ,
                      Finding ,
                      URL ,
                      Details ,
                      QueryPlan ,
                      QueryPlanFiltered
						  
                    )
                    SELECT  67 AS CheckID ,
                            120 AS Priority ,
                            'Query Plans' AS FindingsGroup ,
                            'Scalar UDFs' AS Finding ,
                            'http://BrentOzar.com/go/functions' AS URL ,
                            ( 'One of the top resource-intensive queries is using a user-defined scalar function that may inhibit parallelism.' ) AS Details ,
                            qs.query_plan ,
                            qs.query_plan_filtered
                    FROM    #dm_exec_query_stats qs
                    WHERE   COALESCE(qs.query_plan_filtered,
                                     CAST(qs.query_plan AS NVARCHAR(MAX))) LIKE '%<UserDefinedFunction%'

        END /* IF @CheckProcedureCache = 1 */

	/*Check for the last good DBCC CHECKDB date */
    CREATE TABLE #DBCCs
        (
          Id INT IDENTITY(1, 1)
                 PRIMARY KEY ,
          ParentObject VARCHAR(255) ,
          Object VARCHAR(255) ,
          Field VARCHAR(255) ,
          Value VARCHAR(255) ,
          DbName SYSNAME NULL
        )
    EXEC sp_MSforeachdb N'USE [?];
							INSERT #DBCCs(ParentObject, Object, Field, Value)
							EXEC (''DBCC DBInfo() With TableResults, NO_INFOMSGS'');
							UPDATE #DBCCs SET DbName = N''?'' WHERE DbName IS NULL;';


    WITH    DB2
              AS ( SELECT   DISTINCT
                            Field ,
                            Value ,
                            DbName
                   FROM     #DBCCs
                   WHERE    Field = 'dbi_dbccLastKnownGood'
                 )
        INSERT  INTO #BlitzResults
                ( CheckID ,
                  Priority ,
                  FindingsGroup ,
                  Finding ,
                  URL ,
                  Details
		                 
                )
                SELECT  68 AS CheckID ,
                        50 AS PRIORITY ,
                        'Reliability' AS FindingsGroup ,
                        'Last good DBCC CHECKDB over 2 weeks old' AS Finding ,
                        'http://BrentOzar.com/go/checkdb' AS URL ,
                        'Database [' + DB2.DbName + ']'
                        + CASE DB2.Value
                            WHEN '1900-01-01 00:00:00.000'
                            THEN ' never had a successful DBCC CHECKDB.'
                            ELSE ' last had a successful DBCC CHECKDB run on '
                                 + DB2.Value + '.'
                          END
                        + ' This check should be run regularly to catch any database corruption as soon as possible.'
                        + ' Note: you can restore a backup of a busy production database to a test server and run DBCC CHECKDB '
                        + ' against that to minimize impact. If you do that, you can ignore this warning.' AS Details
                FROM    DB2
                WHERE   CAST(DB2.Value AS DATETIME) < DATEADD(DD, -14,
                                                              CURRENT_TIMESTAMP)



/*Check for high VLF count: this will omit any database snapshots*/
    IF @@VERSION LIKE 'Microsoft SQL Server 2012%' 
        BEGIN
            CREATE TABLE #LogInfo2012
                (
                  recoveryunitid INT ,
                  FileID SMALLINT ,
                  FileSize BIGINT ,
                  StartOffset BIGINT ,
                  FSeqNo BIGINT ,
                  [Status] TINYINT ,
                  Parity TINYINT ,
                  CreateLSN NUMERIC(38)
                );
            EXEC sp_MSforeachdb N'USE [?];    
	INSERT INTO #LogInfo2012 
	EXEC sp_executesql N''DBCC LogInfo() WITH NO_INFOMSGS'';      
	IF    @@ROWCOUNT > 50            
		BEGIN
			INSERT  INTO #BlitzResults                        
			( CheckID                          
			,Priority                          
			,FindingsGroup                          
			,Finding                          
			,URL                          
			,Details)                  
			SELECT      69                              
			,100                              
			,''Performance''                              
			,''High VLF Count''                              
			,''http://BrentOzar.com/go/vlf ''                              
			,''The ['' + DB_NAME() + ''] database has '' +  CAST(COUNT(*) as VARCHAR(20)) + '' virtual log files (VLFs). This may be slowing down startup, restores, and even inserts/updates/deletes.''  
			FROM #LogInfo2012
			WHERE EXISTS (SELECT name FROM master.sys.databases 
							WHERE source_database_id is null) ;            
			END                       
			TRUNCATE TABLE #LogInfo2012;'
            DROP TABLE #LogInfo2012;
        END
    IF @@VERSION NOT LIKE 'Microsoft SQL Server 2012%' 
        BEGIN
            CREATE TABLE #LogInfo
                (
                  FileID SMALLINT ,
                  FileSize BIGINT ,
                  StartOffset BIGINT ,
                  FSeqNo BIGINT ,
                  [Status] TINYINT ,
                  Parity TINYINT ,
                  CreateLSN NUMERIC(38)
                );
            EXEC sp_MSforeachdb N'USE [?];    
	INSERT INTO #LogInfo 
	EXEC sp_executesql N''DBCC LogInfo() WITH NO_INFOMSGS'';      
	IF    @@ROWCOUNT > 50            
		BEGIN
			INSERT  INTO #BlitzResults                        
			( CheckID                          
			,Priority                          
			,FindingsGroup                          
			,Finding                          
			,URL                          
			,Details)                  
			SELECT      69                              
			,100                              
			,''Performance''                              
			,''High VLF Count''                              
			,''http://BrentOzar.com/go/vlf''                              
			,''The ['' + DB_NAME() + ''] database has '' +  CAST(COUNT(*) as VARCHAR(20)) + '' virtual log files (VLFs). This may be slowing down startup, restores, and even inserts/updates/deletes.''  
			FROM #LogInfo
			WHERE EXISTS (SELECT name FROM master.sys.databases 
							WHERE source_database_id is null);            
			END                       
			TRUNCATE TABLE #LogInfo;'
            DROP TABLE #LogInfo;
        END
	
/*Verify that the servername is set */
	
    IF @@SERVERNAME IS NULL 
        BEGIN
            INSERT  INTO #BlitzResults
                    ( CheckID ,
                      Priority ,
                      FindingsGroup ,
                      Finding ,
                      URL ,
                      Details
                    )
                    SELECT  70 AS CheckID ,
                            200 AS Priority ,
                            'Configuration' AS FindingsGroup ,
                            '@@Servername not set' AS Finding ,
                            'http://BrentOzar.com/go/servername' AS URL ,
                            '@@Servername variable is null. Correct by executing "sp_addserver ''<LocalServerName>'', local"' AS Details
        END;


/*Check for non-aligned indexes in partioned databases*/
    CREATE TABLE #partdb
        (
          dbname VARCHAR(100) ,
          objectname VARCHAR(200) ,
          type_desc VARCHAR(50)
        )
    EXEC dbo.sp_MSforeachdb 'USE [?]; insert into #partdb(dbname, objectname, type_desc)
SELECT distinct db_name(database_id) as DBName,o.name Object_Name,
ds.type_desc
 FROM sys.objects AS o
      JOIN sys.indexes AS i
  ON o.object_id = i.object_id 
JOIN sys.data_spaces ds on ds.data_space_id = i.data_space_id
  LEFT OUTER JOIN 
  sys.dm_db_index_usage_stats AS s    
 ON i.object_id = s.object_id   
  AND i.index_id = s.index_id
  WHERE  o.type = ''u''
 -- Clustered and Non-Clustered indexes
   AND i.type IN (1, 2) 
AND o.name in 
	(
SELECT a.name from 
    (SELECT ob.name, ds.type_desc from sys.objects ob JOIN sys.indexes ind on ind.object_id = ob.object_id join sys.data_spaces ds on ds.data_space_id = ind.data_space_id
		GROUP BY ob.name, ds.type_desc ) a group by a.name having COUNT (*) > 1
	)'
	
    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT DISTINCT
                    72 AS CheckId ,
                    100 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'The partioned database ' + dbname
                    + ' may have non-aligned indexes' AS Finding ,
                    'http://BrentOzar.com/go/aligned' AS URL ,
                    'Having non-aligned indexes on partitioned tables may cause inefficient query plans and CPU pressure' AS Details
            FROM    #partdb
            WHERE   dbname IS NOT	NULL
    DROP TABLE #partdb

/*Check to see if a failsafe operator has been configured*/

    DECLARE @AlertInfo TABLE
        (
          FailSafeOperator NVARCHAR(255) ,
          NotificationMethod INT ,
          ForwardingServer NVARCHAR(255) ,
          ForwardingSeverity INT ,
          PagerToTemplate NVARCHAR(255) ,
          PagerCCTemplate NVARCHAR(255) ,
          PagerSubjectTemplate NVARCHAR(255) ,
          PagerSendSubjectOnly NVARCHAR(255) ,
          ForwardAlways INT
        )

    INSERT  INTO @AlertInfo
            EXEC [master].[dbo].[sp_MSgetalertinfo] @includeaddresses = 0
    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
                
            )
            SELECT  73 AS CheckID ,
                    50 AS Priority ,
                    'Reliability' AS FindingsGroup ,
                    'No failsafe operator configured' AS Finding ,
                    'http://BrentOzar.com/go/failsafe' AS URL ,
                    ( 'No failsafe operator is configured on this server.  This is a good idea just in-case there are issues with the [msdb] database that prevents alerting.' ) AS Details
            FROM    @AlertInfo
            WHERE   FailSafeOperator IS NULL;

/*Identify globally enabled trace flags*/
    IF OBJECT_ID('tempdb..#TraceStatus') IS NOT NULL 
        DROP TABLE #TraceStatus;
    CREATE TABLE #TraceStatus
        (
          TraceFlag VARCHAR(10) ,
          status BIT ,
          Global BIT ,
          Session BIT
        );

    INSERT  INTO #TraceStatus
            EXEC ( ' DBCC TRACESTATUS(-1) WITH NO_INFOMSGS'
                )

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  74 AS CheckID ,
                    200 AS Priority ,
                    'Global Trace Flag' AS FindingsGroup ,
                    'TraceFlag On' AS Finding ,
                    'http://www.BrentOzar.com/go/traceflags/' AS URL ,
                    'Trace flag ' + T.TraceFlag + ' is enabled globally.' ASDetails
            FROM    #TraceStatus T

/*Check for transaction log file larger than data file */

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  75 AS CheckId ,
                    50 AS Priority ,
                    'Reliability' AS FindingsGroup ,
                    'Transaction Log Larger than Data File' AS Finding ,
                    'http://BrentOzar.com/go/biglog' AS URL ,
                    'The database [' + DB_NAME(a.database_id)
                    + '] has a transaction log file larger than a data file. This may indicate that transaction log backups are not being performed or not performed often enough.' AS Details
            FROM    sys.master_files a
            WHERE   a.type = 1
                    AND a.size > 125000 /* Size is measured in pages here, so this gets us log files over 1GB. */
                    AND a.size > ( SELECT   SUM(b.size)
                                   FROM     sys.master_files b
                                   WHERE    a.database_id = b.database_id
                                            AND b.type = 0
                                 )
                    AND a.database_id IN ( SELECT   database_id
                                           FROM     sys.databases
                                           WHERE    source_database_id IS NULL )

/*Check for collation conflicts between user databases and tempdb */
    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  76 AS CheckId ,
                    50 AS Priority ,
                    'Reliability' AS FindingsGroup ,
                    'Collation for ' + name
                    + ' different than tempdb collation' AS Finding ,
                    'http://BrentOzar.com/go/collate' AS URL ,
                    'Collation differences between user databases and tempdb can cause conflicts especially when comparing string values' AS Details
            FROM    sys.databases
            WHERE   name NOT IN ( 'master', 'model', 'msdb' )
                    AND collation_name <> ( SELECT  collation_name
                                            FROM    sys.databases
                                            WHERE   name = 'tempdb'
                                          )

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  77 AS CheckId ,
                    50 AS Priority ,
                    'Reliability' AS FindingsGroup ,
                    'Database Snapshot Online' AS Finding ,
                    'http://BrentOzar.com/go/snapshot' AS URL ,
                    'Database [' + dSnap.[name] + '] is a snapshot of ['
                    + dOriginal.[name]
                    + ']. Make sure you have enough drive space to maintain the snapshot as the original database grows.' AS Details
            FROM    sys.databases dSnap
                    INNER JOIN sys.databases dOriginal ON dSnap.source_database_id = dOriginal.database_id

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  79 AS CheckId ,
                    100 AS Priority ,
                    'Performance' AS FindingsGroup ,
                    'Shrink Database Job' AS Finding ,
                    'http://BrentOzar.com/go/autoshrink' AS URL ,
                    'In the [' + j.[name] + '] job, step [' + step.[step_name]
                    + '] has SHRINKDATABASE or SHRINKFILE, which may be causing database fragmentation.' AS Details
            FROM    msdb.dbo.sysjobs j
                    INNER JOIN msdb.dbo.sysjobsteps step ON j.job_id = step.job_id
            WHERE   step.command LIKE N'%SHRINKDATABASE%'
                    OR step.command LIKE N'%SHRINKFILE%'

    EXEC dbo.sp_MSforeachdb 'USE [?]; INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details) SELECT DISTINCT 80, 50, ''Reliability'', ''Max File Size Set'', ''http://BrentOzar.com/go/maxsize'', (''The ['' + DB_NAME() + ''] database file '' + name + '' has a max file size set to '' + CAST(CAST(max_size AS BIGINT) * 8 / 1024 AS VARCHAR(100)) + ''MB. If it runs out of space, the database will stop working even though there may be drive space available.'') FROM sys.database_files WHERE max_size <> 268435456 AND max_size <> -1';

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  81 AS CheckID ,
                    200 AS Priority ,
                    'Non-Active Server Config' AS FindingsGroup ,
                    cr.name AS Finding ,
                    'http://www.BrentOzar.com/blitz/sp_configure/' AS URL ,
                    ( 'This sp_configure option isn''t running under its set value.  Its set value is '
                      + CAST(cr.[Value] AS VARCHAR(100))
                      + ' and its running value is '
                      + CAST(cr.value_in_use AS VARCHAR(100))
                      + '. When someone does a RECONFIGURE or restarts the instance, this setting will start taking effect.' ) AS Details
            FROM    sys.configurations cr
            WHERE   cr.value <> cr.value_in_use;


    IF EXISTS ( SELECT  *
                FROM    sys.all_objects
                WHERE   name = 'dm_server_services' ) 
        SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        SELECT  83 AS CheckID ,
                250 AS Priority ,
                ''Server Info'' AS FindingsGroup ,
                ''Services'' AS Finding ,
                '''' AS URL ,
                N''Service: '' + servicename + N'' runs under service account '' + service_account + N''. Last startup time: '' + COALESCE(CAST(CAST(last_startup_time AS DATETIME) AS VARCHAR(50)), ''not shown.'') + ''. Startup type: '' + startup_type_desc + N'', currently '' + status_desc + ''.'' 
                FROM sys.dm_server_services;'
    EXECUTE(@StringToExecute);


/* Check 84 - SQL Server 2012 */
    IF EXISTS ( SELECT  *
                FROM    sys.all_objects o
                        INNER JOIN sys.all_columns c ON o.object_id = c.object_id
                WHERE   o.name = 'dm_os_sys_info'
                        AND c.name = 'physical_memory_kb' ) 
        BEGIN
            SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        SELECT  84 AS CheckID ,
                250 AS Priority ,
                ''Server Info'' AS FindingsGroup ,
                ''Hardware'' AS Finding ,
                '''' AS URL ,
                ''Logical processors: '' + CAST(cpu_count AS VARCHAR(50)) + ''. Physical memory: '' + CAST( CAST(ROUND((physical_memory_kb / 1024.0 / 1024), 1) AS INT) AS VARCHAR(50)) + ''GB.''
		FROM sys.dm_os_sys_info';
            EXECUTE(@StringToExecute);
        END

/* Check 84 - SQL Server 2008 */
    IF EXISTS ( SELECT  *
                FROM    sys.all_objects o
                        INNER JOIN sys.all_columns c ON o.object_id = c.object_id
                WHERE   o.name = 'dm_os_sys_info'
                        AND c.name = 'physical_memory_in_bytes' ) 
        BEGIN
            SET @StringToExecute = 'INSERT INTO #BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        SELECT  84 AS CheckID ,
                250 AS Priority ,
                ''Server Info'' AS FindingsGroup ,
                ''Hardware'' AS Finding ,
                '''' AS URL ,
                ''Logical processors: '' + CAST(cpu_count AS VARCHAR(50)) + ''. Physical memory: '' + CAST( CAST(ROUND((physical_memory_in_bytes / 1024.0 / 1024 / 1024), 1) AS INT) AS VARCHAR(50)) + ''GB.''
		FROM sys.dm_os_sys_info';
            EXECUTE(@StringToExecute);
        END


    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
            SELECT  85 AS CheckID ,
                    250 AS Priority ,
                    'Server Info' AS FindingsGroup ,
                    'SQL Server Service' AS Finding ,
                    '' AS URL ,
                    N'Version: '
                    + CAST(SERVERPROPERTY('productversion') AS NVARCHAR(100))
                    + N'. Patch Level: '
                    + CAST(SERVERPROPERTY('productlevel') AS NVARCHAR(100))
                    + N'. Edition: '
                    + CAST(SERVERPROPERTY('edition') AS VARCHAR(100))
                    + N'. AlwaysOn Enabled: '
                    + CAST(COALESCE(SERVERPROPERTY('IsHadrEnabled'), 0) AS VARCHAR(100))
                    + N'. AlwaysOn Mgr Status: '
                    + CAST(COALESCE(SERVERPROPERTY('HadrManagerStatus'), 0) AS VARCHAR(100))
	

    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
            )
    VALUES  ( -1 ,
              255 ,
              'Thanks!' ,
              'From Brent Ozar Unlimited' ,
              'http://www.BrentOzar.com/blitz/' ,
              'Thanks from the Brent Ozar Unlimited team.  We hope you found this tool useful, and if you need help relieving your SQL Server pains, email us at Help@BrentOzar.com.'
            );

    SET @Version = 16;
    INSERT  INTO #BlitzResults
            ( CheckID ,
              Priority ,
              FindingsGroup ,
              Finding ,
              URL ,
              Details
		            
            )
    VALUES  ( -1 ,
              0 ,
              'sp_Blitz v16 Dec 13 2012' ,
              'From Brent Ozar Unlimited' ,
              'http://www.BrentOzar.com/blitz/' ,
              'Thanks from the Brent Ozar Unlimited team.  We hope you found this tool useful, and if you need help relieving your SQL Server pains, email us at Help@BrentOzar.com.'
		            
            );



    IF @OutputType = 'COUNT' 
        BEGIN
            SELECT  COUNT(*) AS Warnings
            FROM    #BlitzResults
        END
    ELSE 
        BEGIN
            SELECT  [Priority] ,
                    [FindingsGroup] ,
                    [Finding] ,
                    [URL] ,
                    [Details] ,
                    [QueryPlan] ,
                    [QueryPlanFiltered] ,
                    CheckID
            FROM    #BlitzResults
            ORDER BY Priority ,
                    FindingsGroup ,
                    Finding ,
                    Details;
        END
  
    DROP TABLE #BlitzResults;


    IF @OutputProcedureCache = 1 
        SELECT TOP 20
                total_worker_time / execution_count AS AvgCPU ,
                total_worker_time AS TotalCPU ,
                CAST(ROUND(100.00 * total_worker_time
                           / ( SELECT   SUM(total_worker_time)
                               FROM     sys.dm_exec_query_stats
                             ), 2) AS MONEY) AS PercentCPU ,
                total_elapsed_time / execution_count AS AvgDuration ,
                total_elapsed_time AS TotalDuration ,
                CAST(ROUND(100.00 * total_elapsed_time
                           / ( SELECT   SUM(total_elapsed_time)
                               FROM     sys.dm_exec_query_stats
                             ), 2) AS MONEY) AS PercentDuration ,
                total_logical_reads / execution_count AS AvgReads ,
                total_logical_reads AS TotalReads ,
                CAST(ROUND(100.00 * total_logical_reads
                           / ( SELECT   SUM(total_logical_reads)
                               FROM     sys.dm_exec_query_stats
                             ), 2) AS MONEY) AS PercentReads ,
                execution_count ,
                CAST(ROUND(100.00 * execution_count
                           / ( SELECT   SUM(execution_count)
                               FROM     sys.dm_exec_query_stats
                             ), 2) AS MONEY) AS PercentExecutions ,
                CASE WHEN DATEDIFF(mi, creation_time, qs.last_execution_time) = 0
                     THEN 0
                     ELSE CAST(( 1.00 * execution_count / DATEDIFF(mi,
                                                              creation_time,
                                                              qs.last_execution_time) ) AS MONEY)
                END AS executions_per_minute ,
                qs.creation_time AS plan_creation_time ,
                qs.last_execution_time ,
                text ,
                text_filtered ,
                query_plan ,
                query_plan_filtered ,
                sql_handle ,
                query_hash ,
                plan_handle ,
                query_plan_hash
        FROM    #dm_exec_query_stats qs
        ORDER BY CASE UPPER(@CheckProcedureCacheFilter)
                   WHEN 'CPU' THEN total_worker_time
                   WHEN 'READS' THEN total_logical_reads
                   WHEN 'EXECCOUNT' THEN execution_count
                   WHEN 'DURATION' THEN total_elapsed_time
                   ELSE total_worker_time
                 END DESC
    SET NOCOUNT OFF;
GO

/*
Sample execution call with the most common parameters:
EXEC [dbo].[sp_Blitz]
    @CheckUserDatabaseObjects = 1 ,
    @CheckProcedureCache = 1 ,
    @OutputType = 'TABLE' ,
    @OutputProcedureCache = 0 ,
    @CheckProcedureCacheFilter = NULL,
	@CheckServerInfo = 0

*/

use master
if exists(select * from master.sys.objects where name = 'sp_blocked')
drop procedure sp_blocked
go
create procedure dbo.sp_blocked
@spid int
as
create table #Blocked
(spid int)
insert into #Blocked
(spid)
values
(@spid)

while @@ROWCOUNT <> 0
BEGIN
insert into #Blocked
(spid)
select spid 
from master.sys.sysprocesses 
where blocked in (select spid from #Blocked)
and spid not in (select spid from #Blocked)
END

delete from #Blocked
where spid = @spid

delete from #Blocked
where spid is null

if exists(select * from #Blocked)
BEGIN
select *
from master.sys.sysprocesses
where spid in (select spid from #blocked)
END
else
BEGIN
select 'No Processes are being blocked by spid ' + convert(varchar(20), @spid) + '.' as 'System Message'
END

drop table #Blocked
go
print 'sp_blocked created.'

USE master
print 'Creating sp_who3'

if exists (select * from sys.objects where name = 'sp_who3')
drop procedure [dbo].[sp_who3]
GO
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

CREATE procedure sp_who3
@spid sysname = null
as

/*
Date Creator Action
2007.02.15 mrdenny Birth
2007.05.18 mrdenny Correct Full Query Text
2007.10.08 mrdenny Added Waiting Statement to Full Query RecordSet
*/

DECLARE @spid_i INT
DECLARE @spid_only bit
SET NOCOUNT ON
if @spid is null
BEGIN
exec sp_who2
END
ELSE
BEGIN
set @spid_only = 1
if lower(cast(@spid as varchar(10))) = 'active'
BEGIN
set @spid_only = 0
exec sp_who2 'active'
END
if lower(cast(@spid as varchar(10))) = 'blocked' or (isnumeric(@spid) = 1 and @spid < 0)
BEGIN
DECLARE @blocked TABLE
(spid int,
blocked int)

INSERT INTO @blocked
select spid, blocked
from sys.sysprocesses
where blocked <> 0

insert into @blocked
select spid, blocked
from sys.sysprocesses
where spid in (select blocked from @blocked)

set @spid_only = 0
select sys.sysprocesses.spid as 'SPID', 
sys.sysprocesses.status, 
sys.sysprocesses.loginame as 'Login',
sys.sysprocesses.hostname as 'HostName',
sys.sysprocesses.blocked as 'BlkBy',
sys.databases.name as 'DBName',
sys.sysprocesses.cmd as 'Command',
sys.sysprocesses.cpu as 'CPUTime',
sys.sysprocesses.physical_io as 'DiskIO',
sys.sysprocesses.last_batch as 'LastBatch',
sys.sysprocesses.program_name as 'ProgramName',
sys.sysprocesses.spid as 'SPID'
from sys.sysprocesses
left outer join sys.databases on sys.sysprocesses.dbid = sys.databases.database_id
where spid in (select spid from @blocked)
END

if @spid_only = 1
BEGIN
DECLARE @sql_handle varbinary(64)
DECLARE @stmt_start int
DECLARE @stmt_end int

set @spid_i = @spid

SELECT @sql_handle = sql_handle,
    @stmt_start = stmt_start,
    @stmt_end = stmt_end
from sys.sysprocesses
where spid = @spid_i

exec sp_who @spid_i
exec sp_who2 @spid_i
dbcc inputbuffer (@spid_i)
/*Start Get Output Buffer*/
select text as 'Full Query', 
    case when @stmt_start < 0 then 
        substring(text, @stmt_start/2, (@stmt_end/2)-(@stmt_start/2)) 
    else 
        null 
    end as 'Current Command'
from sys.dm_exec_sql_text(@sql_handle)
/*End Get Output Buffer*/
select * from master.sys.sysprocesses where spid = @spid_i
exec sp_blocked @spid_i
exec sp_lock @spid_i
END
END
go

USE master
GO

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'sp_WhoIsActive')
	EXEC ('CREATE PROC dbo.sp_WhoIsActive AS SELECT ''stub version, to be replaced''')
GO

/*********************************************************************************************
Who Is Active? v11.00 (2011-04-27)
(C) 2007-2011, Adam Machanic

Feedback: mailto:amachanic@gmail.com
Updates: http://sqlblog.com/blogs/adam_machanic/archive/tags/who+is+active/default.aspx
"Beta" Builds: http://sqlblog.com/files/folders/beta/tags/who+is+active/default.aspx

Donate! Support this project: http://tinyurl.com/WhoIsActiveDonate

License: 
	Who is Active? is free to download and use for personal, educational, and internal 
	corporate purposes, provided that this header is preserved. Redistribution or sale 
	of Who is Active?, in whole or in part, is prohibited without the author's express 
	written consent.
*********************************************************************************************/
ALTER PROC dbo.sp_WhoIsActive
(
--~
	--Filters--Both inclusive and exclusive
	--Set either filter to '' to disable
	--Valid filter types are: session, program, database, login, and host
	--Session is a session ID, and either 0 or '' can be used to indicate "all" sessions
	--All other filter types support % or _ as wildcards
	@filter sysname = '',
	@filter_type VARCHAR(10) = 'session',
	@not_filter sysname = '',
	@not_filter_type VARCHAR(10) = 'session',

	--Retrieve data about the calling session?
	@show_own_spid BIT = 0,

	--Retrieve data about system sessions?
	@show_system_spids BIT = 0,

	--Controls how sleeping SPIDs are handled, based on the idea of levels of interest
	--0 does not pull any sleeping SPIDs
	--1 pulls only those sleeping SPIDs that also have an open transaction
	--2 pulls all sleeping SPIDs
	@show_sleeping_spids TINYINT = 1,

	--If 1, gets the full stored procedure or running batch, when available
	--If 0, gets only the actual statement that is currently running in the batch or procedure
	@get_full_inner_text BIT = 0,

	--Get associated query plans for running tasks, if available
	--If @get_plans = 1, gets the plan based on the request's statement offset
	--If @get_plans = 2, gets the entire plan based on the request's plan_handle
	@get_plans TINYINT = 0,

	--Get the associated outer ad hoc query or stored procedure call, if available
	@get_outer_command BIT = 0,

	--Enables pulling transaction log write info and transaction duration
	@get_transaction_info BIT = 0,

	--Get information on active tasks, based on three interest levels
	--Level 0 does not pull any task-related information
	--Level 1 is a lightweight mode that pulls the top non-CXPACKET wait, giving preference to blockers
	--Level 2 pulls all available task-based metrics, including: 
	--number of active tasks, current wait stats, physical I/O, context switches, and blocker information
	@get_task_info TINYINT = 1,

	--Gets associated locks for each request, aggregated in an XML format
	@get_locks BIT = 0,

	--Get average time for past runs of an active query
	--(based on the combination of plan handle, sql handle, and offset)
	@get_avg_time BIT = 0,

	--Get additional non-performance-related information about the session or request
	--text_size, language, date_format, date_first, quoted_identifier, arithabort, ansi_null_dflt_on, 
	--ansi_defaults, ansi_warnings, ansi_padding, ansi_nulls, concat_null_yields_null, 
	--transaction_isolation_level, lock_timeout, deadlock_priority, row_count, command_type
	--
	--If a SQL Agent job is running, an subnode called agent_info will be populated with some or all of
	--the following: job_id, job_name, step_id, step_name, msdb_query_error (in the event of an error)
	--
	--If @get_task_info is set to 2 and a lock wait is detected, a subnode called block_info will be
	--populated with some or all of the following: lock_type, database_name, object_id, file_id, hobt_id, 
	--applock_hash, metadata_resource, metadata_class_id, object_name, schema_name
	@get_additional_info BIT = 0,

	--Walk the blocking chain and count the number of 
	--total SPIDs blocked all the way down by a given session
	--Also enables task_info Level 1, if @get_task_info is set to 0
	@find_block_leaders BIT = 0,

	--Pull deltas on various metrics
	--Interval in seconds to wait before doing the second data pull
	@delta_interval TINYINT = 0,

	--List of desired output columns, in desired order
	--Note that the final output will be the intersection of all enabled features and all 
	--columns in the list. Therefore, only columns associated with enabled features will 
	--actually appear in the output. Likewise, removing columns from this list may effectively
	--disable features, even if they are turned on
	--
	--Each element in this list must be one of the valid output column names. Names must be
	--delimited by square brackets. White space, formatting, and additional characters are
	--allowed, as long as the list contains exact matches of delimited valid column names.
	@output_column_list VARCHAR(8000) = '[dd%][session_id][sql_text][sql_command][login_name][wait_info][tasks][tran_log%][cpu%][temp%][block%][reads%][writes%][context%][physical%][query_plan][locks][%]',

	--Column(s) by which to sort output, optionally with sort directions. 
		--Valid column choices:
		--session_id, physical_io, reads, physical_reads, writes, tempdb_allocations,
		--tempdb_current, CPU, context_switches, used_memory, physical_io_delta, 
		--reads_delta, physical_reads_delta, writes_delta, tempdb_allocations_delta, 
		--tempdb_current_delta, CPU_delta, context_switches_delta, used_memory_delta, 
		--tasks, tran_start_time, open_tran_count, blocking_session_id, blocked_session_count,
		--percent_complete, host_name, login_name, database_name, start_time, login_time
		--
		--Note that column names in the list must be bracket-delimited. Commas and/or white
		--space are not required. 
	@sort_order VARCHAR(500) = '[start_time] ASC',

	--Formats some of the output columns in a more "human readable" form
	--0 disables outfput format
	--1 formats the output for variable-width fonts
	--2 formats the output for fixed-width fonts
	@format_output TINYINT = 1,

	--If set to a non-blank value, the script will attempt to insert into the specified 
	--destination table. Please note that the script will not verify that the table exists, 
	--or that it has the correct schema, before doing the insert.
	--Table can be specified in one, two, or three-part format
	@destination_table VARCHAR(4000) = '',

	--If set to 1, no data collection will happen and no result set will be returned; instead,
	--a CREATE TABLE statement will be returned via the @schema parameter, which will match 
	--the schema of the result set that would be returned by using the same collection of the
	--rest of the parameters. The CREATE TABLE statement will have a placeholder token of 
	--<table_name> in place of an actual table name.
	@return_schema BIT = 0,
	@schema VARCHAR(MAX) = NULL OUTPUT,

	--Help! What do I do?
	@help BIT = 0
--~
)
/*
OUTPUT COLUMNS
--------------
Formatted/Non:	[session_id] [smallint] NOT NULL
	Session ID (a.k.a. SPID)

Formatted:		[dd hh:mm:ss.mss] [varchar](15) NULL
Non-Formatted:	<not returned>
	For an active request, time the query has been running
	For a sleeping session, time since the last batch completed

Formatted:		[dd hh:mm:ss.mss (avg)] [varchar](15) NULL
Non-Formatted:	[avg_elapsed_time] [int] NULL
	(Requires @get_avg_time option)
	How much time has the active portion of the query taken in the past, on average?

Formatted:		[physical_io] [varchar](30) NULL
Non-Formatted:	[physical_io] [bigint] NULL
	Shows the number of physical I/Os, for active requests

Formatted:		[reads] [varchar](30) NULL
Non-Formatted:	[reads] [bigint] NULL
	For an active request, number of reads done for the current query
	For a sleeping session, total number of reads done over the lifetime of the session

Formatted:		[physical_reads] [varchar](30) NULL
Non-Formatted:	[physical_reads] [bigint] NULL
	For an active request, number of physical reads done for the current query
	For a sleeping session, total number of physical reads done over the lifetime of the session

Formatted:		[writes] [varchar](30) NULL
Non-Formatted:	[writes] [bigint] NULL
	For an active request, number of writes done for the current query
	For a sleeping session, total number of writes done over the lifetime of the session

Formatted:		[tempdb_allocations] [varchar](30) NULL
Non-Formatted:	[tempdb_allocations] [bigint] NULL
	For an active request, number of TempDB writes done for the current query
	For a sleeping session, total number of TempDB writes done over the lifetime of the session

Formatted:		[tempdb_current] [varchar](30) NULL
Non-Formatted:	[tempdb_current] [bigint] NULL
	For an active request, number of TempDB pages currently allocated for the query
	For a sleeping session, number of TempDB pages currently allocated for the session

Formatted:		[CPU] [varchar](30) NULL
Non-Formatted:	[CPU] [int] NULL
	For an active request, total CPU time consumed by the current query
	For a sleeping session, total CPU time consumed over the lifetime of the session

Formatted:		[context_switches] [varchar](30) NULL
Non-Formatted:	[context_switches] [bigint] NULL
	Shows the number of context switches, for active requests

Formatted:		[used_memory] [varchar](30) NOT NULL
Non-Formatted:	[used_memory] [bigint] NOT NULL
	For an active request, total memory consumption for the current query
	For a sleeping session, total current memory consumption

Formatted:		[physical_io_delta] [varchar](30) NULL
Non-Formatted:	[physical_io_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of physical I/Os reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[reads_delta] [varchar](30) NULL
Non-Formatted:	[reads_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of reads reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[physical_reads_delta] [varchar](30) NULL
Non-Formatted:	[physical_reads_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of physical reads reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[writes_delta] [varchar](30) NULL
Non-Formatted:	[writes_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of writes reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[tempdb_allocations_delta] [varchar](30) NULL
Non-Formatted:	[tempdb_allocations_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of TempDB writes reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[tempdb_current_delta] [varchar](30) NULL
Non-Formatted:	[tempdb_current_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the number of allocated TempDB pages reported on the first and second 
	collections. If the request started after the first collection, the value will be NULL

Formatted:		[CPU_delta] [varchar](30) NULL
Non-Formatted:	[CPU_delta] [int] NULL
	(Requires @delta_interval option)
	Difference between the CPU time reported on the first and second collections. 
	If the request started after the first collection, the value will be NULL

Formatted:		[context_switches_delta] [varchar](30) NULL
Non-Formatted:	[context_switches_delta] [bigint] NULL
	(Requires @delta_interval option)
	Difference between the context switches count reported on the first and second collections
	If the request started after the first collection, the value will be NULL

Formatted:		[used_memory_delta] [varchar](30) NULL
Non-Formatted:	[used_memory_delta] [bigint] NULL
	Difference between the memory usage reported on the first and second collections
	If the request started after the first collection, the value will be NULL

Formatted:		[tasks] [varchar](30) NULL
Non-Formatted:	[tasks] [smallint] NULL
	Number of worker tasks currently allocated, for active requests

Formatted/Non:	[status] [varchar](30) NOT NULL
	Activity status for the session (running, sleeping, etc)

Formatted/Non:	[wait_info] [nvarchar](4000) NULL
	Aggregates wait information, in the following format:
		(Ax: Bms/Cms/Dms)E
	A is the number of waiting tasks currently waiting on resource type E. B/C/D are wait
	times, in milliseconds. If only one thread is waiting, its wait time will be shown as B.
	If two tasks are waiting, each of their wait times will be shown (B/C). If three or more 
	tasks are waiting, the minimum, average, and maximum wait times will be shown (B/C/D).
	If wait type E is a page latch wait and the page is of a "special" type (e.g. PFS, GAM, SGAM), 
	the page type will be identified.
	If wait type E is CXPACKET, the nodeId from the query plan will be identified

Formatted/Non:	[locks] [xml] NULL
	(Requires @get_locks option)
	Aggregates lock information, in XML format.
	The lock XML includes the lock mode, locked object, and aggregates the number of requests. 
	Attempts are made to identify locked objects by name

Formatted/Non:	[tran_start_time] [datetime] NULL
	(Requires @get_transaction_info option)
	Date and time that the first transaction opened by a session caused a transaction log 
	write to occur.

Formatted/Non:	[tran_log_writes] [nvarchar](4000) NULL
	(Requires @get_transaction_info option)
	Aggregates transaction log write information, in the following format:
	A:wB (C kB)
	A is a database that has been touched by an active transaction
	B is the number of log writes that have been made in the database as a result of the transaction
	C is the number of log kilobytes consumed by the log records

Formatted:		[open_tran_count] [varchar](30) NULL
Non-Formatted:	[open_tran_count] [smallint] NULL
	Shows the number of open transactions the session has open

Formatted:		[sql_command] [xml] NULL
Non-Formatted:	[sql_command] [nvarchar](max) NULL
	(Requires @get_outer_command option)
	Shows the "outer" SQL command, i.e. the text of the batch or RPC sent to the server, 
	if available

Formatted:		[sql_text] [xml] NULL
Non-Formatted:	[sql_text] [nvarchar](max) NULL
	Shows the SQL text for active requests or the last statement executed
	for sleeping sessions, if available in either case.
	If @get_full_inner_text option is set, shows the full text of the batch.
	Otherwise, shows only the active statement within the batch.
	If the query text is locked, a special timeout message will be sent, in the following format:
		<timeout_exceeded />
	If an error occurs, an error message will be sent, in the following format:
		<error message="message" />

Formatted/Non:	[query_plan] [xml] NULL
	(Requires @get_plans option)
	Shows the query plan for the request, if available.
	If the plan is locked, a special timeout message will be sent, in the following format:
		<timeout_exceeded />
	If an error occurs, an error message will be sent, in the following format:
		<error message="message" />

Formatted/Non:	[blocking_session_id] [smallint] NULL
	When applicable, shows the blocking SPID

Formatted:		[blocked_session_count] [varchar](30) NULL
Non-Formatted:	[blocked_session_count] [smallint] NULL
	(Requires @find_block_leaders option)
	The total number of SPIDs blocked by this session,
	all the way down the blocking chain.

Formatted:		[percent_complete] [varchar](30) NULL
Non-Formatted:	[percent_complete] [real] NULL
	When applicable, shows the percent complete (e.g. for backups, restores, and some rollbacks)

Formatted/Non:	[host_name] [sysname] NOT NULL
	Shows the host name for the connection

Formatted/Non:	[login_name] [sysname] NOT NULL
	Shows the login name for the connection

Formatted/Non:	[database_name] [sysname] NULL
	Shows the connected database

Formatted/Non:	[program_name] [sysname] NULL
	Shows the reported program/application name

Formatted/Non:	[additional_info] [xml] NULL
	(Requires @get_additional_info option)
	Returns additional non-performance-related session/request information
	If the script finds a SQL Agent job running, the name of the job and job step will be reported
	If @get_task_info = 2 and the script finds a lock wait, the locked object will be reported

Formatted/Non:	[start_time] [datetime] NOT NULL
	For active requests, shows the time the request started
	For sleeping sessions, shows the time the last batch completed

Formatted/Non:	[login_time] [datetime] NOT NULL
	Shows the time that the session connected

Formatted/Non:	[request_id] [int] NULL
	For active requests, shows the request_id
	Should be 0 unless MARS is being used

Formatted/Non:	[collection_time] [datetime] NOT NULL
	Time that this script's final SELECT ran
*/
AS
BEGIN;
	SET NOCOUNT ON; 
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET QUOTED_IDENTIFIER ON;
	SET ANSI_PADDING ON;
	SET CONCAT_NULL_YIELDS_NULL ON;
	SET ANSI_WARNINGS ON;
	SET NUMERIC_ROUNDABORT OFF;
	SET ARITHABORT ON;

	IF
		@filter IS NULL
		OR @filter_type IS NULL
		OR @not_filter IS NULL
		OR @not_filter_type IS NULL
		OR @show_own_spid IS NULL
		OR @show_system_spids IS NULL
		OR @show_sleeping_spids IS NULL
		OR @get_full_inner_text IS NULL
		OR @get_plans IS NULL
		OR @get_outer_command IS NULL
		OR @get_transaction_info IS NULL
		OR @get_task_info IS NULL
		OR @get_locks IS NULL
		OR @get_avg_time IS NULL
		OR @get_additional_info IS NULL
		OR @find_block_leaders IS NULL
		OR @delta_interval IS NULL
		OR @format_output IS NULL
		OR @output_column_list IS NULL
		OR @sort_order IS NULL
		OR @return_schema IS NULL
		OR @destination_table IS NULL
		OR @help IS NULL
	BEGIN;
		RAISERROR('Input parameters cannot be NULL', 16, 1);
		RETURN;
	END;
	
	IF @filter_type NOT IN ('session', 'program', 'database', 'login', 'host')
	BEGIN;
		RAISERROR('Valid filter types are: session, program, database, login, host', 16, 1);
		RETURN;
	END;
	
	IF @filter_type = 'session' AND @filter LIKE '%[^0123456789]%'
	BEGIN;
		RAISERROR('Session filters must be valid integers', 16, 1);
		RETURN;
	END;
	
	IF @not_filter_type NOT IN ('session', 'program', 'database', 'login', 'host')
	BEGIN;
		RAISERROR('Valid filter types are: session, program, database, login, host', 16, 1);
		RETURN;
	END;
	
	IF @not_filter_type = 'session' AND @not_filter LIKE '%[^0123456789]%'
	BEGIN;
		RAISERROR('Session filters must be valid integers', 16, 1);
		RETURN;
	END;
	
	IF @show_sleeping_spids NOT IN (0, 1, 2)
	BEGIN;
		RAISERROR('Valid values for @show_sleeping_spids are: 0, 1, or 2', 16, 1);
		RETURN;
	END;
	
	IF @get_plans NOT IN (0, 1, 2)
	BEGIN;
		RAISERROR('Valid values for @get_plans are: 0, 1, or 2', 16, 1);
		RETURN;
	END;

	IF @get_task_info NOT IN (0, 1, 2)
	BEGIN;
		RAISERROR('Valid values for @get_task_info are: 0, 1, or 2', 16, 1);
		RETURN;
	END;

	IF @format_output NOT IN (0, 1, 2)
	BEGIN;
		RAISERROR('Valid values for @format_output are: 0, 1, or 2', 16, 1);
		RETURN;
	END;
	
	IF @help = 1
	BEGIN;
		DECLARE 
			@header VARCHAR(MAX),
			@params VARCHAR(MAX),
			@outputs VARCHAR(MAX);

		SELECT 
			@header =
				REPLACE
				(
					REPLACE
					(
						CONVERT
						(
							VARCHAR(MAX),
							SUBSTRING
							(
								t.text, 
								CHARINDEX('/' + REPLICATE('*', 93), t.text) + 94,
								CHARINDEX(REPLICATE('*', 93) + '/', t.text) - (CHARINDEX('/' + REPLICATE('*', 93), t.text) + 94)
							)
						),
						CHAR(13)+CHAR(10),
						CHAR(13)
					),
					'	',
					''
				),
			@params =
				CHAR(13) +
					REPLACE
					(
						REPLACE
						(
							CONVERT
							(
								VARCHAR(MAX),
								SUBSTRING
								(
									t.text, 
									CHARINDEX('--~', t.text) + 5, 
									CHARINDEX('--~', t.text, CHARINDEX('--~', t.text) + 5) - (CHARINDEX('--~', t.text) + 5)
								)
							),
							CHAR(13)+CHAR(10),
							CHAR(13)
						),
						'	',
						''
					),
				@outputs = 
					CHAR(13) +
						REPLACE
						(
							REPLACE
							(
								REPLACE
								(
									CONVERT
									(
										VARCHAR(MAX),
										SUBSTRING
										(
											t.text, 
											CHARINDEX('OUTPUT COLUMNS'+CHAR(13)+CHAR(10)+'--------------', t.text) + 32,
											CHARINDEX('*/', t.text, CHARINDEX('OUTPUT COLUMNS'+CHAR(13)+CHAR(10)+'--------------', t.text) + 32) - (CHARINDEX('OUTPUT COLUMNS'+CHAR(13)+CHAR(10)+'--------------', t.text) + 32)
										)
									),
									CHAR(9),
									CHAR(255)
								),
								CHAR(13)+CHAR(10),
								CHAR(13)
							),
							'	',
							''
						) +
						CHAR(13)
			FROM sys.dm_exec_requests AS r
			CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
			WHERE
				r.session_id = @@SPID;

		WITH
		a0 AS
		(SELECT 1 AS n UNION ALL SELECT 1),
		a1 AS
		(SELECT 1 AS n FROM a0 AS a, a0 AS b),
		a2 AS
		(SELECT 1 AS n FROM a1 AS a, a1 AS b),
		a3 AS
		(SELECT 1 AS n FROM a2 AS a, a2 AS b),
		a4 AS
		(SELECT 1 AS n FROM a3 AS a, a3 AS b),
		numbers AS
		(
			SELECT TOP(LEN(@header) - 1)
				ROW_NUMBER() OVER
				(
					ORDER BY (SELECT NULL)
				) AS number
			FROM a4
			ORDER BY
				number
		)
		SELECT
			RTRIM(LTRIM(
				SUBSTRING
				(
					@header,
					number + 1,
					CHARINDEX(CHAR(13), @header, number + 1) - number - 1
				)
			)) AS [------header---------------------------------------------------------------------------------------------------------------]
		FROM numbers
		WHERE
			SUBSTRING(@header, number, 1) = CHAR(13);

		WITH
		a0 AS
		(SELECT 1 AS n UNION ALL SELECT 1),
		a1 AS
		(SELECT 1 AS n FROM a0 AS a, a0 AS b),
		a2 AS
		(SELECT 1 AS n FROM a1 AS a, a1 AS b),
		a3 AS
		(SELECT 1 AS n FROM a2 AS a, a2 AS b),
		a4 AS
		(SELECT 1 AS n FROM a3 AS a, a3 AS b),
		numbers AS
		(
			SELECT TOP(LEN(@params) - 1)
				ROW_NUMBER() OVER
				(
					ORDER BY (SELECT NULL)
				) AS number
			FROM a4
			ORDER BY
				number
		),
		tokens AS
		(
			SELECT 
				RTRIM(LTRIM(
					SUBSTRING
					(
						@params,
						number + 1,
						CHARINDEX(CHAR(13), @params, number + 1) - number - 1
					)
				)) AS token,
				number,
				CASE
					WHEN SUBSTRING(@params, number + 1, 1) = CHAR(13) THEN number
					ELSE COALESCE(NULLIF(CHARINDEX(',' + CHAR(13) + CHAR(13), @params, number), 0), LEN(@params)) 
				END AS param_group,
				ROW_NUMBER() OVER
				(
					PARTITION BY
						CHARINDEX(',' + CHAR(13) + CHAR(13), @params, number),
						SUBSTRING(@params, number+1, 1)
					ORDER BY 
						number
				) AS group_order
			FROM numbers
			WHERE
				SUBSTRING(@params, number, 1) = CHAR(13)
		),
		parsed_tokens AS
		(
			SELECT
				MIN
				(
					CASE
						WHEN token LIKE '@%' THEN token
						ELSE NULL
					END
				) AS parameter,
				MIN
				(
					CASE
						WHEN token LIKE '--%' THEN RIGHT(token, LEN(token) - 2)
						ELSE NULL
					END
				) AS description,
				param_group,
				group_order
			FROM tokens
			WHERE
				NOT 
				(
					token = '' 
					AND group_order > 1
				)
			GROUP BY
				param_group,
				group_order
		)
		SELECT
			CASE
				WHEN description IS NULL AND parameter IS NULL THEN '-------------------------------------------------------------------------'
				WHEN param_group = MAX(param_group) OVER() THEN parameter
				ELSE COALESCE(LEFT(parameter, LEN(parameter) - 1), '')
			END AS [------parameter----------------------------------------------------------],
			CASE
				WHEN description IS NULL AND parameter IS NULL THEN '----------------------------------------------------------------------------------------------------------------------'
				ELSE COALESCE(description, '')
			END AS [------description-----------------------------------------------------------------------------------------------------]
		FROM parsed_tokens
		ORDER BY
			param_group, 
			group_order;
		
		WITH
		a0 AS
		(SELECT 1 AS n UNION ALL SELECT 1),
		a1 AS
		(SELECT 1 AS n FROM a0 AS a, a0 AS b),
		a2 AS
		(SELECT 1 AS n FROM a1 AS a, a1 AS b),
		a3 AS
		(SELECT 1 AS n FROM a2 AS a, a2 AS b),
		a4 AS
		(SELECT 1 AS n FROM a3 AS a, a3 AS b),
		numbers AS
		(
			SELECT TOP(LEN(@outputs) - 1)
				ROW_NUMBER() OVER
				(
					ORDER BY (SELECT NULL)
				) AS number
			FROM a4
			ORDER BY
				number
		),
		tokens AS
		(
			SELECT 
				RTRIM(LTRIM(
					SUBSTRING
					(
						@outputs,
						number + 1,
						CASE
							WHEN 
								COALESCE(NULLIF(CHARINDEX(CHAR(13) + 'Formatted', @outputs, number + 1), 0), LEN(@outputs)) < 
								COALESCE(NULLIF(CHARINDEX(CHAR(13) + CHAR(255) COLLATE Latin1_General_Bin2, @outputs, number + 1), 0), LEN(@outputs))
								THEN COALESCE(NULLIF(CHARINDEX(CHAR(13) + 'Formatted', @outputs, number + 1), 0), LEN(@outputs)) - number - 1
							ELSE
								COALESCE(NULLIF(CHARINDEX(CHAR(13) + CHAR(255) COLLATE Latin1_General_Bin2, @outputs, number + 1), 0), LEN(@outputs)) - number - 1
						END
					)
				)) AS token,
				number,
				COALESCE(NULLIF(CHARINDEX(CHAR(13) + 'Formatted', @outputs, number + 1), 0), LEN(@outputs)) AS output_group,
				ROW_NUMBER() OVER
				(
					PARTITION BY 
						COALESCE(NULLIF(CHARINDEX(CHAR(13) + 'Formatted', @outputs, number + 1), 0), LEN(@outputs))
					ORDER BY
						number
				) AS output_group_order
			FROM numbers
			WHERE
				SUBSTRING(@outputs, number, 10) = CHAR(13) + 'Formatted'
				OR SUBSTRING(@outputs, number, 2) = CHAR(13) + CHAR(255) COLLATE Latin1_General_Bin2
		),
		output_tokens AS
		(
			SELECT 
				*,
				CASE output_group_order
					WHEN 2 THEN MAX(CASE output_group_order WHEN 1 THEN token ELSE NULL END) OVER (PARTITION BY output_group)
					ELSE ''
				END COLLATE Latin1_General_Bin2 AS column_info
			FROM tokens
		)
		SELECT
			CASE output_group_order
				WHEN 1 THEN '-----------------------------------'
				WHEN 2 THEN 
					CASE
						WHEN CHARINDEX('Formatted/Non:', column_info) = 1 THEN
							SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)+1, CHARINDEX(']', column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)+2) - CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info))
						ELSE
							SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)+2, CHARINDEX(']', column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)+2) - CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info)-1)
					END
				ELSE ''
			END AS formatted_column_name,
			CASE output_group_order
				WHEN 1 THEN '-----------------------------------'
				WHEN 2 THEN 
					CASE
						WHEN CHARINDEX('Formatted/Non:', column_info) = 1 THEN
							SUBSTRING(column_info, CHARINDEX(']', column_info)+2, LEN(column_info))
						ELSE
							SUBSTRING(column_info, CHARINDEX(']', column_info)+2, CHARINDEX('Non-Formatted:', column_info, CHARINDEX(']', column_info)+2) - CHARINDEX(']', column_info)-3)
					END
				ELSE ''
			END AS formatted_column_type,
			CASE output_group_order
				WHEN 1 THEN '---------------------------------------'
				WHEN 2 THEN 
					CASE
						WHEN CHARINDEX('Formatted/Non:', column_info) = 1 THEN ''
						ELSE
							CASE
								WHEN SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1, 1) = '<' THEN
									SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1, CHARINDEX('>', column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1) - CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info)))
								ELSE
									SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1, CHARINDEX(']', column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1) - CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info)))
							END
					END
				ELSE ''
			END AS unformatted_column_name,
			CASE output_group_order
				WHEN 1 THEN '---------------------------------------'
				WHEN 2 THEN 
					CASE
						WHEN CHARINDEX('Formatted/Non:', column_info) = 1 THEN ''
						ELSE
							CASE
								WHEN SUBSTRING(column_info, CHARINDEX(CHAR(255) COLLATE Latin1_General_Bin2, column_info, CHARINDEX('Non-Formatted:', column_info))+1, 1) = '<' THEN ''
								ELSE
									SUBSTRING(column_info, CHARINDEX(']', column_info, CHARINDEX('Non-Formatted:', column_info))+2, CHARINDEX('Non-Formatted:', column_info, CHARINDEX(']', column_info)+2) - CHARINDEX(']', column_info)-3)
							END
					END
				ELSE ''
			END AS unformatted_column_type,
			CASE output_group_order
				WHEN 1 THEN '----------------------------------------------------------------------------------------------------------------------'
				ELSE REPLACE(token, CHAR(255) COLLATE Latin1_General_Bin2, '')
			END AS [------description-----------------------------------------------------------------------------------------------------]
		FROM output_tokens
		WHERE
			NOT 
			(
				output_group_order = 1 
				AND output_group = LEN(@outputs)
			)
		ORDER BY
			output_group,
			CASE output_group_order
				WHEN 1 THEN 99
				ELSE output_group_order
			END;

		RETURN;
	END;

	WITH
	a0 AS
	(SELECT 1 AS n UNION ALL SELECT 1),
	a1 AS
	(SELECT 1 AS n FROM a0 AS a, a0 AS b),
	a2 AS
	(SELECT 1 AS n FROM a1 AS a, a1 AS b),
	a3 AS
	(SELECT 1 AS n FROM a2 AS a, a2 AS b),
	a4 AS
	(SELECT 1 AS n FROM a3 AS a, a3 AS b),
	numbers AS
	(
		SELECT TOP(LEN(@output_column_list))
			ROW_NUMBER() OVER
			(
				ORDER BY (SELECT NULL)
			) AS number
		FROM a4
		ORDER BY
			number
	),
	tokens AS
	(
		SELECT 
			'|[' +
				SUBSTRING
				(
					@output_column_list,
					number + 1,
					CHARINDEX(']', @output_column_list, number) - number - 1
				) + '|]' AS token,
			number
		FROM numbers
		WHERE
			SUBSTRING(@output_column_list, number, 1) = '['
	),
	ordered_columns AS
	(
		SELECT
			x.column_name,
			ROW_NUMBER() OVER
			(
				PARTITION BY
					x.column_name
				ORDER BY
					tokens.number,
					x.default_order
			) AS r,
			ROW_NUMBER() OVER
			(
				ORDER BY
					tokens.number,
					x.default_order
			) AS s
		FROM tokens
		JOIN
		(
			SELECT '[session_id]' AS column_name, 1 AS default_order
			UNION ALL
			SELECT '[dd hh:mm:ss.mss]', 2
			WHERE
				@format_output = 1
			UNION ALL
			SELECT '[dd hh:mm:ss.mss (avg)]', 3
			WHERE
				@format_output = 1
				AND @get_avg_time = 1
			UNION ALL
			SELECT '[avg_elapsed_time]', 4
			WHERE
				@format_output = 0
				AND @get_avg_time = 1
			UNION ALL
			SELECT '[physical_io]', 5
			WHERE
				@get_task_info = 2
			UNION ALL
			SELECT '[reads]', 6
			UNION ALL
			SELECT '[physical_reads]', 7
			UNION ALL
			SELECT '[writes]', 8
			UNION ALL
			SELECT '[tempdb_allocations]', 9
			UNION ALL
			SELECT '[tempdb_current]', 10
			UNION ALL
			SELECT '[CPU]', 11
			UNION ALL
			SELECT '[context_switches]', 12
			WHERE
				@get_task_info = 2
			UNION ALL
			SELECT '[used_memory]', 13
			UNION ALL
			SELECT '[physical_io_delta]', 14
			WHERE
				@delta_interval > 0	
				AND @get_task_info = 2
			UNION ALL
			SELECT '[reads_delta]', 15
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[physical_reads_delta]', 16
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[writes_delta]', 17
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[tempdb_allocations_delta]', 18
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[tempdb_current_delta]', 19
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[CPU_delta]', 20
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[context_switches_delta]', 21
			WHERE
				@delta_interval > 0
				AND @get_task_info = 2
			UNION ALL
			SELECT '[used_memory_delta]', 22
			WHERE
				@delta_interval > 0
			UNION ALL
			SELECT '[tasks]', 23
			WHERE
				@get_task_info = 2
			UNION ALL
			SELECT '[status]', 24
			UNION ALL
			SELECT '[wait_info]', 25
			WHERE
				@get_task_info > 0
				OR @find_block_leaders = 1
			UNION ALL
			SELECT '[locks]', 26
			WHERE
				@get_locks = 1
			UNION ALL
			SELECT '[tran_start_time]', 27
			WHERE
				@get_transaction_info = 1
			UNION ALL
			SELECT '[tran_log_writes]', 28
			WHERE
				@get_transaction_info = 1
			UNION ALL
			SELECT '[open_tran_count]', 29
			UNION ALL
			SELECT '[sql_command]', 30
			WHERE
				@get_outer_command = 1
			UNION ALL
			SELECT '[sql_text]', 31
			UNION ALL
			SELECT '[query_plan]', 32
			WHERE
				@get_plans >= 1
			UNION ALL
			SELECT '[blocking_session_id]', 33
			WHERE
				@get_task_info > 0
				OR @find_block_leaders = 1
			UNION ALL
			SELECT '[blocked_session_count]', 34
			WHERE
				@find_block_leaders = 1
			UNION ALL
			SELECT '[percent_complete]', 35
			UNION ALL
			SELECT '[host_name]', 36
			UNION ALL
			SELECT '[login_name]', 37
			UNION ALL
			SELECT '[database_name]', 38
			UNION ALL
			SELECT '[program_name]', 39
			UNION ALL
			SELECT '[additional_info]', 40
			WHERE
				@get_additional_info = 1
			UNION ALL
			SELECT '[start_time]', 41
			UNION ALL
			SELECT '[login_time]', 42
			UNION ALL
			SELECT '[request_id]', 43
			UNION ALL
			SELECT '[collection_time]', 44
		) AS x ON 
			x.column_name LIKE token ESCAPE '|'
	)
	SELECT
		@output_column_list =
			STUFF
			(
				(
					SELECT
						',' + column_name as [text()]
					FROM ordered_columns
					WHERE
						r = 1
					ORDER BY
						s
					FOR XML
						PATH('')
				),
				1,
				1,
				''
			);
	
	IF COALESCE(RTRIM(@output_column_list), '') = ''
	BEGIN;
		RAISERROR('No valid column matches found in @output_column_list or no columns remain due to selected options.', 16, 1);
		RETURN;
	END;
	
	IF @destination_table <> ''
	BEGIN;
		SET @destination_table = 
			--database
			COALESCE(QUOTENAME(PARSENAME(@destination_table, 3)) + '.', '') +
			--schema
			COALESCE(QUOTENAME(PARSENAME(@destination_table, 2)) + '.', '') +
			--table
			COALESCE(QUOTENAME(PARSENAME(@destination_table, 1)), '');
			
		IF COALESCE(RTRIM(@destination_table), '') = ''
		BEGIN;
			RAISERROR('Destination table not properly formatted.', 16, 1);
			RETURN;
		END;
	END;

	WITH
	a0 AS
	(SELECT 1 AS n UNION ALL SELECT 1),
	a1 AS
	(SELECT 1 AS n FROM a0 AS a, a0 AS b),
	a2 AS
	(SELECT 1 AS n FROM a1 AS a, a1 AS b),
	a3 AS
	(SELECT 1 AS n FROM a2 AS a, a2 AS b),
	a4 AS
	(SELECT 1 AS n FROM a3 AS a, a3 AS b),
	numbers AS
	(
		SELECT TOP(LEN(@sort_order))
			ROW_NUMBER() OVER
			(
				ORDER BY (SELECT NULL)
			) AS number
		FROM a4
		ORDER BY
			number
	),
	tokens AS
	(
		SELECT 
			'|[' +
				SUBSTRING
				(
					@sort_order,
					number + 1,
					CHARINDEX(']', @sort_order, number) - number - 1
				) + '|]' AS token,
			SUBSTRING
			(
				@sort_order,
				CHARINDEX(']', @sort_order, number) + 1,
				COALESCE(NULLIF(CHARINDEX('[', @sort_order, CHARINDEX(']', @sort_order, number)), 0), LEN(@sort_order)) - CHARINDEX(']', @sort_order, number)
			) AS next_chunk,
			number
		FROM numbers
		WHERE
			SUBSTRING(@sort_order, number, 1) = '['
	),
	ordered_columns AS
	(
		SELECT
			x.column_name +
				CASE
					WHEN tokens.next_chunk LIKE '%asc%' THEN ' ASC'
					WHEN tokens.next_chunk LIKE '%desc%' THEN ' DESC'
					ELSE ''
				END AS column_name,
			ROW_NUMBER() OVER
			(
				PARTITION BY
					x.column_name
				ORDER BY
					tokens.number
			) AS r,
			tokens.number
		FROM tokens
		JOIN
		(
			SELECT '[session_id]' AS column_name
			UNION ALL
			SELECT '[physical_io]'
			UNION ALL
			SELECT '[reads]'
			UNION ALL
			SELECT '[physical_reads]'
			UNION ALL
			SELECT '[writes]'
			UNION ALL
			SELECT '[tempdb_allocations]'
			UNION ALL
			SELECT '[tempdb_current]'
			UNION ALL
			SELECT '[CPU]'
			UNION ALL
			SELECT '[context_switches]'
			UNION ALL
			SELECT '[used_memory]'
			UNION ALL
			SELECT '[physical_io_delta]'
			UNION ALL
			SELECT '[reads_delta]'
			UNION ALL
			SELECT '[physical_reads_delta]'
			UNION ALL
			SELECT '[writes_delta]'
			UNION ALL
			SELECT '[tempdb_allocations_delta]'
			UNION ALL
			SELECT '[tempdb_current_delta]'
			UNION ALL
			SELECT '[CPU_delta]'
			UNION ALL
			SELECT '[context_switches_delta]'
			UNION ALL
			SELECT '[used_memory_delta]'
			UNION ALL
			SELECT '[tasks]'
			UNION ALL
			SELECT '[tran_start_time]'
			UNION ALL
			SELECT '[open_tran_count]'
			UNION ALL
			SELECT '[blocking_session_id]'
			UNION ALL
			SELECT '[blocked_session_count]'
			UNION ALL
			SELECT '[percent_complete]'
			UNION ALL
			SELECT '[host_name]'
			UNION ALL
			SELECT '[login_name]'
			UNION ALL
			SELECT '[database_name]'
			UNION ALL
			SELECT '[start_time]'
			UNION ALL
			SELECT '[login_time]'
		) AS x ON 
			x.column_name LIKE token ESCAPE '|'
	)
	SELECT
		@sort_order = COALESCE(z.sort_order, '')
	FROM
	(
		SELECT
			STUFF
			(
				(
					SELECT
						',' + column_name as [text()]
					FROM ordered_columns
					WHERE
						r = 1
					ORDER BY
						number
					FOR XML
						PATH('')
				),
				1,
				1,
				''
			) AS sort_order
	) AS z;

	CREATE TABLE #sessions
	(
		recursion SMALLINT NOT NULL,
		session_id SMALLINT NOT NULL,
		request_id INT NOT NULL,
		session_number INT NOT NULL,
		elapsed_time INT NOT NULL,
		avg_elapsed_time INT NULL,
		physical_io BIGINT NULL,
		reads BIGINT NULL,
		physical_reads BIGINT NULL,
		writes BIGINT NULL,
		tempdb_allocations BIGINT NULL,
		tempdb_current BIGINT NULL,
		CPU INT NULL,
		thread_CPU_snapshot BIGINT NULL,
		context_switches BIGINT NULL,
		used_memory BIGINT NOT NULL, 
		tasks SMALLINT NULL,
		status VARCHAR(30) NOT NULL,
		wait_info NVARCHAR(4000) NULL,
		locks XML NULL,
		transaction_id BIGINT NULL,
		tran_start_time DATETIME NULL,
		tran_log_writes NVARCHAR(4000) NULL,
		open_tran_count SMALLINT NULL,
		sql_command XML NULL,
		sql_handle VARBINARY(64) NULL,
		statement_start_offset INT NULL,
		statement_end_offset INT NULL,
		sql_text XML NULL,
		plan_handle VARBINARY(64) NULL,
		query_plan XML NULL,
		blocking_session_id SMALLINT NULL,
		blocked_session_count SMALLINT NULL,
		percent_complete REAL NULL,
		host_name sysname NULL,
		login_name sysname NOT NULL,
		database_name sysname NULL,
		program_name sysname NULL,
		additional_info XML NULL,
		start_time DATETIME NOT NULL,
		login_time DATETIME NULL,
		last_request_start_time DATETIME NULL,
		PRIMARY KEY CLUSTERED (session_id, request_id, recursion) WITH (IGNORE_DUP_KEY = ON),
		UNIQUE NONCLUSTERED (transaction_id, session_id, request_id, recursion) WITH (IGNORE_DUP_KEY = ON)
	);

	IF @return_schema = 0
	BEGIN;
		--Disable unnecessary autostats on the table
		CREATE STATISTICS s_session_id ON #sessions (session_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_request_id ON #sessions (request_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_transaction_id ON #sessions (transaction_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_session_number ON #sessions (session_number)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_status ON #sessions (status)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_start_time ON #sessions (start_time)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_last_request_start_time ON #sessions (last_request_start_time)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_recursion ON #sessions (recursion)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;

		DECLARE @recursion SMALLINT;
		SET @recursion = 
			CASE @delta_interval
				WHEN 0 THEN 1
				ELSE -1
			END;

		DECLARE @first_collection_ms_ticks BIGINT;
		DECLARE @last_collection_start DATETIME;

		--Used for the delta pull
		REDO:;
		
		IF 
			@get_locks = 1 
			AND @recursion = 1
			AND @output_column_list LIKE '%|[locks|]%' ESCAPE '|'
		BEGIN;
			SELECT
				y.resource_type,
				y.database_name,
				y.object_id,
				y.file_id,
				y.page_type,
				y.hobt_id,
				y.allocation_unit_id,
				y.index_id,
				y.schema_id,
				y.principal_id,
				y.request_mode,
				y.request_status,
				y.session_id,
				y.resource_description,
				y.request_count,
				s.request_id,
				s.start_time,
				CONVERT(sysname, NULL) AS object_name,
				CONVERT(sysname, NULL) AS index_name,
				CONVERT(sysname, NULL) AS schema_name,
				CONVERT(sysname, NULL) AS principal_name,
				CONVERT(NVARCHAR(2048), NULL) AS query_error
			INTO #locks
			FROM
			(
				SELECT
					sp.spid AS session_id,
					CASE sp.status
						WHEN 'sleeping' THEN CONVERT(INT, 0)
						ELSE sp.request_id
					END AS request_id,
					CASE sp.status
						WHEN 'sleeping' THEN sp.last_batch
						ELSE COALESCE(req.start_time, sp.last_batch)
					END AS start_time,
					sp.dbid
				FROM sys.sysprocesses AS sp
				OUTER APPLY
				(
					SELECT TOP(1)
						CASE
							WHEN 
							(
								sp.hostprocess > ''
								OR r.total_elapsed_time < 0
							) THEN
								r.start_time
							ELSE
								DATEADD
								(
									ms, 
									1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())), 
									DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())
								)
						END AS start_time
					FROM sys.dm_exec_requests AS r
					WHERE
						r.session_id = sp.spid
						AND r.request_id = sp.request_id
				) AS req
				WHERE
					--Process inclusive filter
					1 =
						CASE
							WHEN @filter <> '' THEN
								CASE @filter_type
									WHEN 'session' THEN
										CASE
											WHEN
												CONVERT(SMALLINT, @filter) = 0
												OR sp.spid = CONVERT(SMALLINT, @filter)
													THEN 1
											ELSE 0
										END
									WHEN 'program' THEN
										CASE
											WHEN sp.program_name LIKE @filter THEN 1
											ELSE 0
										END
									WHEN 'login' THEN
										CASE
											WHEN sp.loginame LIKE @filter THEN 1
											ELSE 0
										END
									WHEN 'host' THEN
										CASE
											WHEN sp.hostname LIKE @filter THEN 1
											ELSE 0
										END
									WHEN 'database' THEN
										CASE
											WHEN DB_NAME(sp.dbid) LIKE @filter THEN 1
											ELSE 0
										END
									ELSE 0
								END
							ELSE 1
						END
					--Process exclusive filter
					AND 0 =
						CASE
							WHEN @not_filter <> '' THEN
								CASE @not_filter_type
									WHEN 'session' THEN
										CASE
											WHEN sp.spid = CONVERT(SMALLINT, @not_filter) THEN 1
											ELSE 0
										END
									WHEN 'program' THEN
										CASE
											WHEN sp.program_name LIKE @not_filter THEN 1
											ELSE 0
										END
									WHEN 'login' THEN
										CASE
											WHEN sp.loginame LIKE @not_filter THEN 1
											ELSE 0
										END
									WHEN 'host' THEN
										CASE
											WHEN sp.hostname LIKE @not_filter THEN 1
											ELSE 0
										END
									WHEN 'database' THEN
										CASE
											WHEN DB_NAME(sp.dbid) LIKE @not_filter THEN 1
											ELSE 0
										END
									ELSE 0
								END
							ELSE 0
						END
					AND 
					(
						@show_own_spid = 1
						OR sp.spid <> @@SPID
					)
					AND 
					(
						@show_system_spids = 1
						OR sp.hostprocess > ''
					)
					AND sp.ecid = 0
			) AS s
			INNER HASH JOIN
			(
				SELECT
					x.resource_type,
					x.database_name,
					x.object_id,
					x.file_id,
					CASE
						WHEN x.page_no = 1 OR x.page_no % 8088 = 0 THEN 'PFS'
						WHEN x.page_no = 2 OR x.page_no % 511232 = 0 THEN 'GAM'
						WHEN x.page_no = 3 OR x.page_no % 511233 = 0 THEN 'SGAM'
						WHEN x.page_no = 6 OR x.page_no % 511238 = 0 THEN 'DCM'
						WHEN x.page_no = 7 OR x.page_no % 511239 = 0 THEN 'BCM'
						WHEN x.page_no IS NOT NULL THEN '*'
						ELSE NULL
					END AS page_type,
					x.hobt_id,
					x.allocation_unit_id,
					x.index_id,
					x.schema_id,
					x.principal_id,
					x.request_mode,
					x.request_status,
					x.session_id,
					x.request_id,
					CASE
						WHEN COALESCE(x.object_id, x.file_id, x.hobt_id, x.allocation_unit_id, x.index_id, x.schema_id, x.principal_id) IS NULL THEN NULLIF(resource_description, '')
						ELSE NULL
					END AS resource_description,
					COUNT(*) AS request_count
				FROM
				(
					SELECT
						tl.resource_type +
							CASE
								WHEN tl.resource_subtype = '' THEN ''
								ELSE '.' + tl.resource_subtype
							END AS resource_type,
						COALESCE(DB_NAME(tl.resource_database_id), N'(null)') AS database_name,
						CONVERT
						(
							INT,
							CASE
								WHEN tl.resource_type = 'OBJECT' THEN tl.resource_associated_entity_id
								WHEN tl.resource_description LIKE '%object_id = %' THEN
									(
										SUBSTRING
										(
											tl.resource_description, 
											(CHARINDEX('object_id = ', tl.resource_description) + 12), 
											COALESCE
											(
												NULLIF
												(
													CHARINDEX(',', tl.resource_description, CHARINDEX('object_id = ', tl.resource_description) + 12),
													0
												), 
												DATALENGTH(tl.resource_description)+1
											) - (CHARINDEX('object_id = ', tl.resource_description) + 12)
										)
									)
								ELSE NULL
							END
						) AS object_id,
						CONVERT
						(
							INT,
							CASE 
								WHEN tl.resource_type = 'FILE' THEN CONVERT(INT, tl.resource_description)
								WHEN tl.resource_type IN ('PAGE', 'EXTENT', 'RID') THEN LEFT(tl.resource_description, CHARINDEX(':', tl.resource_description)-1)
								ELSE NULL
							END
						) AS file_id,
						CONVERT
						(
							INT,
							CASE
								WHEN tl.resource_type IN ('PAGE', 'EXTENT', 'RID') THEN 
									SUBSTRING
									(
										tl.resource_description, 
										CHARINDEX(':', tl.resource_description) + 1, 
										COALESCE
										(
											NULLIF
											(
												CHARINDEX(':', tl.resource_description, CHARINDEX(':', tl.resource_description) + 1), 
												0
											), 
											DATALENGTH(tl.resource_description)+1
										) - (CHARINDEX(':', tl.resource_description) + 1)
									)
								ELSE NULL
							END
						) AS page_no,
						CASE
							WHEN tl.resource_type IN ('PAGE', 'KEY', 'RID', 'HOBT') THEN tl.resource_associated_entity_id
							ELSE NULL
						END AS hobt_id,
						CASE
							WHEN tl.resource_type = 'ALLOCATION_UNIT' THEN tl.resource_associated_entity_id
							ELSE NULL
						END AS allocation_unit_id,
						CONVERT
						(
							INT,
							CASE
								WHEN
									/*TODO: Deal with server principals*/ 
									tl.resource_subtype <> 'SERVER_PRINCIPAL' 
									AND tl.resource_description LIKE '%index_id or stats_id = %' THEN
									(
										SUBSTRING
										(
											tl.resource_description, 
											(CHARINDEX('index_id or stats_id = ', tl.resource_description) + 23), 
											COALESCE
											(
												NULLIF
												(
													CHARINDEX(',', tl.resource_description, CHARINDEX('index_id or stats_id = ', tl.resource_description) + 23), 
													0
												), 
												DATALENGTH(tl.resource_description)+1
											) - (CHARINDEX('index_id or stats_id = ', tl.resource_description) + 23)
										)
									)
								ELSE NULL
							END 
						) AS index_id,
						CONVERT
						(
							INT,
							CASE
								WHEN tl.resource_description LIKE '%schema_id = %' THEN
									(
										SUBSTRING
										(
											tl.resource_description, 
											(CHARINDEX('schema_id = ', tl.resource_description) + 12), 
											COALESCE
											(
												NULLIF
												(
													CHARINDEX(',', tl.resource_description, CHARINDEX('schema_id = ', tl.resource_description) + 12), 
													0
												), 
												DATALENGTH(tl.resource_description)+1
											) - (CHARINDEX('schema_id = ', tl.resource_description) + 12)
										)
									)
								ELSE NULL
							END 
						) AS schema_id,
						CONVERT
						(
							INT,
							CASE
								WHEN tl.resource_description LIKE '%principal_id = %' THEN
									(
										SUBSTRING
										(
											tl.resource_description, 
											(CHARINDEX('principal_id = ', tl.resource_description) + 15), 
											COALESCE
											(
												NULLIF
												(
													CHARINDEX(',', tl.resource_description, CHARINDEX('principal_id = ', tl.resource_description) + 15), 
													0
												), 
												DATALENGTH(tl.resource_description)+1
											) - (CHARINDEX('principal_id = ', tl.resource_description) + 15)
										)
									)
								ELSE NULL
							END
						) AS principal_id,
						tl.request_mode,
						tl.request_status,
						tl.request_session_id AS session_id,
						tl.request_request_id AS request_id,

						/*TODO: Applocks, other resource_descriptions*/
						RTRIM(tl.resource_description) AS resource_description,
						tl.resource_associated_entity_id
						/*********************************************/
					FROM 
					(
						SELECT 
							request_session_id,
							CONVERT(VARCHAR(120), resource_type) COLLATE Latin1_General_Bin2 AS resource_type,
							CONVERT(VARCHAR(120), resource_subtype) COLLATE Latin1_General_Bin2 AS resource_subtype,
							resource_database_id,
							CONVERT(VARCHAR(512), resource_description) COLLATE Latin1_General_Bin2 AS resource_description,
							resource_associated_entity_id,
							CONVERT(VARCHAR(120), request_mode) COLLATE Latin1_General_Bin2 AS request_mode,
							CONVERT(VARCHAR(120), request_status) COLLATE Latin1_General_Bin2 AS request_status,
							request_request_id
						FROM sys.dm_tran_locks
					) AS tl
				) AS x
				GROUP BY
					x.resource_type,
					x.database_name,
					x.object_id,
					x.file_id,
					CASE
						WHEN x.page_no = 1 OR x.page_no % 8088 = 0 THEN 'PFS'
						WHEN x.page_no = 2 OR x.page_no % 511232 = 0 THEN 'GAM'
						WHEN x.page_no = 3 OR x.page_no % 511233 = 0 THEN 'SGAM'
						WHEN x.page_no = 6 OR x.page_no % 511238 = 0 THEN 'DCM'
						WHEN x.page_no = 7 OR x.page_no % 511239 = 0 THEN 'BCM'
						WHEN x.page_no IS NOT NULL THEN '*'
						ELSE NULL
					END,
					x.hobt_id,
					x.allocation_unit_id,
					x.index_id,
					x.schema_id,
					x.principal_id,
					x.request_mode,
					x.request_status,
					x.session_id,
					x.request_id,
					CASE
						WHEN COALESCE(x.object_id, x.file_id, x.hobt_id, x.allocation_unit_id, x.index_id, x.schema_id, x.principal_id) IS NULL THEN NULLIF(resource_description, '')
						ELSE NULL
					END
			) AS y ON
				y.session_id = s.session_id
				AND y.request_id = s.request_id
			OPTION (HASH GROUP);

			--Disable unnecessary autostats on the table
			CREATE STATISTICS s_database_name ON #locks (database_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_object_id ON #locks (object_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_hobt_id ON #locks (hobt_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_allocation_unit_id ON #locks (allocation_unit_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_index_id ON #locks (index_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_schema_id ON #locks (schema_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_principal_id ON #locks (principal_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_request_id ON #locks (request_id)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_start_time ON #locks (start_time)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_resource_type ON #locks (resource_type)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_object_name ON #locks (object_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_schema_name ON #locks (schema_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_page_type ON #locks (page_type)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_request_mode ON #locks (request_mode)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_request_status ON #locks (request_status)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_resource_description ON #locks (resource_description)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_index_name ON #locks (index_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_principal_name ON #locks (principal_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
		END;
		
		DECLARE 
			@sql VARCHAR(MAX), 
			@sql_n NVARCHAR(MAX);

		SET @sql = 
			CONVERT(VARCHAR(MAX), '') +
			'DECLARE @blocker BIT; ' +
			'SET @blocker = 0; ' +
			'DECLARE @i INT; ' +
			'SET @i = 2147483647; ' +
			'' +
			'DECLARE @sessions TABLE ' +
			'( ' +
				'session_id SMALLINT NOT NULL, ' +
				'request_id INT NOT NULL, ' +
				'login_time DATETIME, ' +
				'last_request_end_time DATETIME, ' +
				'status VARCHAR(30), ' +
				'statement_start_offset INT, ' +
				'statement_end_offset INT, ' +
				'sql_handle BINARY(20), ' +
				'host_name NVARCHAR(128), ' +
				'login_name NVARCHAR(128), ' +
				'program_name NVARCHAR(128), ' +
				'database_id SMALLINT, ' +
				'memory_usage INT, ' +
				'open_tran_count SMALLINT, ' +
				CASE
					WHEN 
					(
						@get_task_info <> 0 
						OR @find_block_leaders = 1 
					) THEN
						'wait_type NVARCHAR(32), ' +
						'wait_resource NVARCHAR(256), ' +
						'wait_time BIGINT, '
					ELSE ''
				END +
				'blocked SMALLINT, ' +
				'is_user_process BIT, ' +
				'cmd VARCHAR(32), ' +
				'PRIMARY KEY CLUSTERED (session_id, request_id) WITH (IGNORE_DUP_KEY = ON) ' +
			'); ' +
			'' +
			'DECLARE @blockers TABLE ' +
			'( ' +
				'session_id INT NOT NULL PRIMARY KEY ' +
			'); ' +
			'' +
			'BLOCKERS:; ' +
			'' +
			'INSERT @sessions ' +
			'( ' +
				'session_id, ' +
				'request_id, ' +
				'login_time, ' +
				'last_request_end_time, ' +
				'status, ' +
				'statement_start_offset, ' +
				'statement_end_offset, ' +
				'sql_handle, ' +
				'host_name, ' +
				'login_name, ' +
				'program_name, ' +
				'database_id, ' +
				'memory_usage, ' +
				'open_tran_count, ' +
				CASE
					WHEN 
					(
						@get_task_info <> 0
						OR @find_block_leaders = 1 
					) THEN
						'wait_type, ' +
						'wait_resource, ' +
						'wait_time, '
					ELSE
						''
				END +
				'blocked, ' +
				'is_user_process, ' +
				'cmd ' +
			') ' +
			'SELECT TOP(@i) ' +
				'spy.session_id, ' +
				'spy.request_id, ' +
				'spy.login_time, ' +
				'spy.last_request_end_time, ' +
				'spy.status, ' +
				'spy.statement_start_offset, ' +
				'spy.statement_end_offset, ' +
				'spy.sql_handle, ' +
				'spy.host_name, ' +
				'spy.login_name, ' +
				'spy.program_name, ' +
				'spy.database_id, ' +
				'spy.memory_usage, ' +
				'spy.open_tran_count, ' +
				CASE
					WHEN 
					(
						@get_task_info <> 0  
						OR @find_block_leaders = 1 
					) THEN
						'spy.wait_type, ' +
						'CASE ' +
							'WHEN ' +
								'spy.wait_type LIKE N''PAGE%LATCH_%'' ' +
								'OR spy.wait_type = N''CXPACKET'' ' +
								'OR spy.wait_type LIKE N''LATCH[_]%'' ' +
								'OR spy.wait_type = N''OLEDB'' THEN ' +
									'spy.wait_resource ' +
							'ELSE ' +
								'NULL ' +
						'END AS wait_resource, ' +
						'spy.wait_time, '
					ELSE ''
				END +
				'spy.blocked, ' +
				'spy.is_user_process, ' +
				'spy.cmd ' +
			'FROM ' +
			'( ' +
				'SELECT TOP(@i) ' +
					'spx.*, ' +
					CASE
						WHEN 
						(
							@get_task_info <> 0 
							OR @find_block_leaders = 1 
						) THEN
							'ROW_NUMBER() OVER ' +
							'( ' +
								'PARTITION BY ' +
									'spx.session_id, ' +
									'spx.request_id ' +
								'ORDER BY ' +
									'CASE ' +
										'WHEN spx.wait_type LIKE N''LCK[_]%'' THEN 1 ' +
										'ELSE 99 ' +
									'END, ' +
									'spx.wait_time DESC, ' +
									'spx.blocked DESC ' +
							') AS r '
						ELSE '1 AS r '
					END +
				'FROM ' +
				'( ' +
					'SELECT TOP(@i) ' +
						'sp0.session_id, ' +
						'sp0.request_id, ' +
						'sp0.login_time, ' +
						'sp0.last_request_end_time, ' +
						'LOWER(sp0.status) AS status, ' +
						'CASE ' +
							'WHEN sp0.cmd = ''CREATE INDEX'' THEN 0 ' +
							'ELSE sp0.stmt_start ' +
						'END AS statement_start_offset, ' +
						'CASE ' +
							'WHEN sp0.cmd = N''CREATE INDEX'' THEN -1 ' +
							'ELSE COALESCE(NULLIF(sp0.stmt_end, 0), -1) ' +
						'END AS statement_end_offset, ' +
						'sp0.sql_handle, ' +
						'sp0.host_name, ' +
						'sp0.login_name, ' +
						'sp0.program_name, ' +
						'sp0.database_id, ' +
						'sp0.memory_usage, ' +
						'sp0.open_tran_count, ' +
						CASE
							WHEN 
							(
								@get_task_info <> 0 
								OR @find_block_leaders = 1 
							) THEN
								'CASE ' +
									'WHEN sp0.wait_time > 0 AND sp0.wait_type <> N''CXPACKET'' THEN sp0.wait_type ' +
									'ELSE NULL ' +
								'END AS wait_type, ' +
								'CASE ' +
									'WHEN sp0.wait_time > 0 AND sp0.wait_type <> N''CXPACKET'' THEN sp0.wait_resource ' +
									'ELSE NULL ' +
								'END AS wait_resource, ' +
								'CASE ' +
									'WHEN sp0.wait_type <> N''CXPACKET'' THEN sp0.wait_time ' +
									'ELSE 0 ' +
								'END AS wait_time, '
							ELSE ''
						END +
						'sp0.blocked, ' +
						'sp0.is_user_process, ' +
						'sp0.cmd ' +
					'FROM ' +
					'( ' +
						'SELECT TOP(@i) ' +
							'sp1.session_id, ' +
							'sp1.request_id, ' +
							'sp1.login_time, ' +
							'sp1.last_request_end_time, ' +
							'sp1.status, ' +
							'sp1.cmd, ' +
							'sp1.stmt_start, ' +
							'sp1.stmt_end, ' +
							'MAX(NULLIF(sp1.sql_handle, 0x00)) OVER (PARTITION BY sp1.session_id, sp1.request_id) AS sql_handle, ' +
							'sp1.host_name, ' +
							'MAX(sp1.login_name) OVER (PARTITION BY sp1.session_id, sp1.request_id) AS login_name, ' +
							'sp1.program_name, ' +
							'sp1.database_id, ' +
							'MAX(sp1.memory_usage)  OVER (PARTITION BY sp1.session_id, sp1.request_id) AS memory_usage, ' +
							'MAX(sp1.open_tran_count)  OVER (PARTITION BY sp1.session_id, sp1.request_id) AS open_tran_count, ' +
							'sp1.wait_type, ' +
							'sp1.wait_resource, ' +
							'sp1.wait_time, ' +
							'sp1.blocked, ' +
							'sp1.hostprocess, ' +
							'sp1.is_user_process ' +
						'FROM ' +
						'( ' +
							'SELECT TOP(@i) ' +
								'sp2.spid AS session_id, ' +
								'CASE sp2.status ' +
									'WHEN ''sleeping'' THEN CONVERT(INT, 0) ' +
									'ELSE sp2.request_id ' +
								'END AS request_id, ' +
								'MAX(sp2.login_time) AS login_time, ' +
								'MAX(sp2.last_batch) AS last_request_end_time, ' +
								'MAX(CONVERT(VARCHAR(30), RTRIM(sp2.status)) COLLATE Latin1_General_Bin2) AS status, ' +
								'MAX(CONVERT(VARCHAR(32), RTRIM(sp2.cmd)) COLLATE Latin1_General_Bin2) AS cmd, ' +
								'MAX(sp2.stmt_start) AS stmt_start, ' +
								'MAX(sp2.stmt_end) AS stmt_end, ' +
								'MAX(sp2.sql_handle) AS sql_handle, ' +
								'MAX(CONVERT(sysname, RTRIM(sp2.hostname)) COLLATE SQL_Latin1_General_CP1_CI_AS) AS host_name, ' +
								'MAX(CONVERT(sysname, RTRIM(sp2.loginame)) COLLATE SQL_Latin1_General_CP1_CI_AS) AS login_name, ' +
								'MAX ' +
								'( ' +
									'CASE ' +
										'WHEN blk.queue_id IS NOT NULL THEN ' + 
											'N''Service Broker ' +
												'database_id: '' + CONVERT(NVARCHAR, blk.database_id) + ' +
												'N'' queue_id: '' + CONVERT(NVARCHAR, blk.queue_id)' +
										'ELSE ' +
											'CONVERT ' +
											'( ' +
												'sysname, ' +
												'RTRIM(sp2.program_name) ' +
											') ' +
									'END COLLATE SQL_Latin1_General_CP1_CI_AS ' +
								') AS program_name, ' +
								'MAX(sp2.dbid) AS database_id, ' +
								'MAX(sp2.memusage) AS memory_usage, ' +
								'MAX(sp2.open_tran) AS open_tran_count, ' +
								'RTRIM(sp2.lastwaittype) AS wait_type, ' +
								'RTRIM(sp2.waitresource) AS wait_resource, ' +
								'MAX(sp2.waittime) AS wait_time, ' +
								'COALESCE(NULLIF(sp2.blocked, sp2.spid), 0) AS blocked, ' +
								'MAX ' +
								'( ' +
									'CASE ' +
										'WHEN blk.session_id = sp2.spid THEN ' +
											'''blocker'' ' +
										'ELSE ' +
											'RTRIM(sp2.hostprocess) ' +
									'END ' +
								') AS hostprocess, ' +
								'CONVERT ' +
								'( ' +
									'BIT, ' +
									'MAX ' +
									'( ' +
										'CASE ' +
											'WHEN sp2.hostprocess > '''' THEN ' +
												'1 ' +
											'ELSE ' +
												'0 ' +
										'END ' +
									') ' +
								') AS is_user_process ' +
							'FROM ' +
							'( ' +
								'SELECT TOP(@i) ' +
									'session_id, ' +
									'CONVERT(INT, NULL) AS queue_id, ' +
									'CONVERT(INT, NULL) AS database_id ' +
								'FROM @blockers ' +
								'' +
								'UNION ALL ' +
								'' +
								'SELECT TOP(@i) ' +
									'CONVERT(SMALLINT, 0), ' +
									'CONVERT(INT, NULL) AS queue_id, ' +
									'CONVERT(INT, NULL) AS database_id ' +
								'WHERE ' +
									'@blocker = 0 ' +
								'' +
								'UNION ALL ' +
								'' +
								'SELECT TOP(@i) ' +
									'CONVERT(SMALLINT, spid), ' +
									'queue_id, ' +
									'database_id ' +
								'FROM sys.dm_broker_activated_tasks ' +
								'WHERE ' +
									'@blocker = 0 ' +
							') AS blk ' +
							'INNER JOIN sys.sysprocesses AS sp2 ON ' +
								'sp2.spid = blk.session_id ' +
								'OR ' +
								'( ' +
									'blk.session_id = 0 ' +
									'AND @blocker = 0 ' +
								') ' +
							CASE 
								WHEN 
								(
									@get_task_info = 0 
									AND @find_block_leaders = 0
								) THEN
									'WHERE ' +
										'sp2.ecid = 0 ' 
								ELSE ''
							END +
							'GROUP BY ' +
								'sp2.spid, ' +
								'CASE sp2.status ' +
									'WHEN ''sleeping'' THEN CONVERT(INT, 0) ' +
									'ELSE sp2.request_id ' +
								'END, ' +
								'RTRIM(sp2.lastwaittype), ' +
								'RTRIM(sp2.waitresource), ' +
								'COALESCE(NULLIF(sp2.blocked, sp2.spid), 0) ' +
						') AS sp1 ' +
					') AS sp0 ' +
					'WHERE ' +
						'@blocker = 1 ' +
						'OR ' +
						'(1=1 ' +
							--inclusive filter
							CASE
								WHEN @filter <> '' THEN
									CASE @filter_type
										WHEN 'session' THEN
											CASE
												WHEN CONVERT(SMALLINT, @filter) <> 0 THEN
													'AND sp0.session_id = CONVERT(SMALLINT, @filter) '
												ELSE ''
											END
										WHEN 'program' THEN
											'AND sp0.program_name LIKE @filter '
										WHEN 'login' THEN
											'AND sp0.login_name LIKE @filter '
										WHEN 'host' THEN
											'AND sp0.host_name LIKE @filter '
										WHEN 'database' THEN
											'AND DB_NAME(sp0.database_id) LIKE @filter '
										ELSE ''
									END
								ELSE ''
							END +
							--exclusive filter
							CASE
								WHEN @not_filter <> '' THEN
									CASE @not_filter_type
										WHEN 'session' THEN
											CASE
												WHEN CONVERT(SMALLINT, @not_filter) <> 0 THEN
													'AND sp0.session_id <> CONVERT(SMALLINT, @not_filter) '
												ELSE ''
											END
										WHEN 'program' THEN
											'AND sp0.program_name NOT LIKE @not_filter '
										WHEN 'login' THEN
											'AND sp0.login_name NOT LIKE @not_filter '
										WHEN 'host' THEN
											'AND sp0.host_name NOT LIKE @not_filter '
										WHEN 'database' THEN
											'AND DB_NAME(sp0.database_id) NOT LIKE @not_filter '
										ELSE ''
									END
								ELSE ''
							END +
							CASE @show_own_spid
								WHEN 1 THEN ''
								ELSE
									'AND sp0.session_id <> @@spid '
							END +
							CASE 
								WHEN @show_system_spids = 0 THEN
									'AND sp0.hostprocess > '''' ' 
								ELSE ''
							END +
							CASE @show_sleeping_spids
								WHEN 0 THEN
									'AND sp0.status <> ''sleeping'' '
								WHEN 1 THEN
									'AND ' +
									'( ' +
										'sp0.status <> ''sleeping'' ' +
										'OR sp0.open_tran_count > 0 ' +
									') '
								ELSE ''
							END +
						') ' +
				') AS spx ' +
			') AS spy ' +
			'WHERE ' +
				'spy.r = 1; ' + 
			CASE @recursion
				WHEN 1 THEN 
					'IF @@ROWCOUNT > 0 ' +
					'BEGIN; ' +
						'INSERT @blockers ' +
						'( ' +
							'session_id ' +
						') ' +
						'SELECT TOP(@i) ' +
							'blocked ' +
						'FROM @sessions ' +
						'WHERE ' +
							'NULLIF(blocked, 0) IS NOT NULL ' +
						'' +
						'EXCEPT ' +
						'' +
						'SELECT TOP(@i) ' +
							'session_id ' +
						'FROM @sessions; ' +
						'' +
						CASE
							WHEN
							(
								@get_task_info > 0
								OR @find_block_leaders = 1
							) THEN
								'IF @@ROWCOUNT > 0 ' +
								'BEGIN; ' +
									'SET @blocker = 1; ' +
									'GOTO BLOCKERS; ' +
								'END; '
							ELSE ''
						END +
					'END; '
				ELSE ''
			END +
			'SELECT TOP(@i) ' +
				'@recursion AS recursion, ' +
				'x.session_id, ' +
				'x.request_id, ' +
				'DENSE_RANK() OVER  ' +
				'( ' +
					'ORDER BY ' +
						'x.session_id ' +
				') AS session_number, ' +
				CASE
					WHEN @output_column_list LIKE '%|[dd hh:mm:ss.mss|]%' ESCAPE '|' THEN 'x.elapsed_time '
					ELSE '0 '
				END + 'AS elapsed_time, ' +
				CASE
					WHEN
						(
							@output_column_list LIKE '%|[dd hh:mm:ss.mss (avg)|]%' ESCAPE '|' OR 
							@output_column_list LIKE '%|[avg_elapsed_time|]%' ESCAPE '|'
						)
						AND @recursion = 1
							THEN 'x.avg_elapsed_time / 1000 '
					ELSE 'NULL '
				END + 'AS avg_elapsed_time, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[physical_io|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[physical_io_delta|]%' ESCAPE '|'
							THEN 'x.physical_io '
					ELSE 'NULL '
				END + 'AS physical_io, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[reads|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[reads_delta|]%' ESCAPE '|'
							THEN 'x.reads '
					ELSE '0 '
				END + 'AS reads, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[physical_reads|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[physical_reads_delta|]%' ESCAPE '|'
							THEN 'x.physical_reads '
					ELSE '0 '
				END + 'AS physical_reads, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[writes|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[writes_delta|]%' ESCAPE '|'
							THEN 'x.writes '
					ELSE '0 '
				END + 'AS writes, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[tempdb_allocations|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[tempdb_allocations_delta|]%' ESCAPE '|'
							THEN 'x.tempdb_allocations '
					ELSE '0 '
				END + 'AS tempdb_allocations, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[tempdb_current|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[tempdb_current_delta|]%' ESCAPE '|'
							THEN 'x.tempdb_current '
					ELSE '0 '
				END + 'AS tempdb_current, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[CPU|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[CPU_delta|]%' ESCAPE '|'
							THEN 'x.CPU '
					ELSE '0 '
				END + 'AS CPU, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[CPU_delta|]%' ESCAPE '|'
						AND @get_task_info = 2
							THEN 'x.thread_CPU_snapshot '
					ELSE '0 '
				END + 'AS thread_CPU_snapshot, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[context_switches|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[context_switches_delta|]%' ESCAPE '|'
							THEN 'x.context_switches '
					ELSE 'NULL '
				END + 'AS context_switches, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[used_memory|]%' ESCAPE '|'
						OR @output_column_list LIKE '%|[used_memory_delta|]%' ESCAPE '|'
							THEN 'x.used_memory '
					ELSE '0 '
				END + 'AS used_memory, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[tasks|]%' ESCAPE '|'
						AND @recursion = 1
							THEN 'x.tasks '
					ELSE 'NULL '
				END + 'AS tasks, ' +
				CASE
					WHEN 
						(
							@output_column_list LIKE '%|[status|]%' ESCAPE '|' 
							OR @output_column_list LIKE '%|[sql_command|]%' ESCAPE '|'
						)
						AND @recursion = 1
							THEN 'x.status '
					ELSE ''''' '
				END + 'AS status, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[wait_info|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 
								CASE @get_task_info
									WHEN 2 THEN 'COALESCE(x.task_wait_info, x.sys_wait_info) '
									ELSE 'x.sys_wait_info '
								END
					ELSE 'NULL '
				END + 'AS wait_info, ' +
				CASE
					WHEN 
						(
							@output_column_list LIKE '%|[tran_start_time|]%' ESCAPE '|' 
							OR @output_column_list LIKE '%|[tran_log_writes|]%' ESCAPE '|' 
						)
						AND @recursion = 1
							THEN 
							'x.transaction_id '
					ELSE 'NULL '
				END + 'AS transaction_id, ' +					
				CASE
					WHEN 
						@output_column_list LIKE '%|[open_tran_count|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 'x.open_tran_count '
					ELSE 'NULL '
				END + 'AS open_tran_count, ' + 
				CASE
					WHEN 
						@output_column_list LIKE '%|[sql_text|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 'x.sql_handle '
					ELSE 'NULL '
				END + 'AS sql_handle, ' +
				CASE
					WHEN 
						(
							@output_column_list LIKE '%|[sql_text|]%' ESCAPE '|' 
							OR @output_column_list LIKE '%|[query_plan|]%' ESCAPE '|' 
						)
						AND @recursion = 1
							THEN 'x.statement_start_offset '
					ELSE 'NULL '
				END + 'AS statement_start_offset, ' +
				CASE
					WHEN 
						(
							@output_column_list LIKE '%|[sql_text|]%' ESCAPE '|' 
							OR @output_column_list LIKE '%|[query_plan|]%' ESCAPE '|' 
						)
						AND @recursion = 1
							THEN 'x.statement_end_offset '
					ELSE 'NULL '
				END + 'AS statement_end_offset, ' +
				'NULL AS sql_text, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[query_plan|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 'x.plan_handle '
					ELSE 'NULL '
				END + 'AS plan_handle, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[blocking_session_id|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 'NULLIF(x.blocking_session_id, 0) '
					ELSE 'NULL '
				END + 'AS blocking_session_id, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[percent_complete|]%' ESCAPE '|'
						AND @recursion = 1
							THEN 'x.percent_complete '
					ELSE 'NULL '
				END + 'AS percent_complete, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[host_name|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 'x.host_name '
					ELSE ''''' '
				END + 'AS host_name, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[login_name|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 'x.login_name '
					ELSE ''''' '
				END + 'AS login_name, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[database_name|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 'DB_NAME(x.database_id) '
					ELSE 'NULL '
				END + 'AS database_name, ' +
				CASE
					WHEN 
						@output_column_list LIKE '%|[program_name|]%' ESCAPE '|' 
						AND @recursion = 1
							THEN 'x.program_name '
					ELSE ''''' '
				END + 'AS program_name, ' +
				CASE
					WHEN
						@output_column_list LIKE '%|[additional_info|]%' ESCAPE '|'
						AND @recursion = 1
							THEN
								'( ' +
									'SELECT TOP(@i) ' +
										'text_size, ' +
										'language, ' +
										'date_format, ' +
										'date_first, ' +
										'CASE quoted_identifier ' +
											'WHEN 0 THEN ''OFF'' ' +
											'WHEN 1 THEN ''ON'' ' +
										'END AS quoted_identifier, ' +
										'CASE arithabort ' +
											'WHEN 0 THEN ''OFF'' ' +
											'WHEN 1 THEN ''ON'' ' +
										'END AS arithabort, ' +
										'CASE ansi_null_dflt_on ' +
											'WHEN 0 THEN ''OFF'' ' +
											'WHEN 1 THEN ''ON'' ' +
										'END AS ansi_null_dflt_on, ' +
										'CASE ansi_defaults ' +
											'WHEN 0 THEN ''OFF'' ' +
											'WHEN 1 THEN ''ON'' ' +
										'END AS ansi_defaults, ' +
										'CASE ansi_warnings ' +
											'WHEN 0 THEN ''OFF'' ' +
											'WHEN 1 THEN ''ON'' ' +
										'END AS ansi_warnings, ' +
										'CASE ansi_padding ' +
											'WHEN 0 THEN ''OFF'' ' +
											'WHEN 1 THEN ''ON'' ' +
										'END AS ansi_padding, ' +
										'CASE ansi_nulls ' +
											'WHEN 0 THEN ''OFF'' ' +
											'WHEN 1 THEN ''ON'' ' +
										'END AS ansi_nulls, ' +
										'CASE concat_null_yields_null ' +
											'WHEN 0 THEN ''OFF'' ' +
											'WHEN 1 THEN ''ON'' ' +
										'END AS concat_null_yields_null, ' +
										'CASE transaction_isolation_level ' +
											'WHEN 0 THEN ''Unspecified'' ' +
											'WHEN 1 THEN ''ReadUncomitted'' ' +
											'WHEN 2 THEN ''ReadCommitted'' ' +
											'WHEN 3 THEN ''Repeatable'' ' +
											'WHEN 4 THEN ''Serializable'' ' +
											'WHEN 5 THEN ''Snapshot'' ' +
										'END AS transaction_isolation_level, ' +
										'lock_timeout, ' +
										'deadlock_priority, ' +
										'row_count, ' +
										'command_type, ' +
										CASE
											WHEN @output_column_list LIKE '%|[program_name|]%' ESCAPE '|' THEN
												'( ' +
													'SELECT TOP(1) ' +
														'CONVERT(uniqueidentifier, CONVERT(XML, '''').value(''xs:hexBinary( substring(sql:column("agent_info.job_id_string"), 0) )'', ''binary(16)'')) AS job_id, ' +
														'agent_info.step_id, ' +
														'( ' +
															'SELECT TOP(1) ' +
																'NULL ' +
															'FOR XML ' +
																'PATH(''job_name''), ' +
																'TYPE ' +
														'), ' +
														'( ' +
															'SELECT TOP(1) ' +
																'NULL ' +
															'FOR XML ' +
																'PATH(''step_name''), ' +
																'TYPE ' +
														') ' +
													'FROM ' +
													'( ' +
														'SELECT TOP(1) ' +
															'SUBSTRING(x.program_name, CHARINDEX(''0x'', x.program_name) + 2, 32) AS job_id_string, ' +
															'SUBSTRING(x.program_name, CHARINDEX('': Step '', x.program_name) + 7, CHARINDEX('')'', x.program_name, CHARINDEX('': Step '', x.program_name)) - (CHARINDEX('': Step '', x.program_name) + 7)) AS step_id ' +
														'WHERE '+
															'x.program_name LIKE N''SQLAgent - TSQL JobStep (Job 0x%'' ' +
													') AS agent_info ' +
													'FOR XML ' +
														'PATH(''agent_job_info''), ' +
														'TYPE ' +
												') '
											ELSE ''
										END +
										CASE
											WHEN @get_task_info = 2 THEN
												', CONVERT(XML, x.block_info) AS block_info '
											ELSE
												''
										END +
									'FOR XML ' +
										'PATH(''additional_info''), ' +
										'TYPE ' +
								') '
					ELSE 'NULL '
				END + 'AS additional_info, ' +
				'x.start_time, ' +
				CASE
					WHEN
						@output_column_list LIKE '%|[login_time|]%' ESCAPE '|'
						AND @recursion = 1
							THEN
								'x.login_time '
					ELSE 'NULL '
				END + 'AS login_time, ' +
				'x.last_request_start_time ' +
			'FROM ' +
			'( ' +
				'SELECT TOP(@i) ' +
					'y.*, ' +
					'CASE ' +
						--if there are more than 24 days, return a negative number of seconds rather than
						--positive milliseconds, in order to avoid overflow errors
						'WHEN DATEDIFF(day, y.start_time, GETDATE()) > 24 THEN ' +
							'DATEDIFF(second, GETDATE(), y.start_time) ' +
						'ELSE DATEDIFF(ms, y.start_time, GETDATE()) ' +
					'END AS elapsed_time, ' +
					'COALESCE(tempdb_info.tempdb_allocations, 0) AS tempdb_allocations, ' +
					'COALESCE ' +
					'( ' +
						'CASE ' +
							'WHEN tempdb_info.tempdb_current < 0 THEN 0 ' +
							'ELSE tempdb_info.tempdb_current ' + 
						'END, ' +
						'0 ' +
					') AS tempdb_current, ' +
					CASE
						WHEN 
							(
								@get_task_info <> 0
								OR @find_block_leaders = 1
							) THEN
								'N''('' + CONVERT(NVARCHAR, y.wait_duration_ms) + N''ms)'' + ' +
									'y.wait_type + ' +
										--TODO: What else can be pulled from the resource_description?
										'CASE ' +
											'WHEN y.wait_type LIKE N''PAGE%LATCH_%'' THEN ' +
												'N'':'' + ' +
												--database name
												'COALESCE(DB_NAME(CONVERT(INT, LEFT(y.resource_description, CHARINDEX(N'':'', y.resource_description) - 1))), N''(null)'') + ' +
												'N'':'' + ' +
												--file id
												'SUBSTRING(y.resource_description, CHARINDEX(N'':'', y.resource_description) + 1, LEN(y.resource_description) - CHARINDEX(N'':'', REVERSE(y.resource_description)) - CHARINDEX(N'':'', y.resource_description)) + ' +
												--page # for special pages
												'N''('' + ' +
													'CASE ' +
														'WHEN ' +
															'CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 1 OR ' +
															'CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) % 8088 = 0 THEN N''PFS'' ' +
														'WHEN ' +
															'CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 2 OR ' +
															'CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) % 511232 = 0 THEN N''GAM'' ' +
														'WHEN ' +
															'CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 3 OR ' +
															'CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) % 511233 = 0 THEN N''SGAM'' ' +
														'WHEN ' +
															'CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 6 OR ' +
															'CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) % 511238 = 0 THEN N''DCM'' ' +
														'WHEN ' +
															'CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) = 7 OR ' +
															'CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N'':'', REVERSE(y.resource_description)) - 1)) % 511239 = 0 THEN N''BCM'' ' +
														'ELSE N''*'' ' +
													'END + ' +
												'N'')'' ' +
											'WHEN y.wait_type = N''CXPACKET'' THEN ' +
												'N'':'' + SUBSTRING(y.resource_description, CHARINDEX(N''nodeId'', y.resource_description) + 7, 4)' +
											'WHEN y.wait_type LIKE N''LATCH[_]%'' THEN ' +
												'N'' ['' + LEFT(y.resource_description, COALESCE(NULLIF(CHARINDEX(N'' '', y.resource_description), 0), LEN(y.resource_description) + 1) - 1) + N'']'' ' +
											'WHEN ' +
												'y.wait_type = N''OLEDB'' ' +
												'AND y.resource_description LIKE N''%(SPID=%)'' THEN ' +
													'N''['' + LEFT(y.resource_description, CHARINDEX(N''(SPID='', y.resource_description) - 2) + ' +
														'N'':'' + SUBSTRING(y.resource_description, CHARINDEX(N''(SPID='', y.resource_description) + 6, CHARINDEX(N'')'', y.resource_description, (CHARINDEX(N''(SPID='', y.resource_description) + 6)) - (CHARINDEX(N''(SPID='', y.resource_description) + 6)) + '']'' ' +
											'ELSE N'''' ' +
										'END COLLATE Latin1_General_Bin2 AS sys_wait_info, '
						ELSE
							''
						END +
						CASE
							WHEN @get_task_info = 2 THEN
								'tasks.physical_io, ' +
								'tasks.context_switches, ' + 
								'tasks.tasks, ' +
								'tasks.block_info, ' +
								'tasks.wait_info AS task_wait_info, ' +
								'tasks.thread_CPU_snapshot, '
						ELSE
							'' 
					END +
					CASE 
						WHEN NOT (@get_avg_time = 1 AND @recursion = 1) THEN 'CONVERT(INT, NULL) '
						ELSE 'qs.total_elapsed_time / qs.execution_count '
					END + 'AS avg_elapsed_time ' +
				'FROM ' +
				'( ' +
					'SELECT TOP(@i) ' +
						'sp.session_id, ' +
						'sp.request_id, ' +
						'COALESCE(r.logical_reads, s.logical_reads) AS reads, ' +
						'COALESCE(r.reads, s.reads) AS physical_reads, ' +
						'COALESCE(r.writes, s.writes) AS writes, ' +
						'COALESCE(r.CPU_time, s.CPU_time) AS CPU, ' +
						'sp.memory_usage + COALESCE(r.granted_query_memory, 0) AS used_memory, ' +
						'LOWER(sp.status) AS status, ' +
						'COALESCE(r.sql_handle, sp.sql_handle) AS sql_handle, ' +
						'COALESCE(r.statement_start_offset, sp.statement_start_offset) AS statement_start_offset, ' +
						'COALESCE(r.statement_end_offset, sp.statement_end_offset) AS statement_end_offset, ' +
						CASE
							WHEN 
							(
								@get_task_info <> 0
								OR @find_block_leaders = 1 
							) THEN
								'sp.wait_type COLLATE Latin1_General_Bin2 AS wait_type, ' +
								'sp.wait_resource COLLATE Latin1_General_Bin2 AS resource_description, ' +
								'sp.wait_time AS wait_duration_ms, '
							ELSE ''
						END +
						'NULLIF(sp.blocked, 0) AS blocking_session_id, ' +
						'r.plan_handle, ' +
						'NULLIF(r.percent_complete, 0) AS percent_complete, ' +
						'sp.host_name, ' +
						'sp.login_name, ' +
						'sp.program_name, ' +
						'COALESCE(r.text_size, s.text_size) AS text_size, ' +
						'COALESCE(r.language, s.language) AS language, ' +
						'COALESCE(r.date_format, s.date_format) AS date_format, ' +
						'COALESCE(r.date_first, s.date_first) AS date_first, ' +
						'COALESCE(r.quoted_identifier, s.quoted_identifier) AS quoted_identifier, ' +
						'COALESCE(r.arithabort, s.arithabort) AS arithabort, ' +
						'COALESCE(r.ansi_null_dflt_on, s.ansi_null_dflt_on) AS ansi_null_dflt_on, ' +
						'COALESCE(r.ansi_defaults, s.ansi_defaults) AS ansi_defaults, ' +
						'COALESCE(r.ansi_warnings, s.ansi_warnings) AS ansi_warnings, ' +
						'COALESCE(r.ansi_padding, s.ansi_padding) AS ansi_padding, ' +
						'COALESCE(r.ansi_nulls, s.ansi_nulls) AS ansi_nulls, ' +
						'COALESCE(r.concat_null_yields_null, s.concat_null_yields_null) AS concat_null_yields_null, ' +
						'COALESCE(r.transaction_isolation_level, s.transaction_isolation_level) AS transaction_isolation_level, ' +
						'COALESCE(r.lock_timeout, s.lock_timeout) AS lock_timeout, ' +
						'COALESCE(r.deadlock_priority, s.deadlock_priority) AS deadlock_priority, ' +
						'COALESCE(r.row_count, s.row_count) AS row_count, ' +
						'COALESCE(r.command, sp.cmd) AS command_type, ' +
						'COALESCE ' +
						'( ' +
							'CASE ' +
								'WHEN ' +
								'( ' +
									's.is_user_process = 0 ' +
									'AND r.total_elapsed_time >= 0 ' +
								') THEN ' +
									'DATEADD ' +
									'( ' +
										'ms, ' +
										'1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())), ' +
										'DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE()) ' +
									') ' +
							'END, ' +
							'NULLIF(COALESCE(r.start_time, sp.last_request_end_time), CONVERT(DATETIME, ''19000101'', 112)), ' +
							'( ' +
								'SELECT TOP(1) ' +
									'DATEADD(second, -(ms_ticks / 1000), GETDATE()) ' +
								'FROM sys.dm_os_sys_info ' +
							') ' +
						') AS start_time, ' +
						'sp.login_time, ' +
						'CASE ' +
							'WHEN s.is_user_process = 1 THEN ' +
								's.last_request_start_time ' +
							'ELSE ' +
								'COALESCE ' +
								'( ' +
									'DATEADD ' +
									'( ' +
										'ms, ' +
										'1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())), ' +
										'DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE()) ' +
									'), ' +
									's.last_request_start_time ' +
								') ' +
						'END AS last_request_start_time, ' +
						'r.transaction_id, ' +
						'sp.database_id, ' +
						'sp.open_tran_count ' +
					'FROM @sessions AS sp ' +
					'LEFT OUTER LOOP JOIN sys.dm_exec_sessions AS s ON ' +
						's.session_id = sp.session_id ' +
						'AND s.login_time = sp.login_time ' +
					'LEFT OUTER LOOP JOIN sys.dm_exec_requests AS r ON ' +
						'sp.status <> ''sleeping'' ' +
						'AND r.session_id = sp.session_id ' +
						'AND r.request_id = sp.request_id ' +
						'AND ' +
						'( ' +
							'( ' +
								's.is_user_process = 0 ' +
								'AND sp.is_user_process = 0 ' +
							') ' +
							'OR ' +
							'( ' +
								'r.start_time = s.last_request_start_time ' +
								'AND s.last_request_end_time = sp.last_request_end_time ' +
							') ' +
						') ' +
				') AS y ' + 
				CASE 
					WHEN @get_task_info = 2 THEN
						CONVERT(VARCHAR(MAX), '') +
						'LEFT OUTER HASH JOIN ' +
						'( ' +
							'SELECT TOP(@i) ' +
								'task_nodes.task_node.value(''(session_id/text())[1]'', ''SMALLINT'') AS session_id, ' +
								'task_nodes.task_node.value(''(request_id/text())[1]'', ''INT'') AS request_id, ' +
								'task_nodes.task_node.value(''(physical_io/text())[1]'', ''BIGINT'') AS physical_io, ' +
								'task_nodes.task_node.value(''(context_switches/text())[1]'', ''BIGINT'') AS context_switches, ' +
								'task_nodes.task_node.value(''(tasks/text())[1]'', ''INT'') AS tasks, ' +
								'task_nodes.task_node.value(''(block_info/text())[1]'', ''NVARCHAR(4000)'') AS block_info, ' +
								'task_nodes.task_node.value(''(waits/text())[1]'', ''NVARCHAR(4000)'') AS wait_info, ' +
								'task_nodes.task_node.value(''(thread_CPU_snapshot/text())[1]'', ''BIGINT'') AS thread_CPU_snapshot ' +
							'FROM ' +
							'( ' +
								'SELECT TOP(@i) ' +
									'CONVERT ' +
									'( ' +
										'XML, ' +
										'REPLACE ' +
										'( ' +
											'CONVERT(NVARCHAR(MAX), tasks_raw.task_xml_raw) COLLATE Latin1_General_Bin2, ' +
											'N''</waits></tasks><tasks><waits>'', ' +
											'N'', '' ' +
										') ' +
									') AS task_xml ' +
								'FROM ' +
								'( ' +
									'SELECT TOP(@i) ' +
										'CASE waits.r ' +
											'WHEN 1 THEN waits.session_id ' +
											'ELSE NULL ' +
										'END AS [session_id], ' +
										'CASE waits.r ' +
											'WHEN 1 THEN waits.request_id ' +
											'ELSE NULL ' +
										'END AS [request_id], ' +											
										'CASE waits.r ' +
											'WHEN 1 THEN waits.physical_io ' +
											'ELSE NULL ' +
										'END AS [physical_io], ' +
										'CASE waits.r ' +
											'WHEN 1 THEN waits.context_switches ' +
											'ELSE NULL ' +
										'END AS [context_switches], ' +
										'CASE waits.r ' +
											'WHEN 1 THEN waits.thread_CPU_snapshot ' +
											'ELSE NULL ' +
										'END AS [thread_CPU_snapshot], ' +
										'CASE waits.r ' +
											'WHEN 1 THEN waits.tasks ' +
											'ELSE NULL ' +
										'END AS [tasks], ' +
										'CASE waits.r ' +
											'WHEN 1 THEN waits.block_info ' +
											'ELSE NULL ' +
										'END AS [block_info], ' +
										'REPLACE ' +
										'( ' +
											'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
											'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
											'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
												'CONVERT ' +
												'( ' +
													'NVARCHAR(MAX), ' +
													'N''('' + ' +
														'CONVERT(NVARCHAR, num_waits) + N''x: '' + ' +
														'CASE num_waits ' +
															'WHEN 1 THEN CONVERT(NVARCHAR, min_wait_time) + N''ms'' ' +
															'WHEN 2 THEN ' +
																'CASE ' +
																	'WHEN min_wait_time <> max_wait_time THEN CONVERT(NVARCHAR, min_wait_time) + N''/'' + CONVERT(NVARCHAR, max_wait_time) + N''ms'' ' +
																	'ELSE CONVERT(NVARCHAR, max_wait_time) + N''ms'' ' +
																'END ' +
															'ELSE ' +
																'CASE ' +
																	'WHEN min_wait_time <> max_wait_time THEN CONVERT(NVARCHAR, min_wait_time) + N''/'' + CONVERT(NVARCHAR, avg_wait_time) + N''/'' + CONVERT(NVARCHAR, max_wait_time) + N''ms'' ' +
																	'ELSE CONVERT(NVARCHAR, max_wait_time) + N''ms'' ' +
																'END ' +
														'END + ' +
													'N'')'' + wait_type COLLATE Latin1_General_Bin2 ' +
												'), ' +
												'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
												'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
												'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
											'NCHAR(0), ' +
											'N'''' ' +
										') AS [waits] ' +
									'FROM ' +
									'( ' +
										'SELECT TOP(@i) ' +
											'w1.*, ' +
											'ROW_NUMBER() OVER ' +
											'( ' +
												'PARTITION BY ' +
													'w1.session_id, ' +
													'w1.request_id ' +
												'ORDER BY ' +
													'w1.block_info DESC, ' +
													'w1.num_waits DESC, ' +
													'w1.wait_type ' +
											') AS r ' +
										'FROM ' +
										'( ' +
											'SELECT TOP(@i) ' +
												'task_info.session_id, ' +
												'task_info.request_id, ' +
												'task_info.physical_io, ' +
												'task_info.context_switches, ' +
												'task_info.thread_CPU_snapshot, ' +
												'task_info.num_tasks AS tasks, ' +
												'CASE ' +
													'WHEN task_info.runnable_time IS NOT NULL THEN ' +
														'''RUNNABLE'' ' +
													'ELSE ' +
														'wt2.wait_type ' +
												'END AS wait_type, ' +
												'NULLIF(COUNT(COALESCE(task_info.runnable_time, wt2.waiting_task_address)), 0) AS num_waits, ' +
												'MIN(COALESCE(task_info.runnable_time, wt2.wait_duration_ms)) AS min_wait_time, ' +
												'AVG(COALESCE(task_info.runnable_time, wt2.wait_duration_ms)) AS avg_wait_time, ' +
												'MAX(COALESCE(task_info.runnable_time, wt2.wait_duration_ms)) AS max_wait_time, ' +
												'MAX(wt2.block_info) AS block_info ' +
											'FROM ' +
											'( ' +
												'SELECT TOP(@i) ' +
													't.session_id, ' +
													't.request_id, ' +
													'SUM(CONVERT(BIGINT, t.pending_io_count)) OVER (PARTITION BY t.session_id, t.request_id) AS physical_io, ' +
													'SUM(CONVERT(BIGINT, t.context_switches_count)) OVER (PARTITION BY t.session_id, t.request_id) AS context_switches, ' +
													CASE
														WHEN @output_column_list LIKE '%|[CPU_delta|]%' ESCAPE '|'
															THEN
																'SUM(tr.usermode_time + tr.kernel_time) OVER (PARTITION BY t.session_id, t.request_id) '
														ELSE
															'CONVERT(BIGINT, NULL) '
													END + ' AS thread_CPU_snapshot, ' +
													'COUNT(*) OVER (PARTITION BY t.session_id, t.request_id) AS num_tasks, ' +
													't.task_address, ' +
													't.task_state, ' +
													'CASE ' +
														'WHEN ' +
															't.task_state = ''RUNNABLE'' ' +
															'AND w.runnable_time > 0 THEN ' +
																'w.runnable_time ' +
														'ELSE ' +
															'NULL ' +
													'END AS runnable_time ' +
												'FROM sys.dm_os_tasks AS t ' +
												'CROSS APPLY ' +
												'( ' +
													'SELECT TOP(1) ' +
														'sp2.session_id ' +
													'FROM @sessions AS sp2 ' +
													'WHERE ' +
														'sp2.session_id = t.session_id ' +
														'AND sp2.request_id = t.request_id ' +
														'AND sp2.status <> ''sleeping'' ' +
												') AS sp20 ' +
												'LEFT OUTER HASH JOIN ' +
												'( ' +
													'SELECT TOP(@i) ' +
														'( ' +
															'SELECT TOP(@i) ' +
																'ms_ticks ' +
															'FROM sys.dm_os_sys_info ' +
														') - ' +
															'w0.wait_resumed_ms_ticks AS runnable_time, ' +
														'w0.worker_address, ' +
														'w0.thread_address, ' +
														'w0.task_bound_ms_ticks ' +
													'FROM sys.dm_os_workers AS w0 ' +
													'WHERE ' +
														'w0.state = ''RUNNABLE'' ' +
														'OR @first_collection_ms_ticks >= w0.task_bound_ms_ticks ' +
												') AS w ON ' +
													'w.worker_address = t.worker_address ' +
												CASE
													WHEN @output_column_list LIKE '%|[CPU_delta|]%' ESCAPE '|'
														THEN
															'LEFT OUTER HASH JOIN sys.dm_os_threads AS tr ON ' +
																'tr.thread_address = w.thread_address ' +
																'AND @first_collection_ms_ticks >= w.task_bound_ms_ticks ' 
													ELSE
														''
												END +
											') AS task_info ' +
											'LEFT OUTER HASH JOIN ' +
											'( ' +
												'SELECT TOP(@i) ' +
													'wt1.wait_type, ' +
													'wt1.waiting_task_address, ' +
													'MAX(wt1.wait_duration_ms) AS wait_duration_ms, ' +
													'MAX(wt1.block_info) AS block_info ' +
												'FROM ' +
												'( ' +
													'SELECT DISTINCT TOP(@i) ' +
														'wt.wait_type + ' +
															--TODO: What else can be pulled from the resource_description?
															'CASE ' +
																'WHEN wt.wait_type LIKE N''PAGE%LATCH_%'' THEN ' +
																	''':'' + ' +
																	--database name
																	'COALESCE(DB_NAME(CONVERT(INT, LEFT(wt.resource_description, CHARINDEX(N'':'', wt.resource_description) - 1))), N''(null)'') + ' +
																	'N'':'' + ' +
																	--file id
																	'SUBSTRING(wt.resource_description, CHARINDEX(N'':'', wt.resource_description) + 1, LEN(wt.resource_description) - CHARINDEX(N'':'', REVERSE(wt.resource_description)) - CHARINDEX(N'':'', wt.resource_description)) + ' +
																	--page # for special pages
																	'N''('' + ' +
																		'CASE ' +
																			'WHEN ' +
																				'CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 1 OR ' +
																				'CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) % 8088 = 0 THEN N''PFS'' ' +
																			'WHEN ' +
																				'CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 2 OR ' +
																				'CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) % 511232 = 0 THEN N''GAM'' ' +
																			'WHEN ' +
																				'CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 3 OR ' +
																				'CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) % 511233 = 0 THEN N''SGAM'' ' +
																			'WHEN ' +
																				'CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 6 OR ' +
																				'CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) % 511238 = 0 THEN N''DCM'' ' +
																			'WHEN ' +
																				'CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) = 7 OR ' +
																				'CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N'':'', REVERSE(wt.resource_description)) - 1)) % 511239 = 0 THEN N''BCM'' ' +
																			'ELSE N''*'' ' +
																		'END + ' +
																	'N'')'' ' +
																'WHEN wt.wait_type = N''CXPACKET'' THEN ' +
																	'N'':'' + SUBSTRING(wt.resource_description, CHARINDEX(N''nodeId'', wt.resource_description) + 7, 4) ' +
																'WHEN wt.wait_type LIKE N''LATCH[_]%'' THEN ' +
																	'N'' ['' + LEFT(wt.resource_description, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description), 0), LEN(wt.resource_description) + 1) - 1) + N'']'' ' +
																'ELSE N'''' ' +
															'END COLLATE Latin1_General_Bin2 AS wait_type, ' +
														'CASE ' +
															'WHEN ' +
															'( ' +
																'wt.blocking_session_id IS NOT NULL ' +
																'AND wt.wait_type LIKE N''LCK[_]%'' ' +
															') THEN ' +
																'( ' +
																	'SELECT TOP(@i) ' +
																		'x.lock_type, ' +
																		'REPLACE ' +
																		'( ' +
																			'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
																			'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
																			'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
																				'DB_NAME ' +
																				'( ' +
																					'CONVERT ' +
																					'( ' +
																						'INT, ' +
																						'SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''dbid='', wt.resource_description), 0) + 5, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''dbid='', wt.resource_description) + 5), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''dbid='', wt.resource_description) - 5) ' +
																					') ' +
																				'), ' +
																				'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
																				'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
																				'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
																			'NCHAR(0), ' +
																			'N'''' ' +
																		') AS database_name, ' +
																		'CASE x.lock_type ' +
																			'WHEN N''objectlock'' THEN SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''objid='', wt.resource_description), 0) + 6, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''objid='', wt.resource_description) + 6), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''objid='', wt.resource_description) - 6) ' +
																			'ELSE NULL ' +
																		'END AS object_id, ' +
																		'CASE x.lock_type ' +
																			'WHEN N''filelock'' THEN ' +
																				'SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''fileid='', wt.resource_description), 0) + 7, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''fileid='', wt.resource_description) + 7), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''fileid='', wt.resource_description) - 7) ' +
																			'ELSE NULL ' +
																		'END AS file_id, ' +
																		'CASE ' +
																			'WHEN x.lock_type in (N''pagelock'', N''extentlock'', N''ridlock'') THEN ' +
																				'SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''associatedObjectId='', wt.resource_description), 0) + 19, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''associatedObjectId='', wt.resource_description) + 19), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''associatedObjectId='', wt.resource_description) - 19) ' +
																			'WHEN x.lock_type in (N''keylock'', N''hobtlock'', N''allocunitlock'') THEN ' +
																				'SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''hobtid='', wt.resource_description), 0) + 7, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''hobtid='', wt.resource_description) + 7), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''hobtid='', wt.resource_description) - 7) ' +
																			'ELSE NULL ' +
																		'END AS hobt_id, ' +
																		'CASE x.lock_type ' +
																			'WHEN N''applicationlock'' THEN ' +
																				'SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''hash='', wt.resource_description), 0) + 5, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''hash='', wt.resource_description) + 5), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''hash='', wt.resource_description) - 5) ' +
																			'ELSE NULL ' +
																		'END AS applock_hash, ' +
																		'CASE x.lock_type ' +
																			'WHEN N''metadatalock'' THEN ' +
																				'SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''subresource='', wt.resource_description), 0) + 12, COALESCE(NULLIF(CHARINDEX(N'' '', wt.resource_description, CHARINDEX(N''subresource='', wt.resource_description) + 12), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N''subresource='', wt.resource_description) - 12) ' +
																			'ELSE NULL ' +
																		'END AS metadata_resource, ' +
																		'CASE x.lock_type ' +
																			'WHEN N''metadatalock'' THEN ' +
																				'SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N''classid='', wt.resource_description), 0) + 8, COALESCE(NULLIF(CHARINDEX(N'' dbid='', wt.resource_description) - CHARINDEX(N''classid='', wt.resource_description), 0), LEN(wt.resource_description) + 1) - 8) ' +
																			'ELSE NULL ' +
																		'END AS metadata_class_id ' +
																	'FROM ' +
																	'( ' +
																		'SELECT TOP(1) ' +
																			'LEFT(wt.resource_description, CHARINDEX(N'' '', wt.resource_description) - 1) COLLATE Latin1_General_Bin2 AS lock_type ' +
																	') AS x ' +
																	'FOR XML ' +
																		'PATH('''') ' +
																') ' +
															'ELSE NULL ' +
														'END AS block_info, ' +
														'wt.wait_duration_ms, ' +
														'wt.waiting_task_address ' +
													'FROM ' +
													'( ' +
														'SELECT TOP(@i) ' +
															'wt0.wait_type COLLATE Latin1_General_Bin2 AS wait_type, ' +
															'wt0.resource_description COLLATE Latin1_General_Bin2 AS resource_description, ' +
															'wt0.wait_duration_ms, ' +
															'wt0.waiting_task_address, ' +
															'CASE ' +
																'WHEN wt0.blocking_session_id = p.blocked THEN wt0.blocking_session_id ' +
																'ELSE NULL ' +
															'END AS blocking_session_id ' +
														'FROM sys.dm_os_waiting_tasks AS wt0 ' +
														'CROSS APPLY ' +
														'( ' +
															'SELECT TOP(1)' +
																's0.blocked ' +
															'FROM @sessions AS s0 ' +
															'WHERE ' +
																's0.session_id = wt0.session_id ' +
																'AND s0.wait_type <> N''OLEDB'' ' +
																'AND wt0.wait_type <> N''OLEDB'' ' +
														') AS p ' +
													') AS wt ' +
												') AS wt1 ' +
												'GROUP BY ' +
													'wt1.wait_type, ' +
													'wt1.waiting_task_address ' +
											') AS wt2 ON ' +
												'wt2.waiting_task_address = task_info.task_address ' +
												'AND wt2.wait_duration_ms > 0 ' +
												'AND task_info.runnable_time IS NULL ' +
											'GROUP BY ' +
												'task_info.session_id, ' +
												'task_info.request_id, ' +
												'task_info.physical_io, ' +
												'task_info.context_switches, ' +
												'task_info.thread_CPU_snapshot, ' +
												'task_info.num_tasks, ' +
												'CASE ' +
													'WHEN task_info.runnable_time IS NOT NULL THEN ' +
														'''RUNNABLE'' ' +
													'ELSE ' +
														'wt2.wait_type ' +
												'END ' +
										') AS w1 ' +
									') AS waits ' +
									'ORDER BY ' +
										'waits.session_id, ' +
										'waits.request_id, ' +
										'waits.r ' +
									'FOR XML ' +
										'PATH(N''tasks''), ' +
										'TYPE ' +
								') AS tasks_raw (task_xml_raw) ' +
							') AS tasks_final ' +
							'CROSS APPLY tasks_final.task_xml.nodes(N''/tasks'') AS task_nodes (task_node) ' +
							'WHERE ' +
								'task_nodes.task_node.exist(N''session_id'') = 1 ' +
						') AS tasks ON ' +
							'tasks.session_id = y.session_id ' +
							'AND tasks.request_id = y.request_id '
					ELSE ''
				END +
				'LEFT OUTER HASH JOIN ' +
				'( ' +
					'SELECT TOP(@i) ' +
						't_info.session_id, ' +
						'COALESCE(t_info.request_id, -1) AS request_id, ' +
						'SUM(t_info.tempdb_allocations) AS tempdb_allocations, ' +
						'SUM(t_info.tempdb_current) AS tempdb_current ' +
					'FROM ' +
					'( ' +
						'SELECT TOP(@i) ' +
							'tsu.session_id, ' +
							'tsu.request_id, ' +
							'tsu.user_objects_alloc_page_count + ' +
								'tsu.internal_objects_alloc_page_count AS tempdb_allocations,' +
							'tsu.user_objects_alloc_page_count + ' +
								'tsu.internal_objects_alloc_page_count - ' +
								'tsu.user_objects_dealloc_page_count - ' +
								'tsu.internal_objects_dealloc_page_count AS tempdb_current ' +
						'FROM sys.dm_db_task_space_usage AS tsu ' +
						'CROSS APPLY ' +
						'( ' +
							'SELECT TOP(1) ' +
								's0.session_id ' +
							'FROM @sessions AS s0 ' +
							'WHERE ' +
								's0.session_id = tsu.session_id ' +
						') AS p ' +
						'' +
						'UNION ALL ' +
						'' +
						'SELECT TOP(@i) ' +
							'ssu.session_id, ' +
							'NULL AS request_id, ' +
							'ssu.user_objects_alloc_page_count + ' +
								'ssu.internal_objects_alloc_page_count AS tempdb_allocations, ' +
							'ssu.user_objects_alloc_page_count + ' +
								'ssu.internal_objects_alloc_page_count - ' +
								'ssu.user_objects_dealloc_page_count - ' +
								'ssu.internal_objects_dealloc_page_count AS tempdb_current ' +
						'FROM sys.dm_db_session_space_usage AS ssu ' +
						'CROSS APPLY ' +
						'( ' +
							'SELECT TOP(1) ' +
								's0.session_id ' +
							'FROM @sessions AS s0 ' +
							'WHERE ' +
								's0.session_id = ssu.session_id ' +
						') AS p ' +
					') AS t_info ' +
					'GROUP BY ' +
						't_info.session_id, ' +
						'COALESCE(t_info.request_id, -1) ' +
				') AS tempdb_info ON ' +
					'tempdb_info.session_id = y.session_id ' +
					'AND tempdb_info.request_id = ' +
						'CASE ' +
							'WHEN y.status = N''sleeping'' THEN ' +
								'-1 ' +
							'ELSE ' +
								'y.request_id ' +
						'END ' +
				CASE 
					WHEN 
						NOT 
						(
							@get_avg_time = 1 
							AND @recursion = 1
						) THEN 
							''
					ELSE
						'LEFT OUTER HASH JOIN ' +
						'( ' +
							'SELECT TOP(@i) ' +
								'* ' +
							'FROM sys.dm_exec_query_stats ' +
						') AS qs ON ' +
							'qs.sql_handle = y.sql_handle ' + 
							'AND qs.plan_handle = y.plan_handle ' + 
							'AND qs.statement_start_offset = y.statement_start_offset ' +
							'AND qs.statement_end_offset = y.statement_end_offset '
					END + 
			') AS x ' +
			'OPTION (KEEPFIXED PLAN, OPTIMIZE FOR (@i = 1)); ';

		SET @sql_n = CONVERT(NVARCHAR(MAX), @sql);

		SET @last_collection_start = GETDATE();
		
		IF @recursion = -1
		BEGIN;
			SELECT
				@first_collection_ms_ticks = ms_ticks
			FROM sys.dm_os_sys_info;
		END;

		INSERT #sessions
		(
			recursion,
			session_id,
			request_id,
			session_number,
			elapsed_time,
			avg_elapsed_time,
			physical_io,
			reads,
			physical_reads,
			writes,
			tempdb_allocations,
			tempdb_current,
			CPU,
			thread_CPU_snapshot,
			context_switches,
			used_memory,
			tasks,
			status,
			wait_info,
			transaction_id,
			open_tran_count,
			sql_handle,
			statement_start_offset,
			statement_end_offset,		
			sql_text,
			plan_handle,
			blocking_session_id,
			percent_complete,
			host_name,
			login_name,
			database_name,
			program_name,
			additional_info,
			start_time,
			login_time,
			last_request_start_time
		)
		EXEC sp_executesql 
			@sql_n,
			N'@recursion SMALLINT, @filter sysname, @not_filter sysname, @first_collection_ms_ticks BIGINT',
			@recursion, @filter, @not_filter, @first_collection_ms_ticks;

		--Collect transaction information?
		IF
			@recursion = 1
			AND
			(
				@output_column_list LIKE '%|[tran_start_time|]%' ESCAPE '|'
				OR @output_column_list LIKE '%|[tran_log_writes|]%' ESCAPE '|' 
			)
		BEGIN;	
			DECLARE @i INT;
			SET @i = 2147483647;

			UPDATE s
			SET
				tran_start_time =
					CONVERT
					(
						DATETIME,
						LEFT
						(
							x.trans_info,
							NULLIF(CHARINDEX(NCHAR(254), x.trans_info) - 1, -1)
						),
						121
					),
				tran_log_writes =
					RIGHT
					(
						x.trans_info,
						LEN(x.trans_info) - CHARINDEX(NCHAR(254), x.trans_info)
					)
			FROM
			(
				SELECT TOP(@i)
					trans_nodes.trans_node.value('(session_id/text())[1]', 'SMALLINT') AS session_id,
					COALESCE(trans_nodes.trans_node.value('(request_id/text())[1]', 'INT'), 0) AS request_id,
					trans_nodes.trans_node.value('(trans_info/text())[1]', 'NVARCHAR(4000)') AS trans_info				
				FROM
				(
					SELECT TOP(@i)
						CONVERT
						(
							XML,
							REPLACE
							(
								CONVERT(NVARCHAR(MAX), trans_raw.trans_xml_raw) COLLATE Latin1_General_Bin2, 
								N'</trans_info></trans><trans><trans_info>', N''
							)
						)
					FROM
					(
						SELECT TOP(@i)
							CASE u_trans.r
								WHEN 1 THEN u_trans.session_id
								ELSE NULL
							END AS [session_id],
							CASE u_trans.r
								WHEN 1 THEN u_trans.request_id
								ELSE NULL
							END AS [request_id],
							CONVERT
							(
								NVARCHAR(MAX),
								CASE
									WHEN u_trans.database_id IS NOT NULL THEN
										CASE u_trans.r
											WHEN 1 THEN COALESCE(CONVERT(NVARCHAR, u_trans.transaction_start_time, 121) + NCHAR(254), N'')
											ELSE N''
										END + 
											REPLACE
											(
												REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
												REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
												REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
													CONVERT(VARCHAR(128), COALESCE(DB_NAME(u_trans.database_id), N'(null)')),
													NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
													NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
													NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
												NCHAR(0),
												N'?'
											) +
											N': ' +
										CONVERT(NVARCHAR, u_trans.log_record_count) + N' (' + CONVERT(NVARCHAR, u_trans.log_kb_used) + N' kB)' +
										N','
									ELSE
										N'N/A,'
								END COLLATE Latin1_General_Bin2
							) AS [trans_info]
						FROM
						(
							SELECT TOP(@i)
								trans.*,
								ROW_NUMBER() OVER
								(
									PARTITION BY
										trans.session_id,
										trans.request_id
									ORDER BY
										trans.transaction_start_time DESC
								) AS r
							FROM
							(
								SELECT TOP(@i)
									session_tran_map.session_id,
									session_tran_map.request_id,
									s_tran.database_id,
									COALESCE(SUM(s_tran.database_transaction_log_record_count), 0) AS log_record_count,
									COALESCE(SUM(s_tran.database_transaction_log_bytes_used), 0) / 1024 AS log_kb_used,
									MIN(s_tran.database_transaction_begin_time) AS transaction_start_time
								FROM
								(
									SELECT TOP(@i)
										*
									FROM sys.dm_tran_active_transactions
									WHERE
										transaction_begin_time <= @last_collection_start
								) AS a_tran
								INNER HASH JOIN
								(
									SELECT TOP(@i)
										*
									FROM sys.dm_tran_database_transactions
									WHERE
										database_id < 32767
								) AS s_tran ON
									s_tran.transaction_id = a_tran.transaction_id
								LEFT OUTER HASH JOIN
								(
									SELECT TOP(@i)
										*
									FROM sys.dm_tran_session_transactions
								) AS tst ON
									s_tran.transaction_id = tst.transaction_id
								CROSS APPLY
								(
									SELECT TOP(1)
										s3.session_id,
										s3.request_id
									FROM
									(
										SELECT TOP(1)
											s1.session_id,
											s1.request_id
										FROM #sessions AS s1
										WHERE
											s1.transaction_id = s_tran.transaction_id
											AND s1.recursion = 1
											
										UNION ALL
									
										SELECT TOP(1)
											s2.session_id,
											s2.request_id
										FROM #sessions AS s2
										WHERE
											s2.session_id = tst.session_id
											AND s2.recursion = 1
									) AS s3
									ORDER BY
										s3.request_id
								) AS session_tran_map
								GROUP BY
									session_tran_map.session_id,
									session_tran_map.request_id,
									s_tran.database_id
							) AS trans
						) AS u_trans
						FOR XML
							PATH('trans'),
							TYPE
					) AS trans_raw (trans_xml_raw)
				) AS trans_final (trans_xml)
				CROSS APPLY trans_final.trans_xml.nodes('/trans') AS trans_nodes (trans_node)
			) AS x
			INNER HASH JOIN #sessions AS s ON
				s.session_id = x.session_id
				AND s.request_id = x.request_id
			OPTION (OPTIMIZE FOR (@i = 1));
		END;

		--Variables for text and plan collection
		DECLARE	
			@session_id SMALLINT,
			@request_id INT,
			@sql_handle VARBINARY(64),
			@plan_handle VARBINARY(64),
			@statement_start_offset INT,
			@statement_end_offset INT,
			@start_time DATETIME,
			@database_name sysname;

		IF 
			@recursion = 1
			AND @output_column_list LIKE '%|[sql_text|]%' ESCAPE '|'
		BEGIN;
			DECLARE sql_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT 
					session_id,
					request_id,
					sql_handle,
					statement_start_offset,
					statement_end_offset
				FROM #sessions
				WHERE
					recursion = 1
					AND sql_handle IS NOT NULL
			OPTION (KEEPFIXED PLAN);

			OPEN sql_cursor;

			FETCH NEXT FROM sql_cursor
			INTO 
				@session_id,
				@request_id,
				@sql_handle,
				@statement_start_offset,
				@statement_end_offset;

			--Wait up to 5 ms for the SQL text, then give up
			SET LOCK_TIMEOUT 5;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					UPDATE s
					SET
						s.sql_text =
						(
							SELECT
								REPLACE
								(
									REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
										N'--' + NCHAR(13) + NCHAR(10) +
										CASE 
											WHEN @get_full_inner_text = 1 THEN est.text
											WHEN LEN(est.text) < (@statement_end_offset / 2) + 1 THEN est.text
											WHEN SUBSTRING(est.text, (@statement_start_offset/2), 2) LIKE N'[a-zA-Z0-9][a-zA-Z0-9]' THEN est.text
											ELSE
												CASE
													WHEN @statement_start_offset > 0 THEN
														SUBSTRING
														(
															est.text,
															((@statement_start_offset/2) + 1),
															(
																CASE
																	WHEN @statement_end_offset = -1 THEN 2147483647
																	ELSE ((@statement_end_offset - @statement_start_offset)/2) + 1
																END
															)
														)
													ELSE RTRIM(LTRIM(est.text))
												END
										END +
										NCHAR(13) + NCHAR(10) + N'--' COLLATE Latin1_General_Bin2,
										NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
										NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
										NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
									NCHAR(0),
									N''
								) AS [processing-instruction(query)]
							FOR XML
								PATH(''),
								TYPE
						),
						s.statement_start_offset = 
							CASE 
								WHEN LEN(est.text) < (@statement_end_offset / 2) + 1 THEN 0
								WHEN SUBSTRING(CONVERT(VARCHAR(MAX), est.text), (@statement_start_offset/2), 2) LIKE '[a-zA-Z0-9][a-zA-Z0-9]' THEN 0
								ELSE @statement_start_offset
							END,
						s.statement_end_offset = 
							CASE 
								WHEN LEN(est.text) < (@statement_end_offset / 2) + 1 THEN -1
								WHEN SUBSTRING(CONVERT(VARCHAR(MAX), est.text), (@statement_start_offset/2), 2) LIKE '[a-zA-Z0-9][a-zA-Z0-9]' THEN -1
								ELSE @statement_end_offset
							END
					FROM 
						#sessions AS s,
						(
							SELECT TOP(1)
								text
							FROM
							(
								SELECT 
									text, 
									0 AS row_num
								FROM sys.dm_exec_sql_text(@sql_handle)
								
								UNION ALL
								
								SELECT 
									NULL,
									1 AS row_num
							) AS est0
							ORDER BY
								row_num
						) AS est
					WHERE 
						s.session_id = @session_id
						AND s.request_id = @request_id
						AND s.recursion = 1
					OPTION (KEEPFIXED PLAN);
				END TRY
				BEGIN CATCH;
					UPDATE s
					SET
						s.sql_text = 
							CASE ERROR_NUMBER() 
								WHEN 1222 THEN '<timeout_exceeded />'
								ELSE '<error message="' + ERROR_MESSAGE() + '" />'
							END
					FROM #sessions AS s
					WHERE 
						s.session_id = @session_id
						AND s.request_id = @request_id
						AND s.recursion = 1
					OPTION (KEEPFIXED PLAN);
				END CATCH;

				FETCH NEXT FROM sql_cursor
				INTO
					@session_id,
					@request_id,
					@sql_handle,
					@statement_start_offset,
					@statement_end_offset;
			END;

			--Return this to the default
			SET LOCK_TIMEOUT -1;

			CLOSE sql_cursor;
			DEALLOCATE sql_cursor;
		END;

		IF 
			@get_outer_command = 1 
			AND @recursion = 1
			AND @output_column_list LIKE '%|[sql_command|]%' ESCAPE '|'
		BEGIN;
			DECLARE @buffer_results TABLE
			(
				EventType VARCHAR(30),
				Parameters INT,
				EventInfo NVARCHAR(4000),
				start_time DATETIME,
				session_number INT IDENTITY(1,1) NOT NULL PRIMARY KEY
			);

			DECLARE buffer_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT 
					session_id,
					MAX(start_time) AS start_time
				FROM #sessions
				WHERE
					recursion = 1
				GROUP BY
					session_id
				ORDER BY
					session_id
				OPTION (KEEPFIXED PLAN);

			OPEN buffer_cursor;

			FETCH NEXT FROM buffer_cursor
			INTO 
				@session_id,
				@start_time;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					--In SQL Server 2008, DBCC INPUTBUFFER will throw 
					--an exception if the session no longer exists
					INSERT @buffer_results
					(
						EventType,
						Parameters,
						EventInfo
					)
					EXEC sp_executesql
						N'DBCC INPUTBUFFER(@session_id) WITH NO_INFOMSGS;',
						N'@session_id SMALLINT',
						@session_id;

					UPDATE br
					SET
						br.start_time = @start_time
					FROM @buffer_results AS br
					WHERE
						br.session_number = 
						(
							SELECT MAX(br2.session_number)
							FROM @buffer_results br2
						);
				END TRY
				BEGIN CATCH
				END CATCH;

				FETCH NEXT FROM buffer_cursor
				INTO 
					@session_id,
					@start_time;
			END;

			UPDATE s
			SET
				sql_command = 
				(
					SELECT 
						REPLACE
						(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								CONVERT
								(
									NVARCHAR(MAX),
									N'--' + NCHAR(13) + NCHAR(10) + br.EventInfo + NCHAR(13) + NCHAR(10) + N'--' COLLATE Latin1_General_Bin2
								),
								NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
								NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
								NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
							NCHAR(0),
							N''
						) AS [processing-instruction(query)]
					FROM @buffer_results AS br
					WHERE 
						br.session_number = s.session_number
						AND br.start_time = s.start_time
						AND 
						(
							(
								s.start_time = s.last_request_start_time
								AND EXISTS
								(
									SELECT *
									FROM sys.dm_exec_requests r2
									WHERE
										r2.session_id = s.session_id
										AND r2.request_id = s.request_id
										AND r2.start_time = s.start_time
								)
							)
							OR 
							(
								s.request_id = 0
								AND EXISTS
								(
									SELECT *
									FROM sys.dm_exec_sessions s2
									WHERE
										s2.session_id = s.session_id
										AND s2.last_request_start_time = s.last_request_start_time
								)
							)
						)
					FOR XML
						PATH(''),
						TYPE
				)
			FROM #sessions AS s
			WHERE
				recursion = 1
			OPTION (KEEPFIXED PLAN);

			CLOSE buffer_cursor;
			DEALLOCATE buffer_cursor;
		END;

		IF 
			@get_plans >= 1 
			AND @recursion = 1
			AND @output_column_list LIKE '%|[query_plan|]%' ESCAPE '|'
		BEGIN;
			DECLARE plan_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT
					session_id,
					request_id,
					plan_handle,
					statement_start_offset,
					statement_end_offset
				FROM #sessions
				WHERE
					recursion = 1
					AND plan_handle IS NOT NULL
			OPTION (KEEPFIXED PLAN);

			OPEN plan_cursor;

			FETCH NEXT FROM plan_cursor
			INTO 
				@session_id,
				@request_id,
				@plan_handle,
				@statement_start_offset,
				@statement_end_offset;

			--Wait up to 5 ms for a query plan, then give up
			SET LOCK_TIMEOUT 5;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					UPDATE s
					SET
						s.query_plan =
						(
							SELECT
								CONVERT(xml, query_plan)
							FROM sys.dm_exec_text_query_plan
							(
								@plan_handle, 
								CASE @get_plans
									WHEN 1 THEN
										@statement_start_offset
									ELSE
										0
								END, 
								CASE @get_plans
									WHEN 1 THEN
										@statement_end_offset
									ELSE
										-1
								END
							)
						)
					FROM #sessions AS s
					WHERE 
						s.session_id = @session_id
						AND s.request_id = @request_id
						AND s.recursion = 1
					OPTION (KEEPFIXED PLAN);
				END TRY
				BEGIN CATCH;
					IF ERROR_NUMBER() = 6335
					BEGIN;
						UPDATE s
						SET
							s.query_plan =
							(
								SELECT
									N'--' + NCHAR(13) + NCHAR(10) + 
									N'-- Could not render showplan due to XML data type limitations. ' + NCHAR(13) + NCHAR(10) + 
									N'-- To see the graphical plan save the XML below as a .SQLPLAN file and re-open in SSMS.' + NCHAR(13) + NCHAR(10) +
									N'--' + NCHAR(13) + NCHAR(10) +
										REPLACE(qp.query_plan, N'<RelOp', NCHAR(13)+NCHAR(10)+N'<RelOp') + 
										NCHAR(13) + NCHAR(10) + N'--' COLLATE Latin1_General_Bin2 AS [processing-instruction(query_plan)]
								FROM sys.dm_exec_text_query_plan
								(
									@plan_handle, 
									CASE @get_plans
										WHEN 1 THEN
											@statement_start_offset
										ELSE
											0
									END, 
									CASE @get_plans
										WHEN 1 THEN
											@statement_end_offset
										ELSE
											-1
									END
								) AS qp
								FOR XML
									PATH(''),
									TYPE
							)
						FROM #sessions AS s
						WHERE 
							s.session_id = @session_id
							AND s.request_id = @request_id
							AND s.recursion = 1
						OPTION (KEEPFIXED PLAN);
					END;
					ELSE
					BEGIN;
						UPDATE s
						SET
							s.query_plan = 
								CASE ERROR_NUMBER() 
									WHEN 1222 THEN '<timeout_exceeded />'
									ELSE '<error message="' + ERROR_MESSAGE() + '" />'
								END
						FROM #sessions AS s
						WHERE 
							s.session_id = @session_id
							AND s.request_id = @request_id
							AND s.recursion = 1
						OPTION (KEEPFIXED PLAN);
					END;
				END CATCH;

				FETCH NEXT FROM plan_cursor
				INTO
					@session_id,
					@request_id,
					@plan_handle,
					@statement_start_offset,
					@statement_end_offset;
			END;

			--Return this to the default
			SET LOCK_TIMEOUT -1;

			CLOSE plan_cursor;
			DEALLOCATE plan_cursor;
		END;

		IF 
			@get_locks = 1 
			AND @recursion = 1
			AND @output_column_list LIKE '%|[locks|]%' ESCAPE '|'
		BEGIN;
			DECLARE locks_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT DISTINCT
					database_name
				FROM #locks
				WHERE
					EXISTS
					(
						SELECT *
						FROM #sessions AS s
						WHERE
							s.session_id = #locks.session_id
							AND recursion = 1
					)
					AND database_name <> '(null)'
				OPTION (KEEPFIXED PLAN);

			OPEN locks_cursor;

			FETCH NEXT FROM locks_cursor
			INTO 
				@database_name;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					SET @sql_n = CONVERT(NVARCHAR(MAX), '') +
						'UPDATE l ' +
						'SET ' +
							'object_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										'o.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								'), ' +
							'index_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										'i.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								'), ' +
							'schema_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										's.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								'), ' +
							'principal_name = ' + 
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										'dp.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								') ' +
						'FROM #locks AS l ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.allocation_units AS au ON ' +
							'au.allocation_unit_id = l.allocation_unit_id ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.partitions AS p ON ' +
							'p.hobt_id = ' +
								'COALESCE ' +
								'( ' +
									'l.hobt_id, ' +
									'CASE ' +
										'WHEN au.type IN (1, 3) THEN au.container_id ' +
										'ELSE NULL ' +
									'END ' +
								') ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.partitions AS p1 ON ' +
							'l.hobt_id IS NULL ' +
							'AND au.type = 2 ' +
							'AND p1.partition_id = au.container_id ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.objects AS o ON ' +
							'o.object_id = COALESCE(l.object_id, p.object_id, p1.object_id) ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.indexes AS i ON ' +
							'i.object_id = COALESCE(l.object_id, p.object_id, p1.object_id) ' +
							'AND i.index_id = COALESCE(l.index_id, p.index_id, p1.index_id) ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.schemas AS s ON ' +
							's.schema_id = COALESCE(l.schema_id, o.schema_id) ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.database_principals AS dp ON ' +
							'dp.principal_id = l.principal_id ' +
						'WHERE ' +
							'l.database_name = @database_name ' +
						'OPTION (KEEPFIXED PLAN); ';
					
					EXEC sp_executesql
						@sql_n,
						N'@database_name sysname',
						@database_name;
				END TRY
				BEGIN CATCH;
					UPDATE #locks
					SET
						query_error = 
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									CONVERT
									(
										NVARCHAR(MAX), 
										ERROR_MESSAGE() COLLATE Latin1_General_Bin2
									),
									NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
									NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
									NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
								NCHAR(0),
								N''
							)
					WHERE 
						database_name = @database_name
					OPTION (KEEPFIXED PLAN);
				END CATCH;

				FETCH NEXT FROM locks_cursor
				INTO
					@database_name;
			END;

			CLOSE locks_cursor;
			DEALLOCATE locks_cursor;

			CREATE CLUSTERED INDEX IX_SRD ON #locks (session_id, request_id, database_name);

			UPDATE s
			SET 
				s.locks =
				(
					SELECT 
						REPLACE
						(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								CONVERT
								(
									NVARCHAR(MAX), 
									l1.database_name COLLATE Latin1_General_Bin2
								),
								NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
								NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
								NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
							NCHAR(0),
							N''
						) AS [Database/@name],
						MIN(l1.query_error) AS [Database/@query_error],
						(
							SELECT 
								l2.request_mode AS [Lock/@request_mode],
								l2.request_status AS [Lock/@request_status],
								COUNT(*) AS [Lock/@request_count]
							FROM #locks AS l2
							WHERE 
								l1.session_id = l2.session_id
								AND l1.request_id = l2.request_id
								AND l2.database_name = l1.database_name
								AND l2.resource_type = 'DATABASE'
							GROUP BY
								l2.request_mode,
								l2.request_status
							FOR XML
								PATH(''),
								TYPE
						) AS [Database/Locks],
						(
							SELECT
								COALESCE(l3.object_name, '(null)') AS [Object/@name],
								l3.schema_name AS [Object/@schema_name],
								(
									SELECT
										l4.resource_type AS [Lock/@resource_type],
										l4.page_type AS [Lock/@page_type],
										l4.index_name AS [Lock/@index_name],
										CASE 
											WHEN l4.object_name IS NULL THEN l4.schema_name
											ELSE NULL
										END AS [Lock/@schema_name],
										l4.principal_name AS [Lock/@principal_name],
										l4.resource_description AS [Lock/@resource_description],
										l4.request_mode AS [Lock/@request_mode],
										l4.request_status AS [Lock/@request_status],
										SUM(l4.request_count) AS [Lock/@request_count]
									FROM #locks AS l4
									WHERE 
										l4.session_id = l3.session_id
										AND l4.request_id = l3.request_id
										AND l3.database_name = l4.database_name
										AND COALESCE(l3.object_name, '(null)') = COALESCE(l4.object_name, '(null)')
										AND COALESCE(l3.schema_name, '') = COALESCE(l4.schema_name, '')
										AND l4.resource_type <> 'DATABASE'
									GROUP BY
										l4.resource_type,
										l4.page_type,
										l4.index_name,
										CASE 
											WHEN l4.object_name IS NULL THEN l4.schema_name
											ELSE NULL
										END,
										l4.principal_name,
										l4.resource_description,
										l4.request_mode,
										l4.request_status
									FOR XML
										PATH(''),
										TYPE
								) AS [Object/Locks]
							FROM #locks AS l3
							WHERE 
								l3.session_id = l1.session_id
								AND l3.request_id = l1.request_id
								AND l3.database_name = l1.database_name
								AND l3.resource_type <> 'DATABASE'
							GROUP BY 
								l3.session_id,
								l3.request_id,
								l3.database_name,
								COALESCE(l3.object_name, '(null)'),
								l3.schema_name
							FOR XML
								PATH(''),
								TYPE
						) AS [Database/Objects]
					FROM #locks AS l1
					WHERE
						l1.session_id = s.session_id
						AND l1.request_id = s.request_id
						AND l1.start_time IN (s.start_time, s.last_request_start_time)
						AND s.recursion = 1
					GROUP BY 
						l1.session_id,
						l1.request_id,
						l1.database_name
					FOR XML
						PATH(''),
						TYPE
				)
			FROM #sessions s
			OPTION (KEEPFIXED PLAN);
		END;

		IF 
			@find_block_leaders = 1
			AND @recursion = 1
			AND @output_column_list LIKE '%|[blocked_session_count|]%' ESCAPE '|'
		BEGIN;
			WITH
			blockers AS
			(
				SELECT
					session_id,
					session_id AS top_level_session_id
				FROM #sessions
				WHERE
					recursion = 1

				UNION ALL

				SELECT
					s.session_id,
					b.top_level_session_id
				FROM blockers AS b
				JOIN #sessions AS s ON
					s.blocking_session_id = b.session_id
					AND s.recursion = 1
			)
			UPDATE s
			SET
				s.blocked_session_count = x.blocked_session_count
			FROM #sessions AS s
			JOIN
			(
				SELECT
					b.top_level_session_id AS session_id,
					COUNT(*) - 1 AS blocked_session_count
				FROM blockers AS b
				GROUP BY
					b.top_level_session_id
			) x ON
				s.session_id = x.session_id
			WHERE
				s.recursion = 1;
		END;

		IF
			@get_task_info = 2
			AND @output_column_list LIKE '%|[additional_info|]%' ESCAPE '|'
			AND @recursion = 1
		BEGIN;
			CREATE TABLE #blocked_requests
			(
				session_id SMALLINT NOT NULL,
				request_id INT NOT NULL,
				database_name sysname NOT NULL,
				object_id INT,
				hobt_id BIGINT,
				schema_id INT,
				schema_name sysname NULL,
				object_name sysname NULL,
				query_error NVARCHAR(2048),
				PRIMARY KEY (database_name, session_id, request_id)
			);

			CREATE STATISTICS s_database_name ON #blocked_requests (database_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_schema_name ON #blocked_requests (schema_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_object_name ON #blocked_requests (object_name)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
			CREATE STATISTICS s_query_error ON #blocked_requests (query_error)
			WITH SAMPLE 0 ROWS, NORECOMPUTE;
		
			INSERT #blocked_requests
			(
				session_id,
				request_id,
				database_name,
				object_id,
				hobt_id,
				schema_id
			)
			SELECT
				session_id,
				request_id,
				database_name,
				object_id,
				hobt_id,
				CONVERT(INT, SUBSTRING(schema_node, CHARINDEX(' = ', schema_node) + 3, LEN(schema_node))) AS schema_id
			FROM
			(
				SELECT
					session_id,
					request_id,
					agent_nodes.agent_node.value('(database_name/text())[1]', 'sysname') AS database_name,
					agent_nodes.agent_node.value('(object_id/text())[1]', 'int') AS object_id,
					agent_nodes.agent_node.value('(hobt_id/text())[1]', 'bigint') AS hobt_id,
					agent_nodes.agent_node.value('(metadata_resource/text()[.="SCHEMA"]/../../metadata_class_id/text())[1]', 'varchar(100)') AS schema_node
				FROM #sessions AS s
				CROSS APPLY s.additional_info.nodes('//block_info') AS agent_nodes (agent_node)
				WHERE
					s.recursion = 1
			) AS t
			WHERE
				t.object_id IS NOT NULL
				OR t.hobt_id IS NOT NULL
				OR t.schema_node IS NOT NULL;
			
			DECLARE blocks_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR
				SELECT DISTINCT
					database_name
				FROM #blocked_requests;
				
			OPEN blocks_cursor;
			
			FETCH NEXT FROM blocks_cursor
			INTO 
				@database_name;
			
			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					SET @sql_n = 
						CONVERT(NVARCHAR(MAX), '') +
						'UPDATE b ' +
						'SET ' +
							'b.schema_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										's.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								'), ' +
							'b.object_name = ' +
								'REPLACE ' +
								'( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
										'o.name COLLATE Latin1_General_Bin2, ' +
										'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
										'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
										'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
									'NCHAR(0), ' +
									N''''' ' +
								') ' +
						'FROM #blocked_requests AS b ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.partitions AS p ON ' +
							'p.hobt_id = b.hobt_id ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.objects AS o ON ' +
							'o.object_id = COALESCE(p.object_id, b.object_id) ' +
						'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.schemas AS s ON ' +
							's.schema_id = COALESCE(o.schema_id, b.schema_id) ' +
						'WHERE ' +
							'b.database_name = @database_name; ';
					
					EXEC sp_executesql
						@sql_n,
						N'@database_name sysname',
						@database_name;
				END TRY
				BEGIN CATCH;
					UPDATE #blocked_requests
					SET
						query_error = 
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									CONVERT
									(
										NVARCHAR(MAX), 
										ERROR_MESSAGE() COLLATE Latin1_General_Bin2
									),
									NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
									NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
									NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
								NCHAR(0),
								N''
							)
					WHERE
						database_name = @database_name;
				END CATCH;

				FETCH NEXT FROM blocks_cursor
				INTO
					@database_name;
			END;
			
			CLOSE blocks_cursor;
			DEALLOCATE blocks_cursor;
			
			UPDATE s
			SET
				additional_info.modify
				('
					insert <schema_name>{sql:column("b.schema_name")}</schema_name>
					as last
					into (/additional_info/block_info)[1]
				')
			FROM #sessions AS s
			INNER JOIN #blocked_requests AS b ON
				b.session_id = s.session_id
				AND b.request_id = s.request_id
				AND s.recursion = 1
			WHERE
				b.schema_name IS NOT NULL;

			UPDATE s
			SET
				additional_info.modify
				('
					insert <object_name>{sql:column("b.object_name")}</object_name>
					as last
					into (/additional_info/block_info)[1]
				')
			FROM #sessions AS s
			INNER JOIN #blocked_requests AS b ON
				b.session_id = s.session_id
				AND b.request_id = s.request_id
				AND s.recursion = 1
			WHERE
				b.object_name IS NOT NULL;

			UPDATE s
			SET
				additional_info.modify
				('
					insert <query_error>{sql:column("b.query_error")}</query_error>
					as last
					into (/additional_info/block_info)[1]
				')
			FROM #sessions AS s
			INNER JOIN #blocked_requests AS b ON
				b.session_id = s.session_id
				AND b.request_id = s.request_id
				AND s.recursion = 1
			WHERE
				b.query_error IS NOT NULL;
		END;

		IF
			@output_column_list LIKE '%|[program_name|]%' ESCAPE '|'
			AND @output_column_list LIKE '%|[additional_info|]%' ESCAPE '|'
			AND @recursion = 1
		BEGIN;
			DECLARE @job_id UNIQUEIDENTIFIER;
			DECLARE @step_id INT;

			DECLARE agent_cursor
			CURSOR LOCAL FAST_FORWARD
			FOR 
				SELECT
					s.session_id,
					agent_nodes.agent_node.value('(job_id/text())[1]', 'uniqueidentifier') AS job_id,
					agent_nodes.agent_node.value('(step_id/text())[1]', 'int') AS step_id
				FROM #sessions AS s
				CROSS APPLY s.additional_info.nodes('//agent_job_info') AS agent_nodes (agent_node)
				WHERE
					s.recursion = 1
			OPTION (KEEPFIXED PLAN);
			
			OPEN agent_cursor;

			FETCH NEXT FROM agent_cursor
			INTO 
				@session_id,
				@job_id,
				@step_id;

			WHILE @@FETCH_STATUS = 0
			BEGIN;
				BEGIN TRY;
					DECLARE @job_name sysname;
					SET @job_name = NULL;
					DECLARE @step_name sysname;
					SET @step_name = NULL;
					
					SELECT
						@job_name = 
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									j.name,
									NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
									NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
									NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
								NCHAR(0),
								N'?'
							),
						@step_name = 
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									s.step_name,
									NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
									NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
									NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
								NCHAR(0),
								N'?'
							)
					FROM msdb.dbo.sysjobs AS j
					INNER JOIN msdb..sysjobsteps AS s ON
						j.job_id = s.job_id
					WHERE
						j.job_id = @job_id
						AND s.step_id = @step_id;

					IF @job_name IS NOT NULL
					BEGIN;
						UPDATE s
						SET
							additional_info.modify
							('
								insert text{sql:variable("@job_name")}
								into (/additional_info/agent_job_info/job_name)[1]
							')
						FROM #sessions AS s
						WHERE 
							s.session_id = @session_id
						OPTION (KEEPFIXED PLAN);
						
						UPDATE s
						SET
							additional_info.modify
							('
								insert text{sql:variable("@step_name")}
								into (/additional_info/agent_job_info/step_name)[1]
							')
						FROM #sessions AS s
						WHERE 
							s.session_id = @session_id
						OPTION (KEEPFIXED PLAN);
					END;
				END TRY
				BEGIN CATCH;
					DECLARE @msdb_error_message NVARCHAR(256);
					SET @msdb_error_message = ERROR_MESSAGE();
				
					UPDATE s
					SET
						additional_info.modify
						('
							insert <msdb_query_error>{sql:variable("@msdb_error_message")}</msdb_query_error>
							as last
							into (/additional_info/agent_job_info)[1]
						')
					FROM #sessions AS s
					WHERE 
						s.session_id = @session_id
						AND s.recursion = 1
					OPTION (KEEPFIXED PLAN);
				END CATCH;

				FETCH NEXT FROM agent_cursor
				INTO 
					@session_id,
					@job_id,
					@step_id;
			END;

			CLOSE agent_cursor;
			DEALLOCATE agent_cursor;
		END; 
		
		IF 
			@delta_interval > 0 
			AND @recursion <> 1
		BEGIN;
			SET @recursion = 1;

			DECLARE @delay_time CHAR(12);
			SET @delay_time = CONVERT(VARCHAR, DATEADD(second, @delta_interval, 0), 114);
			WAITFOR DELAY @delay_time;

			GOTO REDO;
		END;
	END;

	SET @sql = 
		--Outer column list
		CONVERT
		(
			VARCHAR(MAX),
			CASE
				WHEN 
					@destination_table <> '' 
					AND @return_schema = 0 
						THEN 'INSERT ' + @destination_table + ' '
				ELSE ''
			END +
			'SELECT ' +
				@output_column_list + ' ' +
			CASE @return_schema
				WHEN 1 THEN 'INTO #session_schema '
				ELSE ''
			END
		--End outer column list
		) + 
		--Inner column list
		CONVERT
		(
			VARCHAR(MAX),
			'FROM ' +
			'( ' +
				'SELECT ' +
					'session_id, ' +
					--[dd hh:mm:ss.mss]
					CASE @format_output
						WHEN 1 THEN
							'CASE ' +
								'WHEN elapsed_time < 0 THEN ' +
									'RIGHT ' +
									'( ' +
										'REPLICATE(''0'', max_elapsed_length) + CONVERT(VARCHAR, (-1 * elapsed_time) / 86400), ' +
										'max_elapsed_length ' +
									') + ' +
										'RIGHT ' +
										'( ' +
											'CONVERT(VARCHAR, DATEADD(second, (-1 * elapsed_time), 0), 120), ' +
											'9 ' +
										') + ' +
										'''.000'' ' +
								'ELSE ' +
									'RIGHT ' +
									'( ' +
										'REPLICATE(''0'', max_elapsed_length) + CONVERT(VARCHAR, elapsed_time / 86400000), ' +
										'max_elapsed_length ' +
									') + ' +
										'RIGHT ' +
										'( ' +
											'CONVERT(VARCHAR, DATEADD(second, elapsed_time / 1000, 0), 120), ' +
											'9 ' +
										') + ' +
										'''.'' + ' + 
										'RIGHT(''000'' + CONVERT(VARCHAR, elapsed_time % 1000), 3) ' +
							'END AS [dd hh:mm:ss.mss], '
						ELSE
							''
					END +
					--[dd hh:mm:ss.mss (avg)] / avg_elapsed_time
					CASE @format_output
						WHEN 1 THEN 
							'RIGHT ' +
							'( ' +
								'''00'' + CONVERT(VARCHAR, avg_elapsed_time / 86400000), ' +
								'2 ' +
							') + ' +
								'RIGHT ' +
								'( ' +
									'CONVERT(VARCHAR, DATEADD(second, avg_elapsed_time / 1000, 0), 120), ' +
									'9 ' +
								') + ' +
								'''.'' + ' +
								'RIGHT(''000'' + CONVERT(VARCHAR, avg_elapsed_time % 1000), 3) AS [dd hh:mm:ss.mss (avg)], '
						ELSE
							'avg_elapsed_time, '
					END +
					--physical_io
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, physical_io))) OVER() - LEN(CONVERT(VARCHAR, physical_io))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_io), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_io), 1), 19)) AS '
						ELSE ''
					END + 'physical_io, ' +
					--reads
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, reads))) OVER() - LEN(CONVERT(VARCHAR, reads))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, reads), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, reads), 1), 19)) AS '
						ELSE ''
					END + 'reads, ' +
					--physical_reads
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, physical_reads))) OVER() - LEN(CONVERT(VARCHAR, physical_reads))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_reads), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_reads), 1), 19)) AS '
						ELSE ''
					END + 'physical_reads, ' +
					--writes
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, writes))) OVER() - LEN(CONVERT(VARCHAR, writes))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, writes), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, writes), 1), 19)) AS '
						ELSE ''
					END + 'writes, ' +
					--tempdb_allocations
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tempdb_allocations))) OVER() - LEN(CONVERT(VARCHAR, tempdb_allocations))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_allocations), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_allocations), 1), 19)) AS '
						ELSE ''
					END + 'tempdb_allocations, ' +
					--tempdb_current
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tempdb_current))) OVER() - LEN(CONVERT(VARCHAR, tempdb_current))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_current), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_current), 1), 19)) AS '
						ELSE ''
					END + 'tempdb_current, ' +
					--CPU
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, CPU))) OVER() - LEN(CONVERT(VARCHAR, CPU))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, CPU), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, CPU), 1), 19)) AS '
						ELSE ''
					END + 'CPU, ' +
					--context_switches
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, context_switches))) OVER() - LEN(CONVERT(VARCHAR, context_switches))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, context_switches), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, context_switches), 1), 19)) AS '
						ELSE ''
					END + 'context_switches, ' +
					--used_memory
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, used_memory))) OVER() - LEN(CONVERT(VARCHAR, used_memory))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, used_memory), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, used_memory), 1), 19)) AS '
						ELSE ''
					END + 'used_memory, ' +
					--physical_io_delta			
					'CASE ' +
						'WHEN ' +
							'first_request_start_time = last_request_start_time ' + 
							'AND num_events = 2 ' +
							'AND physical_io_delta >= 0 ' +
								'THEN ' +
								CASE @format_output
									WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, physical_io_delta))) OVER() - LEN(CONVERT(VARCHAR, physical_io_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_io_delta), 1), 19)) ' 
									WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_io_delta), 1), 19)) '
									ELSE 'physical_io_delta '
								END +
						'ELSE NULL ' +
					'END AS physical_io_delta, ' +
					--reads_delta
					'CASE ' +
						'WHEN ' +
							'first_request_start_time = last_request_start_time ' + 
							'AND num_events = 2 ' +
							'AND reads_delta >= 0 ' +
								'THEN ' +
								CASE @format_output
									WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, reads_delta))) OVER() - LEN(CONVERT(VARCHAR, reads_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, reads_delta), 1), 19)) '
									WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, reads_delta), 1), 19)) '
									ELSE 'reads_delta '
								END +
						'ELSE NULL ' +
					'END AS reads_delta, ' +
					--physical_reads_delta
					'CASE ' +
						'WHEN ' +
							'first_request_start_time = last_request_start_time ' + 
							'AND num_events = 2 ' +
							'AND physical_reads_delta >= 0 ' +
								'THEN ' +
								CASE @format_output
									WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, physical_reads_delta))) OVER() - LEN(CONVERT(VARCHAR, physical_reads_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_reads_delta), 1), 19)) '
									WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, physical_reads_delta), 1), 19)) '
									ELSE 'physical_reads_delta '
								END + 
						'ELSE NULL ' +
					'END AS physical_reads_delta, ' +
					--writes_delta
					'CASE ' +
						'WHEN ' +
							'first_request_start_time = last_request_start_time ' + 
							'AND num_events = 2 ' +
							'AND writes_delta >= 0 ' +
								'THEN ' +
								CASE @format_output
									WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, writes_delta))) OVER() - LEN(CONVERT(VARCHAR, writes_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, writes_delta), 1), 19)) '
									WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, writes_delta), 1), 19)) '
									ELSE 'writes_delta '
								END + 
						'ELSE NULL ' +
					'END AS writes_delta, ' +
					--tempdb_allocations_delta
					'CASE ' +
						'WHEN ' +
							'first_request_start_time = last_request_start_time ' + 
							'AND num_events = 2 ' +
							'AND tempdb_allocations_delta >= 0 ' +
								'THEN ' +
								CASE @format_output
									WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tempdb_allocations_delta))) OVER() - LEN(CONVERT(VARCHAR, tempdb_allocations_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_allocations_delta), 1), 19)) '
									WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_allocations_delta), 1), 19)) '
									ELSE 'tempdb_allocations_delta '
								END + 
						'ELSE NULL ' +
					'END AS tempdb_allocations_delta, ' +
					--tempdb_current_delta
					--this is the only one that can (legitimately) go negative 
					'CASE ' +
						'WHEN ' +
							'first_request_start_time = last_request_start_time ' + 
							'AND num_events = 2 ' +
								'THEN ' +
								CASE @format_output
									WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tempdb_current_delta))) OVER() - LEN(CONVERT(VARCHAR, tempdb_current_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_current_delta), 1), 19)) '
									WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tempdb_current_delta), 1), 19)) '
									ELSE 'tempdb_current_delta '
								END + 
						'ELSE NULL ' +
					'END AS tempdb_current_delta, ' +
					--CPU_delta
					'CASE ' +
						'WHEN ' +
							'first_request_start_time = last_request_start_time ' + 
							'AND num_events = 2 ' +
								'THEN ' +
									'CASE ' +
										'WHEN ' +
											'thread_CPU_delta > CPU_delta ' +
											'AND thread_CPU_delta > 0 ' +
												'THEN ' +
													CASE @format_output
														WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, thread_CPU_delta + CPU_delta))) OVER() - LEN(CONVERT(VARCHAR, thread_CPU_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, thread_CPU_delta), 1), 19)) '
														WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, thread_CPU_delta), 1), 19)) '
														ELSE 'thread_CPU_delta '
													END + 
										'WHEN CPU_delta >= 0 THEN ' +
											CASE @format_output
												WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, thread_CPU_delta + CPU_delta))) OVER() - LEN(CONVERT(VARCHAR, CPU_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, CPU_delta), 1), 19)) '
												WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, CPU_delta), 1), 19)) '
												ELSE 'CPU_delta '
											END + 
										'ELSE NULL ' +
									'END ' +
						'ELSE ' +
							'NULL ' +
					'END AS CPU_delta, ' +
					--context_switches_delta
					'CASE ' +
						'WHEN ' +
							'first_request_start_time = last_request_start_time ' + 
							'AND num_events = 2 ' +
							'AND context_switches_delta >= 0 ' +
								'THEN ' +
								CASE @format_output
									WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, context_switches_delta))) OVER() - LEN(CONVERT(VARCHAR, context_switches_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, context_switches_delta), 1), 19)) '
									WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, context_switches_delta), 1), 19)) '
									ELSE 'context_switches_delta '
								END + 
						'ELSE NULL ' +
					'END AS context_switches_delta, ' +
					--used_memory_delta
					'CASE ' +
						'WHEN ' +
							'first_request_start_time = last_request_start_time ' + 
							'AND num_events = 2 ' +
							'AND used_memory_delta >= 0 ' +
								'THEN ' +
								CASE @format_output
									WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, used_memory_delta))) OVER() - LEN(CONVERT(VARCHAR, used_memory_delta))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, used_memory_delta), 1), 19)) '
									WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, used_memory_delta), 1), 19)) '
									ELSE 'used_memory_delta '
								END + 
						'ELSE NULL ' +
					'END AS used_memory_delta, ' +
					--tasks
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, tasks))) OVER() - LEN(CONVERT(VARCHAR, tasks))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tasks), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, tasks), 1), 19)) '
						ELSE ''
					END + 'tasks, ' +
					'status, ' +
					'wait_info, ' +
					'locks, ' +
					'tran_start_time, ' +
					'LEFT(tran_log_writes, LEN(tran_log_writes) - 1) AS tran_log_writes, ' +
					--open_tran_count
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, open_tran_count))) OVER() - LEN(CONVERT(VARCHAR, open_tran_count))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, open_tran_count), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, open_tran_count), 1), 19)) AS '
						ELSE ''
					END + 'open_tran_count, ' +
					--sql_command
					CASE @format_output 
						WHEN 0 THEN 'REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), sql_command), ''<?query --''+CHAR(13)+CHAR(10), ''''), CHAR(13)+CHAR(10)+''--?>'', '''') AS '
						ELSE ''
					END + 'sql_command, ' +
					--sql_text
					CASE @format_output 
						WHEN 0 THEN 'REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), sql_text), ''<?query --''+CHAR(13)+CHAR(10), ''''), CHAR(13)+CHAR(10)+''--?>'', '''') AS '
						ELSE ''
					END + 'sql_text, ' +
					'query_plan, ' +
					'blocking_session_id, ' +
					--blocked_session_count
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, blocked_session_count))) OVER() - LEN(CONVERT(VARCHAR, blocked_session_count))) + LEFT(CONVERT(CHAR(22), CONVERT(MONEY, blocked_session_count), 1), 19)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, LEFT(CONVERT(CHAR(22), CONVERT(MONEY, blocked_session_count), 1), 19)) AS '
						ELSE ''
					END + 'blocked_session_count, ' +
					--percent_complete
					CASE @format_output
						WHEN 1 THEN 'CONVERT(VARCHAR, SPACE(MAX(LEN(CONVERT(VARCHAR, CONVERT(MONEY, percent_complete), 2))) OVER() - LEN(CONVERT(VARCHAR, CONVERT(MONEY, percent_complete), 2))) + CONVERT(CHAR(22), CONVERT(MONEY, percent_complete), 2)) AS '
						WHEN 2 THEN 'CONVERT(VARCHAR, CONVERT(CHAR(22), CONVERT(MONEY, blocked_session_count), 1)) AS '
						ELSE ''
					END + 'percent_complete, ' +
					'host_name, ' +
					'login_name, ' +
					'database_name, ' +
					'program_name, ' +
					'additional_info, ' +
					'start_time, ' +
					'login_time, ' +
					'CASE ' +
						'WHEN status = N''sleeping'' THEN NULL ' +
						'ELSE request_id ' +
					'END AS request_id, ' +
					'GETDATE() AS collection_time '
		--End inner column list
		) +
		--Derived table and INSERT specification
		CONVERT
		(
			VARCHAR(MAX),
				'FROM ' +
				'( ' +
					'SELECT TOP(2147483647) ' +
						'*, ' +
						'CASE ' +
							'MAX ' +
							'( ' +
								'LEN ' +
								'( ' +
									'CONVERT ' +
									'( ' +
										'VARCHAR, ' +
										'CASE ' +
											'WHEN elapsed_time < 0 THEN ' +
												'(-1 * elapsed_time) / 86400 ' +
											'ELSE ' +
												'elapsed_time / 86400000 ' +
										'END ' +
									') ' +
								') ' +
							') OVER () ' +
								'WHEN 1 THEN 2 ' +
								'ELSE ' +
									'MAX ' +
									'( ' +
										'LEN ' +
										'( ' +
											'CONVERT ' +
											'( ' +
												'VARCHAR, ' +
												'CASE ' +
													'WHEN elapsed_time < 0 THEN ' +
														'(-1 * elapsed_time) / 86400 ' +
													'ELSE ' +
														'elapsed_time / 86400000 ' +
												'END ' +
											') ' +
										') ' +
									') OVER () ' +
						'END AS max_elapsed_length, ' +
						'MAX(physical_io * recursion) OVER (PARTITION BY session_id, request_id) + ' +
							'MIN(physical_io * recursion) OVER (PARTITION BY session_id, request_id) AS physical_io_delta, ' +
						'MAX(reads * recursion) OVER (PARTITION BY session_id, request_id) + ' +
							'MIN(reads * recursion) OVER (PARTITION BY session_id, request_id) AS reads_delta, ' +
						'MAX(physical_reads * recursion) OVER (PARTITION BY session_id, request_id) + ' +
							'MIN(physical_reads * recursion) OVER (PARTITION BY session_id, request_id) AS physical_reads_delta, ' +
						'MAX(writes * recursion) OVER (PARTITION BY session_id, request_id) + ' +
							'MIN(writes * recursion) OVER (PARTITION BY session_id, request_id) AS writes_delta, ' +
						'MAX(tempdb_allocations * recursion) OVER (PARTITION BY session_id, request_id) + ' +
							'MIN(tempdb_allocations * recursion) OVER (PARTITION BY session_id, request_id) AS tempdb_allocations_delta, ' +
						'MAX(tempdb_current * recursion) OVER (PARTITION BY session_id, request_id) + ' +
							'MIN(tempdb_current * recursion) OVER (PARTITION BY session_id, request_id) AS tempdb_current_delta, ' +
						'MAX(CPU * recursion) OVER (PARTITION BY session_id, request_id) + ' +
							'MIN(CPU * recursion) OVER (PARTITION BY session_id, request_id) AS CPU_delta, ' +
						'MAX(thread_CPU_snapshot * recursion) OVER (PARTITION BY session_id, request_id) + ' +
							'MIN(thread_CPU_snapshot * recursion) OVER (PARTITION BY session_id, request_id) AS thread_CPU_delta, ' +
						'MAX(context_switches * recursion) OVER (PARTITION BY session_id, request_id) + ' +
							'MIN(context_switches * recursion) OVER (PARTITION BY session_id, request_id) AS context_switches_delta, ' +
						'MAX(used_memory * recursion) OVER (PARTITION BY session_id, request_id) + ' +
							'MIN(used_memory * recursion) OVER (PARTITION BY session_id, request_id) AS used_memory_delta, ' +
						'MIN(last_request_start_time) OVER (PARTITION BY session_id, request_id) AS first_request_start_time, ' +
						'COUNT(*) OVER (PARTITION BY session_id, request_id) AS num_events ' +
					'FROM #sessions AS s1 ' +
					CASE 
						WHEN @sort_order = '' THEN ''
						ELSE
							'ORDER BY ' +
								@sort_order
					END +
				') AS s ' +
				'WHERE ' +
					's.recursion = 1 ' +
			') x ' +
			'OPTION (KEEPFIXED PLAN); ' +
			'' +
			CASE @return_schema
				WHEN 1 THEN
					'SET @schema = ' +
						'''CREATE TABLE <table_name> ( '' + ' +
							'STUFF ' +
							'( ' +
								'( ' +
									'SELECT ' +
										''','' + ' +
										'QUOTENAME(COLUMN_NAME) + '' '' + ' +
										'DATA_TYPE + ' + 
										'CASE ' +
											'WHEN DATA_TYPE LIKE ''%char'' THEN ''('' + COALESCE(NULLIF(CONVERT(VARCHAR, CHARACTER_MAXIMUM_LENGTH), ''-1''), ''max'') + '') '' ' +
											'ELSE '' '' ' +
										'END + ' +
										'CASE IS_NULLABLE ' +
											'WHEN ''NO'' THEN ''NOT '' ' +
											'ELSE '''' ' +
										'END + ''NULL'' AS [text()] ' +
									'FROM tempdb.INFORMATION_SCHEMA.COLUMNS ' +
									'WHERE ' +
										'TABLE_NAME = (SELECT name FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(''tempdb..#session_schema'')) ' +
										'ORDER BY ' +
											'ORDINAL_POSITION ' +
									'FOR XML ' +
										'PATH('''') ' +
								'), + ' +
								'1, ' +
								'1, ' +
								''''' ' +
							') + ' +
						''')''; ' 
				ELSE ''
			END
		--End derived table and INSERT specification
		);

	SET @sql_n = CONVERT(NVARCHAR(MAX), @sql);

	EXEC sp_executesql
		@sql_n,
		N'@schema VARCHAR(MAX) OUTPUT',
		@schema OUTPUT;
END;
GO



USE [DBA_Archive]
GO

/****** Object:  StoredProcedure [dbo].[sp__Sample_server_config]    Script Date: 04/27/2015 01:25:14 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp__Sample_server_config]
AS
-- Know product version since values may defer based on version
BEGIN
DECLARE @ProductVersion nvarchar(128);
DECLARE @charindex bigint;
DECLARE @MajorVersion nvarchar(max);
SELECT @ProductVersion = CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128));
SELECT @charindex = CHARINDEX('.', @ProductVersion);
SET @MajorVersion = SUBSTRING(@ProductVersion, 1, @charindex-1);
DECLARE @tempValue sql_variant;

-- Create table of default values
DECLARE @tvDefaultValues TABLE (Id int IDENTITY(1,1), ConfigurationOption nvarchar(128), Value sql_variant);
INSERT INTO @tvDefaultValues VALUES ('access check cache bucket count', 0);
INSERT INTO @tvDefaultValues VALUES ('access check cache quota', 0);
INSERT INTO @tvDefaultValues VALUES ('ad hoc distributed queries', 0);
INSERT INTO @tvDefaultValues VALUES ('affinity I/O mask', 0);
INSERT INTO @tvDefaultValues VALUES ('affinity64 I/O mask', 0);
INSERT INTO @tvDefaultValues VALUES ('affinity mask', 0);
INSERT INTO @tvDefaultValues VALUES ('affinity64 mask', 0);
INSERT INTO @tvDefaultValues VALUES ('allow updates', 0);
INSERT INTO @tvDefaultValues VALUES ('backup compression default', 0);
INSERT INTO @tvDefaultValues VALUES ('blocked process threshold', 0);
INSERT INTO @tvDefaultValues VALUES ('c2 audit mode', 0);
INSERT INTO @tvDefaultValues VALUES ('clr enabled', 0);
INSERT INTO @tvDefaultValues VALUES ('common criteria compliance enabled', 0);
INSERT INTO @tvDefaultValues VALUES ('contained database authentication', 0);
INSERT INTO @tvDefaultValues VALUES ('cost threshold for parallelism', 5);
INSERT INTO @tvDefaultValues VALUES ('cross db ownership chaining', 0);
INSERT INTO @tvDefaultValues VALUES ('cursor threshold', -1);
INSERT INTO @tvDefaultValues VALUES ('Database Mail XPs', 0);
INSERT INTO @tvDefaultValues VALUES ('default full-text language', 1033);
INSERT INTO @tvDefaultValues VALUES ('default language', 0);
INSERT INTO @tvDefaultValues VALUES ('default trace enabled', 1);
INSERT INTO @tvDefaultValues VALUES ('disallow results from triggers', 0);
INSERT INTO @tvDefaultValues VALUES ('EKM provider enabled', 0);
INSERT INTO @tvDefaultValues VALUES ('filestream_access_level', 0);
INSERT INTO @tvDefaultValues VALUES ('fill factor', 0);
INSERT INTO @tvDefaultValues VALUES ('ft crawl bandwidth (max)', 100);
INSERT INTO @tvDefaultValues VALUES ('ft crawl bandwidth (min)', 0);
INSERT INTO @tvDefaultValues VALUES ('ft notify bandwidth (max)', 100);
INSERT INTO @tvDefaultValues VALUES ('ft notify bandwidth (min)', 0);
INSERT INTO @tvDefaultValues VALUES ('index create memory', 0);
INSERT INTO @tvDefaultValues VALUES ('in-doubt xact resolution', 0);
INSERT INTO @tvDefaultValues VALUES ('lightweight pooling', 0);
INSERT INTO @tvDefaultValues VALUES ('locks', 0);
INSERT INTO @tvDefaultValues VALUES ('max degree of parallelism', 0);
INSERT INTO @tvDefaultValues VALUES ('max full-text crawl range', 4);
INSERT INTO @tvDefaultValues VALUES ('max server memory', 2147483647);	-- actual name may also include 'MB', keeping per MSDN definition in link mentioned above.
INSERT INTO @tvDefaultValues VALUES ('max text repl size', 65536);
INSERT INTO @tvDefaultValues VALUES ('max worker threads', 0);
INSERT INTO @tvDefaultValues VALUES ('media retention', 0);
INSERT INTO @tvDefaultValues VALUES ('min memory per query', 1024);
INSERT INTO @tvDefaultValues VALUES ('min server memory', 0);
INSERT INTO @tvDefaultValues VALUES ('nested triggers', 1);
INSERT INTO @tvDefaultValues VALUES ('network packet size', 4096);
INSERT INTO @tvDefaultValues VALUES ('Ole Automation Procedures', 0);
INSERT INTO @tvDefaultValues VALUES ('open objects', 0);
INSERT INTO @tvDefaultValues VALUES ('optimize for ad hoc workloads', 0);
INSERT INTO @tvDefaultValues VALUES ('PH_timeout', 60);
INSERT INTO @tvDefaultValues VALUES ('precompute rank', 0);
INSERT INTO @tvDefaultValues VALUES ('priority boost', 0);
INSERT INTO @tvDefaultValues VALUES ('query governor cost limit', 0);
INSERT INTO @tvDefaultValues VALUES ('query wait', -1);
INSERT INTO @tvDefaultValues VALUES ('recovery interval', 0);
INSERT INTO @tvDefaultValues VALUES ('remote access', 1);
INSERT INTO @tvDefaultValues VALUES ('remote admin connections', 0);
IF @MajorVersion IN (9, 10) SET @tempValue = 20 ELSE SET @tempValue = 10;
INSERT INTO @tvDefaultValues VALUES ('remote login timeout', @tempValue);
INSERT INTO @tvDefaultValues VALUES ('remote proc trans', 0);
INSERT INTO @tvDefaultValues VALUES ('remote query timeout', 600);
INSERT INTO @tvDefaultValues VALUES ('Replication XPs Option', 0);
INSERT INTO @tvDefaultValues VALUES ('scan for startup procs', 0);
INSERT INTO @tvDefaultValues VALUES ('server trigger recursion', 1);
INSERT INTO @tvDefaultValues VALUES ('set working set size', 0);
INSERT INTO @tvDefaultValues VALUES ('show advanced options', 0);
INSERT INTO @tvDefaultValues VALUES ('SMO and DMO XPs', 1);
INSERT INTO @tvDefaultValues VALUES ('transform noise words', 0);
INSERT INTO @tvDefaultValues VALUES ('two digit year cutoff', 2049);
INSERT INTO @tvDefaultValues VALUES ('user connections', 0);
INSERT INTO @tvDefaultValues VALUES ('user options', 0);
INSERT INTO @tvDefaultValues VALUES ('xp_cmdshell', 0);

INSERT DBA_Archive.._hist_non_default_config_values(name,value_in_use,DefaultValue)
SELECT sc.name, sc.value_in_use, DF.Value AS DefaultValue 
FROM @tvDefaultValues DF JOIN sys.configurations sc 
ON sc.name LIKE '%' + DF.ConfigurationOption + '%' AND DF.Value <> sc.value_in_use 
WHERE sc.name <> 'show advanced options' ORDER BY sc.name
END

GO


USE DBA_Archive
go

CREATE PROCEDURE sp__Collect_Server_Config
AS
DECLARE @ProductVersion nvarchar(128);
DECLARE @charindex bigint;
DECLARE @MajorVersion nvarchar(max);
SELECT @ProductVersion = CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128));
SELECT @charindex = CHARINDEX('.', @ProductVersion);
SET @MajorVersion = SUBSTRING(@ProductVersion, 1, @charindex-1);
DECLARE @tempValue sql_variant;

-- Create table of default values
DECLARE @tvDefaultValues TABLE (Id int IDENTITY(1,1), ConfigurationOption nvarchar(128), Value sql_variant);
INSERT INTO @tvDefaultValues VALUES ('access check cache bucket count', 0);
INSERT INTO @tvDefaultValues VALUES ('access check cache quota', 0);
INSERT INTO @tvDefaultValues VALUES ('ad hoc distributed queries', 0);
INSERT INTO @tvDefaultValues VALUES ('affinity I/O mask', 0);
INSERT INTO @tvDefaultValues VALUES ('affinity64 I/O mask', 0);
INSERT INTO @tvDefaultValues VALUES ('affinity mask', 0);
INSERT INTO @tvDefaultValues VALUES ('affinity64 mask', 0);
INSERT INTO @tvDefaultValues VALUES ('allow updates', 0);
INSERT INTO @tvDefaultValues VALUES ('backup compression default', 0);
INSERT INTO @tvDefaultValues VALUES ('blocked process threshold', 0);
INSERT INTO @tvDefaultValues VALUES ('c2 audit mode', 0);
INSERT INTO @tvDefaultValues VALUES ('clr enabled', 0);
INSERT INTO @tvDefaultValues VALUES ('common criteria compliance enabled', 0);
INSERT INTO @tvDefaultValues VALUES ('contained database authentication', 0);
INSERT INTO @tvDefaultValues VALUES ('cost threshold for parallelism', 5);
INSERT INTO @tvDefaultValues VALUES ('cross db ownership chaining', 0);
INSERT INTO @tvDefaultValues VALUES ('cursor threshold', -1);
INSERT INTO @tvDefaultValues VALUES ('Database Mail XPs', 0);
INSERT INTO @tvDefaultValues VALUES ('default full-text language', 1033);
INSERT INTO @tvDefaultValues VALUES ('default language', 0);
INSERT INTO @tvDefaultValues VALUES ('default trace enabled', 1);
INSERT INTO @tvDefaultValues VALUES ('disallow results from triggers', 0);
INSERT INTO @tvDefaultValues VALUES ('EKM provider enabled', 0);
INSERT INTO @tvDefaultValues VALUES ('filestream_access_level', 0);
INSERT INTO @tvDefaultValues VALUES ('fill factor', 0);
INSERT INTO @tvDefaultValues VALUES ('ft crawl bandwidth (max)', 100);
INSERT INTO @tvDefaultValues VALUES ('ft crawl bandwidth (min)', 0);
INSERT INTO @tvDefaultValues VALUES ('ft notify bandwidth (max)', 100);
INSERT INTO @tvDefaultValues VALUES ('ft notify bandwidth (min)', 0);
INSERT INTO @tvDefaultValues VALUES ('index create memory', 0);
INSERT INTO @tvDefaultValues VALUES ('in-doubt xact resolution', 0);
INSERT INTO @tvDefaultValues VALUES ('lightweight pooling', 0);
INSERT INTO @tvDefaultValues VALUES ('locks', 0);
INSERT INTO @tvDefaultValues VALUES ('max degree of parallelism', 0);
INSERT INTO @tvDefaultValues VALUES ('max full-text crawl range', 4);
INSERT INTO @tvDefaultValues VALUES ('max server memory', 2147483647);	-- actual name may also include 'MB', keeping per MSDN definition in link mentioned above.
INSERT INTO @tvDefaultValues VALUES ('max text repl size', 65536);
INSERT INTO @tvDefaultValues VALUES ('max worker threads', 0);
INSERT INTO @tvDefaultValues VALUES ('media retention', 0);
INSERT INTO @tvDefaultValues VALUES ('min memory per query', 1024);
INSERT INTO @tvDefaultValues VALUES ('min server memory', 0);
INSERT INTO @tvDefaultValues VALUES ('nested triggers', 1);
INSERT INTO @tvDefaultValues VALUES ('network packet size', 4096);
INSERT INTO @tvDefaultValues VALUES ('Ole Automation Procedures', 0);
INSERT INTO @tvDefaultValues VALUES ('open objects', 0);
INSERT INTO @tvDefaultValues VALUES ('optimize for ad hoc workloads', 0);
INSERT INTO @tvDefaultValues VALUES ('PH_timeout', 60);
INSERT INTO @tvDefaultValues VALUES ('precompute rank', 0);
INSERT INTO @tvDefaultValues VALUES ('priority boost', 0);
INSERT INTO @tvDefaultValues VALUES ('query governor cost limit', 0);
INSERT INTO @tvDefaultValues VALUES ('query wait', -1);
INSERT INTO @tvDefaultValues VALUES ('recovery interval', 0);
INSERT INTO @tvDefaultValues VALUES ('remote access', 1);
INSERT INTO @tvDefaultValues VALUES ('remote admin connections', 0);
IF @MajorVersion IN (9, 10) SET @tempValue = 20 ELSE SET @tempValue = 10;
INSERT INTO @tvDefaultValues VALUES ('remote login timeout', @tempValue);
INSERT INTO @tvDefaultValues VALUES ('remote proc trans', 0);
INSERT INTO @tvDefaultValues VALUES ('remote query timeout', 600);
INSERT INTO @tvDefaultValues VALUES ('Replication XPs Option', 0);
INSERT INTO @tvDefaultValues VALUES ('scan for startup procs', 0);
INSERT INTO @tvDefaultValues VALUES ('server trigger recursion', 1);
INSERT INTO @tvDefaultValues VALUES ('set working set size', 0);
INSERT INTO @tvDefaultValues VALUES ('show advanced options', 0);
INSERT INTO @tvDefaultValues VALUES ('SMO and DMO XPs', 1);
INSERT INTO @tvDefaultValues VALUES ('transform noise words', 0);
INSERT INTO @tvDefaultValues VALUES ('two digit year cutoff', 2049);
INSERT INTO @tvDefaultValues VALUES ('user connections', 0);
INSERT INTO @tvDefaultValues VALUES ('user options', 0);
INSERT INTO @tvDefaultValues VALUES ('xp_cmdshell', 0);
INSERT INTO @tvDefaultValues select 'CPU_NumberOfPhysicalCPUs', cpu_count / hyperthread_ratio FROM   sys.dm_os_sys_info
INSERT INTO @tvDefaultValues select 'CPU_NumberOfCoresInEachCPU', CASE WHEN hyperthread_ratio = cpu_count THEN ( ( cpu_count ) / ( cpu_count / hyperthread_ratio ) )
                     ELSE ( ( cpu_count ) / ( cpu_count / hyperthread_ratio ) )/2
              END FROM   sys.dm_os_sys_info
INSERT INTO @tvDefaultValues select 'CPU_TotalNumberOfCores', CASE WHEN hyperthread_ratio = cpu_count THEN cpu_count 
                     ELSE ( cpu_count / hyperthread_ratio ) * ( ( ( cpu_count ) / ( cpu_count / hyperthread_ratio ) )/2 )
              END  FROM   sys.dm_os_sys_info
INSERT INTO @tvDefaultValues select 'CPU_NumberOfLogicalCPUs', cpu_count FROM   sys.dm_os_sys_info

SELECT * FROM (
SELECT sc.name as Configuration_Name, sc.value_in_use as Configured_Value, DF.Value AS Default_Value 
FROM @tvDefaultValues DF JOIN sys.configurations sc 
ON (sc.name LIKE '%' + DF.ConfigurationOption + '%' AND DF.Value <> sc.value_in_use) 
WHERE sc.name <> 'show advanced options' 
UNION 
SELECT DF.ConfigurationOption as Configuration_Name, DF.Value as Actual_Value,'N/A' AS Default_Value 
FROM @tvDefaultValues DF 
WHERE DF.ConfigurationOption like 'CPU_%' 
)A
ORDER BY A.Configuration_Name
go
