/*
In every system the tempdb database is the most frequent db. Beside the system internal function like version store also user created temporary table increases the size of tempdb and the IO workload.
This Transact-SQL script list the actually existing temporary tables and their size.

Works with SQL Server 2005 and higher versions in all editions.
*/
-- Temporary Tables and Their Size
SELECT TBL.name AS ObjName
      ,STAT.row_count AS StatRowCount
      ,STAT.used_page_count * 8 AS UsedSizeKB
      ,STAT.reserved_page_count * 8 AS RevervedSizeKB
FROM tempdb.sys.partitions AS PART
     INNER JOIN tempdb.sys.dm_db_partition_stats AS STAT
         ON PART.partition_id = STAT.partition_id
            AND PART.partition_number = STAT.partition_number
     INNER JOIN tempdb.sys.tables AS TBL
         ON STAT.object_id = TBL.object_id
ORDER BY TBL.name;