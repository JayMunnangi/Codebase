--distribution of the number of data files and filegroups per database is for your servers.

SELECT
    COUNT (*) AS [DataFiles],
    COUNT (DISTINCT data_space_id) AS [Filegroups],
    SUM (size) AS [Size]
FROM sys.master_files
WHERE [type_desc] = N'ROWS' -- filter out log files/data_space_id 0
    AND [database_id] > 4  -- filter out system databases
    AND [FILE_ID] != 65537 -- filter out FILESTREAM
GROUP BY [database_id];
GO
