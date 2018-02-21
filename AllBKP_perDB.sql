SELECT
    [name],
    [backup_start_date],
    [type],
    [first_lsn],
    [database_backup_lsn]
FROM
    [msdb].[dbo].[backupset]
WHERE
    [database_name] = N'production'; -- change DB name
GO
