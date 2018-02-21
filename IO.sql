--Gives Disk IO --anything taking more than 15 secs is having latency.
SELECT  CAST(SUM(io_stall_read_ms + io_stall_write_ms) / 
             SUM(1.0 + num_of_reads + num_of_writes) AS NUMERIC(10, 1) 
        ) AS [avg_io_stall_ms] 
FROM    sys.dm_io_virtual_file_stats(DB_ID(), NULL) 
WHERE   FILE_ID <> 2; 
