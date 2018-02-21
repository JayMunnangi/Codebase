SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO

IF OBJECT_ID('dbo.Util_IndexUsage', 'P') IS NOT NULL DROP PROCEDURE dbo.Util_IndexUsage
GO

/**
Util_IndexUsage
Update - Fixed existance check for drop

Reports index stats, index size+rows, member seek + include columns as two comma separated output columns, and index usage stats for one or more tables and/or schemas.  Flexible parameterized sorting.
Has all the output of Util_ListIndexes plus the usage stats.

Update 2009-01-14:
	Added IndexDepth and FillFactor output columns
	Added 'Last xxx' datetime columns to the result set
	Added @Delimiter parameter for the column listing output (Defaults to ,) for accomodating export to csv files.
	Rearranged collumn output to match the pattern in Util_MissingIndexes. Constistant and looks better with the dates.
	Removed duplicate output of 'is_unique'

Required Input Parameters
	none

Optional
	@SchemaName sysname=''		Filters schemas.  Can use LIKE wildcards.  All schemas if blank.  Accepts LIKE Wildcards.
	@TableName sysname=''		Filters tables.  Can use LIKE wildcards.  All tables if blank.  Accepts LIKE Wildcards.
	@Sort Tinyint=5				Determines what to sort the results by:
									Value	Sort Columns
									1		Score DESC, user_seeks DESC, user_scans DESC
									2		Score ASC, user_seeks ASC, user_scans ASC
									3		SchemaName ASC, TableName ASC, IndexName ASC
									4		SchemaName ASC, TableName ASC, Score DESC
									5		SchemaName ASC, TableName ASC, Score ASC
	@Delimiter VarChar(1)=','	Delimiter for the horizontal delimited seek and include column listings.

Usage:
	EXECUTE Util_IndexUsage 'dbo', 'order%', 5, '|'

Copyright:
	Licensed under the L-GPL - a weak copyleft license - you are permitted to use this as a component of a proprietary database and call this from proprietary software.
	Copyleft lets you do anything you want except plagarize, conceal the source, proprietarize modifications, or prohibit copying & re-distribution of this script/proc.

	This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    see <http://www.fsf.org/licensing/licenses/lgpl.html> for the license text.

*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
**/

CREATE PROCEDURE dbo.Util_IndexUsage
	@SchemaName SysName='',
	@TableName SysName='',
	@Sort tinyint=5,
	@Delimiter VarChar(1)=','
AS

SELECT
	sys.schemas.schema_id, sys.schemas.name AS schema_name,
	sys.objects.object_id, sys.objects.name AS object_name,
	sys.indexes.index_id, ISNULL(sys.indexes.name, '---') AS index_name,
	partitions.Rows, partitions.SizeMB, IndexProperty(sys.objects.object_id,
	sys.indexes.name, 'IndexDepth') AS IndexDepth,
	sys.indexes.type, sys.indexes.type_desc, sys.indexes.fill_factor,
	sys.indexes.is_unique, sys.indexes.is_primary_key, sys.indexes.is_unique_constraint,
	ISNULL(Index_Columns.index_columns_key, '---') AS index_columns_key,
	ISNULL(Index_Columns.index_columns_include, '---') AS index_columns_include,
	ISNULL(sys.dm_db_index_usage_stats.user_seeks,0) AS user_seeks,
	ISNULL(sys.dm_db_index_usage_stats.user_scans,0) AS user_scans,
	ISNULL(sys.dm_db_index_usage_stats.user_lookups,0) AS user_lookups,
	ISNULL(sys.dm_db_index_usage_stats.user_updates,0) AS user_updates,
	sys.dm_db_index_usage_stats.last_user_seek, sys.dm_db_index_usage_stats.last_user_scan,
	sys.dm_db_index_usage_stats.last_user_lookup, sys.dm_db_index_usage_stats.last_user_update,
	ISNULL(sys.dm_db_index_usage_stats.system_seeks,0) AS system_seeks,
	ISNULL(sys.dm_db_index_usage_stats.system_scans,0) AS system_scans,
	ISNULL(sys.dm_db_index_usage_stats.system_lookups,0) AS system_lookups,
	ISNULL(sys.dm_db_index_usage_stats.system_updates,0) AS system_updates,
	sys.dm_db_index_usage_stats.last_system_seek, sys.dm_db_index_usage_stats.last_system_scan,
	sys.dm_db_index_usage_stats.last_system_lookup, sys.dm_db_index_usage_stats.last_system_update,
	(
		(
			(CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_seeks,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_seeks,0)))*10
			+ CASE WHEN sys.indexes.type=2 THEN (CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_scans,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_scans,0)))*1 ELSE 0 END
			+ 1
		)
		/CASE WHEN sys.indexes.type=2 THEN (CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_updates,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_updates,0))+1) ELSE 1 END
	) AS Score
FROM
	sys.objects
	JOIN sys.schemas ON sys.objects.schema_id=sys.schemas.schema_id
	JOIN sys.indexes ON sys.indexes.object_id=sys.objects.object_id
	JOIN (
		SELECT
			object_id, index_id, SUM(row_count) AS Rows,
			CONVERT(numeric(19,3), CONVERT(numeric(19,3), SUM(in_row_reserved_page_count+lob_reserved_page_count+row_overflow_reserved_page_count))/CONVERT(numeric(19,3), 128)) AS SizeMB
		FROM sys.dm_db_partition_stats
		GROUP BY object_id, index_id
	) AS partitions ON sys.indexes.object_id=partitions.object_id AND sys.indexes.index_id=partitions.index_id
	CROSS APPLY (
		SELECT
			LEFT(index_columns_key, LEN(index_columns_key)-1) AS index_columns_key,
			LEFT(index_columns_include, LEN(index_columns_include)-1) AS index_columns_include
		FROM
			(
				SELECT
					(
						SELECT sys.columns.name + @Delimiter + ' '
						FROM
							sys.index_columns
							JOIN sys.columns ON
								sys.index_columns.column_id=sys.columns.column_id
								AND sys.index_columns.object_id=sys.columns.object_id
						WHERE
							sys.index_columns.is_included_column=0
							AND sys.indexes.object_id=sys.index_columns.object_id
							AND sys.indexes.index_id=sys.index_columns.index_id
						ORDER BY key_ordinal
						FOR XML PATH('')
					) AS index_columns_key,
					(
						SELECT sys.columns.name + @Delimiter + ' '
						FROM
							sys.index_columns
							JOIN sys.columns ON
								sys.index_columns.column_id=sys.columns.column_id
								AND sys.index_columns.object_id=sys.columns.object_id
						WHERE
							sys.index_columns.is_included_column=1
							AND sys.indexes.object_id=sys.index_columns.object_id
							AND sys.indexes.index_id=sys.index_columns.index_id
						ORDER BY index_column_id
						FOR XML PATH('')
					) AS index_columns_include
			) AS Index_Columns
	) AS Index_Columns
	LEFT OUTER JOIN sys.dm_db_index_usage_stats ON
		sys.indexes.index_id=sys.dm_db_index_usage_stats.index_id
		AND sys.indexes.object_id=sys.dm_db_index_usage_stats.object_id
		AND sys.dm_db_index_usage_stats.database_id=DB_ID()
WHERE
	sys.objects.type='u'
	AND sys.schemas.name LIKE CASE WHEN @SchemaName='' THEn sys.schemas.name ELSE @SchemaName END
	AND sys.objects.name LIKE CASE WHEN @TableName='' THEn sys.objects.name ELSE @TableName END
ORDER BY
	CASE @Sort
		WHEN 1 THEN
			(
				(
					(CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_seeks,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_seeks,0)))*10
					+ CASE WHEN sys.indexes.type=2 THEN (CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_scans,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_scans,0)))*1 ELSE 0 END
					+ 1
				)
				/CASE WHEN sys.indexes.type=2 THEN (CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_updates,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_updates,0))+1) ELSE 1 END
			)*-1
		WHEN 2 THEN
			(
				(
					(CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_seeks,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_seeks,0)))*10
					+ CASE WHEN sys.indexes.type=2 THEN (CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_scans,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_scans,0)))*1 ELSE 0 END
					+ 1
				)
				/CASE WHEN sys.indexes.type=2 THEN (CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_updates,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_updates,0))+1) ELSE 1 END
			)
		ELSE NULL
	END,
	CASE @Sort
		WHEN 3 THEN sys.schemas.name
		WHEN 4 THEN sys.schemas.name
		WHEN 5 THEN sys.schemas.name
		ELSE NULL
	END,
	CASE @Sort
		WHEN 1 THEN CONVERT(VarChar(10), sys.dm_db_index_usage_stats.user_seeks*-1)
		WHEN 2 THEN CONVERT(VarChar(10), sys.dm_db_index_usage_stats.user_seeks)
		ELSE NULL
	END,
	CASE @Sort
		WHEN 3 THEN sys.objects.name
		WHEN 4 THEN sys.objects.name
		WHEN 5 THEN sys.objects.name
		ELSE NULL
	END,
	CASE @Sort
		WHEN 1 THEN sys.dm_db_index_usage_stats.user_scans*-1
		WHEN 2 THEN sys.dm_db_index_usage_stats.user_scans
		WHEN 4 THEN
			(
				(
					(CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_seeks,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_seeks,0)))*10
					+ CASE WHEN sys.indexes.type=2 THEN (CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_scans,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_scans,0)))*1 ELSE 0 END
					+ 1
				)
				/CASE WHEN sys.indexes.type=2 THEN (CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_updates,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_updates,0))+1) ELSE 1 END
			)*-1
		WHEN 5 THEN
			(
				(
					(CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_seeks,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_seeks,0)))*10
					+ CASE WHEN sys.indexes.type=2 THEN (CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_scans,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_scans,0)))*1 ELSE 0 END
					+ 1
				)
				/CASE WHEN sys.indexes.type=2 THEN (CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.user_updates,0))+CONVERT(Numeric(19,6), ISNULL(sys.dm_db_index_usage_stats.system_updates,0))+1) ELSE 1 END
			)
		ELSE NULL
	END,
	CASE @Sort
		WHEN 3 THEN sys.indexes.name
		ELSE NULL
	END
GO

--*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
