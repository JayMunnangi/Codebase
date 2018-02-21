SELECT D.name AS [Database Name],[file_id], 
num_of_reads, num_of_writes, 
num_of_bytes_read, num_of_bytes_written,
CAST(100. * num_of_reads/(num_of_reads + num_of_writes) 
AS DECIMAL(10,1)) AS [# Reads Pct],
CAST(100. * num_of_writes/(num_of_reads + num_of_writes) 
AS DECIMAL(10,1)) AS [# Write Pct],
CAST(100. * num_of_bytes_read/(num_of_bytes_read + num_of_bytes_written) 
AS DECIMAL(10,1)) AS [Read Bytes Pct],
CAST(100. * num_of_bytes_written/(num_of_bytes_read + num_of_bytes_written) 
AS DECIMAL(10,1)) AS [Written Bytes Pct]
FROM sys.dm_io_virtual_file_stats(NULL, NULL)I
  INNER JOIN sys.databases D  
      ON I.database_id = d.database_id
	  where file_id='1' and name not in ('master','msdb','tempdb','model','dba_archive')
GROUP BY name,file_id,num_of_reads, num_of_writes, 
num_of_bytes_read, num_of_bytes_written ORDER BY num_of_reads DESC;
