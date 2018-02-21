-- 2013-04-13 Pedro Lopes (Microsoft) pedro.lopes@microsoft.com (http://blogs.msdn.com/b/blogdoezequiel/)
--
-- Plan cache xqueries
--
-- 2013-07-16 - Optimized xQueries performance and usability
--
-- 2014-03-16 - Added details to several snippets
--

-- Querying the plan cache for missing indexes
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
	PlanMissingIndexes AS (SELECT query_plan, cp.usecounts, cp.refcounts, cp.plan_handle
							FROM sys.dm_exec_cached_plans cp (NOLOCK)
							CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) tp
							WHERE cp.cacheobjtype = 'Compiled Plan' 
								AND tp.query_plan.exist('//MissingIndex')=1
							)
SELECT c1.value('(//MissingIndex/@Database)[1]', 'sysname') AS database_name,
	c1.value('(//MissingIndex/@Schema)[1]', 'sysname') AS [schema_name],
	c1.value('(//MissingIndex/@Table)[1]', 'sysname') AS [table_name],
	c1.value('@StatementText', 'VARCHAR(4000)') AS sql_text,
	c1.value('@StatementId', 'int') AS StatementId,
	pmi.usecounts,
	pmi.refcounts,
	c1.value('(//MissingIndexGroup/@Impact)[1]', 'FLOAT') AS impact,
	REPLACE(c1.query('for $group in //ColumnGroup for $column in $group/Column where $group/@Usage="EQUALITY" return string($column/@Name)').value('.', 'varchar(max)'),'] [', '],[') AS equality_columns,
	REPLACE(c1.query('for $group in //ColumnGroup for $column in $group/Column where $group/@Usage="INEQUALITY" return string($column/@Name)').value('.', 'varchar(max)'),'] [', '],[') AS inequality_columns,
	REPLACE(c1.query('for $group in //ColumnGroup for $column in $group/Column where $group/@Usage="INCLUDE" return string($column/@Name)').value('.', 'varchar(max)'),'] [', '],[') AS include_columns,
	pmi.query_plan,
	pmi.plan_handle
FROM PlanMissingIndexes pmi
CROSS APPLY pmi.query_plan.nodes('//StmtSimple') AS q1(c1)
WHERE pmi.usecounts > 1
ORDER BY c1.value('(//MissingIndexGroup/@Impact)[1]', 'FLOAT') DESC
OPTION(RECOMPILE, MAXDOP 1); 
GO

-- Querying the plan cache for plans that have warnings
-- Note that SpillToTempDb warnings are only found in actual execution plans
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
	WarningSearch AS (SELECT qp.query_plan, cp.usecounts, cp.objtype, wn.query('.') AS StmtSimple, cp.plan_handle
						FROM sys.dm_exec_cached_plans cp (NOLOCK)
						CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
						CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(wn)
						WHERE wn.exist('//Warnings') = 1
							AND wn.exist('@QueryHash') = 1
						)
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
	StmtSimple.value('StmtSimple[1]/@StatementId', 'int') AS StatementId,
	c1.value('@NodeId','int') AS node_id,
	c1.value('@PhysicalOp','sysname') AS physical_op,
	c1.value('@LogicalOp','sysname') AS logical_op,
	CASE WHEN c2.exist('@NoJoinPredicate[. = "1"]') = 1 THEN 'NoJoinPredicate' 
		WHEN c3.exist('@Database') = 1 THEN 'ColumnsWithNoStatistics' END AS warning,
	ws.objtype,
	ws.usecounts,
	ws.query_plan,
	StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
	StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
	StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
	c1.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
	StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
	StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
	ws.plan_handle
FROM WarningSearch ws
CROSS APPLY StmtSimple.nodes('//RelOp') AS q1(c1)
CROSS APPLY c1.nodes('./Warnings') AS q2(c2)
OUTER APPLY c2.nodes('./ColumnsWithNoStatistics/ColumnReference') AS q3(c3)
UNION ALL
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
	StmtSimple.value('StmtSimple[1]/@StatementId', 'int') AS StatementId,
	c3.value('@NodeId','int') AS node_id,
	c3.value('@PhysicalOp','sysname') AS physical_op,
	c3.value('@LogicalOp','sysname') AS logical_op,
	CASE WHEN c2.exist('@UnmatchedIndexes[. = "1"]') = 1 THEN 'UnmatchedIndexes' 
		WHEN (c4.exist('@ConvertIssue[. = "Cardinality Estimate"]') = 1 OR c4.exist('@ConvertIssue[. = "Seek Plan"]') = 1) 
		THEN 'ConvertIssue_' + c4.value('@ConvertIssue','sysname') END AS warning,
	ws.objtype,
	ws.usecounts,
	ws.query_plan,
	StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
	StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
	StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
	c1.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
	StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
	StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
	ws.plan_handle
FROM WarningSearch ws
CROSS APPLY StmtSimple.nodes('//QueryPlan') AS q1(c1)
CROSS APPLY c1.nodes('./Warnings') AS q2(c2)
CROSS APPLY c1.nodes('./RelOp') AS q3(c3)
OUTER APPLY c2.nodes('./PlanAffectingConvert') AS q4(c4)
OPTION(RECOMPILE, MAXDOP 1); 
GO

-- Querying the plan cache for specific implicit conversions
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
	Convertsearch AS (SELECT qp.query_plan, cp.usecounts, cp.objtype, cp.plan_handle, cs.query('.') AS StmtSimple
					FROM sys.dm_exec_cached_plans cp (NOLOCK)
					CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
					CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(cs)
					WHERE cp.cacheobjtype = 'Compiled Plan' 
							AND cs.exist('@QueryHash') = 1
							AND cs.exist('.//ScalarOperator[contains(@ScalarString, "CONVERT_IMPLICIT")]') = 1
							AND cs.exist('.[contains(@StatementText, "Convertsearch")]') = 0
					)
SELECT c2.value('@StatementText', 'VARCHAR(4000)') AS sql_text,
	c2.value('@StatementId', 'int') AS StatementId,
	c3.value('@ScalarString[1]','VARCHAR(4000)') AS expression,
	ss.usecounts,
	ss.query_plan,
	StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
	StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
	StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
	c2.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
	StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
	StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
	ss.plan_handle
FROM Convertsearch ss
CROSS APPLY query_plan.nodes('//StmtSimple') AS q2(c2)
CROSS APPLY c2.nodes('.//ScalarOperator[contains(@ScalarString, "CONVERT_IMPLICIT")]') AS q3(c3)
OPTION(RECOMPILE, MAXDOP 1); 
GO

-- Querying the plan cache for index scans
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
	Scansearch AS (SELECT qp.query_plan, cp.usecounts, ss.query('.') AS StmtSimple, cp.plan_handle
					FROM sys.dm_exec_cached_plans cp (NOLOCK)
					CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
					CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(ss)
					WHERE cp.cacheobjtype = 'Compiled Plan'
						AND (ss.exist('//RelOp[@PhysicalOp = "Index Scan"]') = 1
								OR ss.exist('//RelOp[@PhysicalOp = "Clustered Index Scan"]') = 1)
						AND ss.exist('@QueryHash') = 1
					)
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
	StmtSimple.value('StmtSimple[1]/@StatementId', 'int') AS StatementId,
	c1.value('@NodeId','int') AS node_id,
	c2.value('@Database','sysname') AS database_name,
	c2.value('@Schema','sysname') AS [schema_name],
	c2.value('@Table','sysname') AS table_name,
	c1.value('@PhysicalOp','sysname') as physical_operator, 
	c2.value('@Index','sysname') AS index_name,
	c3.value('@ScalarString[1]','VARCHAR(4000)') AS predicate,
	c1.value('@TableCardinality','sysname') AS table_cardinality,
	c1.value('@EstimateRows','sysname') AS estimate_rows,
	c1.value('@AvgRowSize','sysname') AS avg_row_size,
	ss.usecounts,
	ss.query_plan,
	StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
	StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
	StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
	c1.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
	StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
	StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
	ss.plan_handle
FROM Scansearch ss
CROSS APPLY query_plan.nodes('//RelOp') AS q1(c1)
CROSS APPLY c1.nodes('./IndexScan/Object') AS q2(c2)
OUTER APPLY c1.nodes('./IndexScan/Predicate/ScalarOperator[1]') AS q3(c3)
WHERE (c1.exist('@PhysicalOp[. = "Index Scan"]') = 1
		OR c1.exist('@PhysicalOp[. = "Clustered Index Scan"]') = 1)
	AND c2.value('@Schema','sysname') <> '[sys]'
OPTION(RECOMPILE, MAXDOP 1); 
GO

-- Querying the plan cache for Lookups
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'), 
	Lookupsearch AS (SELECT qp.query_plan, cp.usecounts, ls.query('.') AS StmtSimple, cp.plan_handle
					FROM sys.dm_exec_cached_plans cp (NOLOCK)
					CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
					CROSS APPLY qp.query_plan.nodes('//StmtSimple') AS p(ls)
					WHERE cp.cacheobjtype = 'Compiled Plan'
						AND ls.exist('//IndexScan[@Lookup = "1"]') = 1
						AND ls.exist('@QueryHash') = 1
					)
SELECT StmtSimple.value('StmtSimple[1]/@StatementText', 'VARCHAR(4000)') AS sql_text,
	StmtSimple.value('StmtSimple[1]/@StatementId', 'int') AS StatementId,
	c1.value('@NodeId','int') AS node_id,
	c2.value('@Database','sysname') AS database_name,
	c2.value('@Schema','sysname') AS [schema_name],
	c2.value('@Table','sysname') AS table_name,
	'Lookup - ' + c1.value('@PhysicalOp','sysname') AS physical_operator, 
	c2.value('@Index','sysname') AS index_name,
	c3.value('@ScalarString','VARCHAR(4000)') AS predicate,
	c1.value('@TableCardinality','sysname') AS table_cardinality,
	c1.value('@EstimateRows','sysname') AS estimate_rows,
	c1.value('@AvgRowSize','sysname') AS avg_row_size,
	ls.usecounts,
	ls.query_plan,
	StmtSimple.value('StmtSimple[1]/@QueryHash', 'VARCHAR(100)') AS query_hash,
	StmtSimple.value('StmtSimple[1]/@QueryPlanHash', 'VARCHAR(100)') AS query_plan_hash,
	StmtSimple.value('StmtSimple[1]/@StatementSubTreeCost', 'sysname') AS StatementSubTreeCost,
	c1.value('@EstimatedTotalSubtreeCost','sysname') AS EstimatedTotalSubtreeCost,
	StmtSimple.value('StmtSimple[1]/@StatementOptmEarlyAbortReason', 'sysname') AS StatementOptmEarlyAbortReason,
	StmtSimple.value('StmtSimple[1]/@StatementOptmLevel', 'sysname') AS StatementOptmLevel,
	ls.plan_handle
FROM Lookupsearch ls
CROSS APPLY query_plan.nodes('//RelOp') AS q1(c1)
CROSS APPLY c1.nodes('./IndexScan/Object') AS q2(c2)
OUTER APPLY c1.nodes('./IndexScan//ScalarOperator[1]') AS q3(c3)
-- Below attribute is present either in Index Seeks or RID Lookups so it can reveal a Lookup is executed
WHERE c1.exist('./IndexScan[@Lookup = "1"]') = 1 
	AND c2.value('@Schema','sysname') <> '[sys]'
OPTION(RECOMPILE, MAXDOP 1); 
GO
