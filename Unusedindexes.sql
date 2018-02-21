SELECT d.name AS 'database name', t.name AS 'table name', i.name AS 'index name', ius.*
 FROM sys.dm_db_index_usage_stats ius
 JOIN sys.databases d ON d.database_id = ius.database_id AND ius.database_id=db_id()
 JOIN sys.tables t ON t.object_id = ius.object_id
 JOIN sys.indexes i ON i.object_id = ius.object_id AND i.index_id = ius.index_id
 ORDER BY user_updates DESC
 
 
 
 