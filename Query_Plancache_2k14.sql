-- 2013-04-13 Pedro Lopes (Microsoft) pedro.lopes@microsoft.com (http://blogs.msdn.com/b/blogdoezequiel/)
--
-- Plan cache xqueries
--
-- 2013-07-16 - Optimized xQueries performance and usability
--
-- 2014-03-16 - Added details to several snippets
--
-- 2014-04-15 - Changed the query looking in the plan cache for plans that use parallelism and their cost

-- Querying the plan cache for index usage (change @IndexName below)
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
DECLARE @IndexName sysname = '<ix_name>';
SET @IndexName = QUOTENAME(@IndexName,'[');
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
	IndexSearch AS (SELECT qp.query_plan, cp.usecounts, ix.query('.') AS StmtSimple, cp.plan_handle
					FROM sys.dm_exec_cached_plans cp (NOLOCK)
					CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
					CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(ix)
					WHERE cp.cacheobjtype = 'Compiled Plan' 
						AND ix.exist('//Object[@Index = sql:variable("@IndexName")]') = 1 
					)
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
	c2.value('@Database','sysname') AS database_name,
	c2.value('@Schema','sysname') AS [schema_name],
	c2.value('@Table','sysname') AS table_name,
	c2.value('@Index','sysname') AS index_name,
	c1.value('@PhysicalOp','NVARCHAR(50)') as physical_operator,
	c3.value('@ScalarString[1]','VARCHAR(4000)') AS predicate,
	c4.value('@Column[1]','VARCHAR(256)') AS seek_columns,
	c1.value('@EstimateRows','sysname') AS estimate_rows,
	c1.value('@AvgRowSize','sysname') AS avg_row_size,
	ixs.query_plan,
	StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
	StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
	StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
	c1.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
	StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
	StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
	ixs.plan_handle
FROM IndexSearch ixs
CROSS APPLY StmtSimple.nodes('//RelOp') AS q1(c1)
CROSS APPLY c1.nodes('IndexScan/Object[@Index = sql:variable("@IndexName")]') AS q2(c2)
OUTER APPLY c1.nodes('IndexScan/Predicate/ScalarOperator') AS q3(c3)
OUTER APPLY c1.nodes('IndexScan/SeekPredicates/SeekPredicateNew//ColumnReference') AS q4(c4)
OPTION(RECOMPILE, MAXDOP 1); 
GO

-- Querying the plan cache for parametrization
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
	PlanParameters AS (SELECT cp.plan_handle, qp.query_plan, qp.dbid, qp.objectid
						FROM sys.dm_exec_cached_plans cp (NOLOCK)
						CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
						WHERE qp.query_plan.exist('//ParameterList')=1
							AND cp.cacheobjtype = 'Compiled Plan'
						)
SELECT QUOTENAME(DB_NAME(pp.dbid)) AS database_name,
	ISNULL(OBJECT_NAME(pp.objectid, pp.dbid), 'No_Associated_Object') AS [object_name],
	c2.value('(@Column)[1]','sysname') AS parameter_name,
	c2.value('(@ParameterCompiledValue)[1]','VARCHAR(max)') AS parameter_compiled_value,
	pp.query_plan,
	pp.plan_handle
FROM PlanParameters pp
CROSS APPLY query_plan.nodes('//ParameterList') AS q1(c1)
CROSS APPLY c1.nodes('ColumnReference') as q2(c2)
WHERE pp.dbid > 4 AND pp.dbid < 32767
OPTION(RECOMPILE, MAXDOP 1); 
GO

-- Querying the plan cache for plans that use parallelism and their cost (useful for tuning Cost Threshold for Parallelism)
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
	ParallelSearch AS (SELECT qp.query_plan, cp.usecounts, cp.objtype, ix.query('.') AS StmtSimple, cp.plan_handle
						FROM sys.dm_exec_cached_plans cp (NOLOCK)
						CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
						CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(ix)
						WHERE ix.exist('//RelOp[@Parallel = "1"]') = 1
							AND ix.exist('@QueryHash') = 1
						)
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
	ps.plan_handle,
	ps.objtype,
	ps.usecounts,
	StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
	ps.query_plan,
	StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
	StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
	c1.value('@CachedPlanSize','sysname') AS CachedPlanSize,
	c2.value('@SerialRequiredMemory','sysname') AS SerialRequiredMemory,
	c2.value('@SerialDesiredMemory','sysname') AS SerialDesiredMemory,
	c3.value('@EstimatedAvailableMemoryGrant','sysname') AS EstimatedAvailableMemoryGrant,
	c3.value('@EstimatedPagesCached','sysname') AS EstimatedPagesCached,
	c3.value('@EstimatedAvailableDegreeOfParallelism','sysname') AS EstimatedAvailableDegreeOfParallelism,
	StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
	StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash
FROM ParallelSearch ps
CROSS APPLY StmtSimple.nodes('//QueryPlan') AS q1(c1)
CROSS APPLY c1.nodes('.//MemoryGrantInfo') AS q2(c2)
CROSS APPLY c1.nodes('.//OptimizerHardwareDependentProperties') AS q3(c3)
ORDER BY 5 DESC
OPTION(RECOMPILE, MAXDOP 1);
GO

-- Querying the plan cache for plans that use parallelism, with more details
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
	ParallelSearch AS (SELECT qp.query_plan, cp.usecounts, cp.objtype, ix.query('.') AS StmtSimple, cp.plan_handle
						FROM sys.dm_exec_cached_plans cp (NOLOCK)
						CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
						CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(ix)
						WHERE cp.cacheobjtype = 'Compiled Plan' 
							AND ix.exist('//RelOp[@Parallel = "1"]') = 1
							AND ix.exist('@QueryHash') = 1
						)
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
	StmtSimple.value('StmtSimple[1]/@StatementId', 'int') AS StatementId,
	c1.value('@NodeId','int') AS node_id,
	c2.value('@Database','sysname') AS database_name,
	c2.value('@Schema','sysname') AS [schema_name],
	c2.value('@Table','sysname') AS table_name,
	c2.value('@Index','sysname') AS [index],
	c2.value('@IndexKind','sysname') AS index_type,
	c1.value('@PhysicalOp','sysname') AS physical_op,
	c1.value('@LogicalOp','sysname') AS logical_op,
	c1.value('@TableCardinality','sysname') AS table_cardinality,
	c1.value('@EstimateRows','sysname') AS estimate_rows,
	c1.value('@AvgRowSize','sysname') AS avg_row_size,
	ps.objtype,
	ps.usecounts,
	ps.query_plan,
	StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
	StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
	StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
	c1.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
	StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
	StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
	ps.plan_handle
FROM ParallelSearch ps
CROSS APPLY StmtSimple.nodes('//Parallelism//RelOp') AS q1(c1)
CROSS APPLY c1.nodes('.//IndexScan/Object') AS q2(c2)
WHERE c1.value('@Parallel','int') = 1
	AND (c1.exist('@PhysicalOp[. = "Index Scan"]') = 1
	OR c1.exist('@PhysicalOp[. = "Clustered Index Scan"]') = 1
	OR c1.exist('@PhysicalOp[. = "Index Seek"]') = 1
	OR c1.exist('@PhysicalOp[. = "Clustered Index Seek"]') = 1
	OR c1.exist('@PhysicalOp[. = "Table Scan"]') = 1)
	AND c2.value('@Schema','sysname') <> '[sys]'
OPTION(RECOMPILE, MAXDOP 1); 
GO

-- Querying the plan cache for plans that use parallelism, and scheduler time > elapsed time
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
	ParallelSearch AS (SELECT qp.query_plan, cp.usecounts, cp.objtype, qs.[total_worker_time], qs.[total_elapsed_time], qs.[execution_count],
							ix.query('.') AS StmtSimple, cp.plan_handle
						FROM sys.dm_exec_cached_plans cp (NOLOCK)
						INNER JOIN sys.dm_exec_query_stats qs (NOLOCK) ON cp.plan_handle = qs.plan_handle
						CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
						CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(ix)
						WHERE cp.cacheobjtype = 'Compiled Plan' 
							AND ix.exist('//RelOp[@Parallel = "1"]') = 1
							AND ix.exist('@QueryHash') = 1
							AND (qs.[total_worker_time]/qs.[execution_count]) > (qs.[total_elapsed_time]/qs.[execution_count])
						)
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
	ps.objtype,
	ps.usecounts,
	ps.[total_worker_time]/ps.[execution_count] AS avg_worker_time,
	ps.[total_elapsed_time]/ps.[execution_count] As avg_elapsed_time,
	ps.query_plan,
	StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
	StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
	StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
	StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
	StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
	ps.plan_handle
FROM ParallelSearch ps
CROSS APPLY StmtSimple.nodes('//RelOp[1]') AS q1(c1)
WHERE c1.value('@Parallel','int') = 1 AND c1.value('@NodeId','int') = 0
OPTION(RECOMPILE, MAXDOP 1); 
GO

-- Querying the plan cache for plans that use parallelism, and scheduler time > elapsed time and more detailed output
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
	ParallelSearch AS (SELECT qp.query_plan, cp.usecounts, cp.objtype, qs.[total_worker_time], qs.[total_elapsed_time], qs.[execution_count],
							ix.query('.') AS StmtSimple, cp.plan_handle
						FROM sys.dm_exec_cached_plans cp (NOLOCK)
						INNER JOIN sys.dm_exec_query_stats qs (NOLOCK) ON cp.plan_handle = qs.plan_handle
						CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
						CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(ix)
						WHERE cp.cacheobjtype = 'Compiled Plan' 
							AND ix.exist('//RelOp[@Parallel = "1"]') = 1
							AND ix.exist('@QueryHash') = 1
							AND (qs.[total_worker_time]/qs.[execution_count]) > (qs.[total_elapsed_time]/qs.[execution_count])
						)
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
	StmtSimple.value('StmtSimple[1]/@StatementId', 'int') AS StatementId,
	c1.value('@NodeId','int') AS node_id,
	c2.value('@Database','sysname') AS database_name,
	c2.value('@Schema','sysname') AS [schema_name],
	c2.value('@Table','sysname') AS table_name,
	c2.value('@Index','sysname') AS [index],
	c2.value('@IndexKind','sysname') AS index_type,
	c1.value('@PhysicalOp','sysname') AS physical_op,
	c1.value('@LogicalOp','sysname') AS logical_op,
	c1.value('@TableCardinality','sysname') AS table_cardinality,
	c1.value('@EstimateRows','sysname') AS estimate_rows,
	c1.value('@AvgRowSize','sysname') AS avg_row_size,
	ps.objtype,
	ps.usecounts,
	ps.[total_worker_time]/ps.[execution_count] AS avg_worker_time,
	ps.[total_elapsed_time]/ps.[execution_count] As avg_elapsed_time,
	ps.query_plan,
	StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
	StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
	StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
	c1.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
	StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
	StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
	ps.plan_handle
FROM ParallelSearch ps
CROSS APPLY StmtSimple.nodes('//Parallelism//RelOp') AS q1(c1)
CROSS APPLY c1.nodes('.//IndexScan/Object') AS q2(c2)
WHERE c1.value('@Parallel','int') = 1
	AND (c1.exist('@PhysicalOp[. = "Index Scan"]') = 1
	OR c1.exist('@PhysicalOp[. = "Clustered Index Scan"]') = 1
	OR c1.exist('@PhysicalOp[. = "Index Seek"]') = 1
	OR c1.exist('@PhysicalOp[. = "Clustered Index Seek"]') = 1
	OR c1.exist('@PhysicalOp[. = "Table Scan"]') = 1)
	AND c2.value('@Schema','sysname') <> '[sys]'
OPTION(RECOMPILE, MAXDOP 1); 
GO
