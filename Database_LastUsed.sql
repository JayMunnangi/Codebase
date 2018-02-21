--based on the ideas from 
--http://sqlblog.com/blogs/aaron_bertrand/archive/2008/05/06/when-was-my-database-table-last-accessed.aspx
;;WITH myCTE AS
(
SELECT
  DB_NAME(database_id) AS TheDatabase,
  last_user_seek,
  last_user_scan,
  last_user_lookup,
  last_user_update
FROM sys.dm_db_index_usage_stats
)
SELECT
  ServerRestartedDate = (SELECT CREATE_DATE FROM sys.databases where name='tempdb'),
  x.TheDatabase,
  MAX(x.last_read) AS  last_read,
  MAX(x.last_write) AS last_write
FROM
(
SELECT TheDatabase,last_user_seek AS last_read, NULL AS last_write FROM myCTE
  UNION ALL
SELECT TheDatabase,last_user_scan, NULL FROM myCTE
  UNION ALL
SELECT TheDatabase,last_user_lookup, NULL FROM myCTE
  UNION ALL
SELECT TheDatabase,NULL, last_user_update FROM myCTE
) AS x

GROUP BY TheDatabase
ORDER BY TheDatabase
--order by last_read desc
